// Command seed-encryptor turns the per-CA PEM pair on disk into a
// MongoDB extended-JSON document ready for mongoimport-style seeding.
//
// The emitted documents match the persistence shape of
// pkiCertificateAuthorities in the mapexVault module. Private keys are
// AES-256-GCM envelope-encrypted with the same Master Key the running
// service uses at decrypt time. Invoked by the mongodb-init container's
// pki-bootstrap.sh right after openssl produces the PEM pair.
package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

const (
	masterKeySize = 32
	gcmNonceSize  = 12

	// Stable ObjectID hash domain; keeps deterministic _ids across
	// bootstrap runs so re-seeding lands on identical documents.
	oidNamespace = "mapex-pki-seed-v1"

	collection = "pkiCertificateAuthorities"
)

// caSpec describes one CA kind we know how to serialize. The slice
// below is the single source of truth — adding a new CA type means
// appending here, dropping a PEM pair on disk, and adding one
// seed_collection line to seed.sh.
type caSpec struct {
	kind      string
	subjectCN string
	certFile  string
	keyFile   string
	outFile   string
}

var caCatalog = []caSpec{
	{
		kind:      "root-ca",
		subjectCN: "Mapex Root CA",
		certFile:  "root_ca.crt",
		keyFile:   "root_ca.key",
		outFile:   "root_ca.json",
	},
	{
		kind:      "intermediate-ca",
		subjectCN: "Mapex Intermediate CA",
		certFile:  "intermediate_ca.crt",
		keyFile:   "intermediate_ca.key",
		outFile:   "intermediate_ca.json",
	},
}

func main() {
	in := flag.String("in", "", "input dir containing root_ca.{crt,key} and intermediate_ca.{crt,key}")
	out := flag.String("out", "", "output dir for seed JSON files")
	flag.Parse()
	if *in == "" || *out == "" {
		fatal("--in and --out are required")
	}

	masterHex := os.Getenv("CREDENTIAL_MASTER_KEY")
	if masterHex == "" {
		fatal("CREDENTIAL_MASTER_KEY env required (64 hex chars = 32 bytes AES-256)")
	}
	masterKey, err := hex.DecodeString(masterHex)
	if err != nil || len(masterKey) != masterKeySize {
		fatal("CREDENTIAL_MASTER_KEY must be 64 hex chars (32 bytes)")
	}

	if err := os.MkdirAll(*out, 0o755); err != nil {
		fatal(fmt.Sprintf("mkdir out: %v", err))
	}

	now := time.Now().UTC()
	for _, spec := range caCatalog {
		if err := encodeOne(spec, *in, *out, masterKey, now); err != nil {
			fatal(fmt.Sprintf("[%s] %v", spec.kind, err))
		}
		fmt.Printf("OK  %s -> %s\n", spec.kind, filepath.Join(*out, spec.outFile))
	}
	fmt.Printf("\nSeed JSON ready in %s. Collection: %s\n", *out, collection)
}

// encodeOne reads the PEM pair for a single CA kind, envelope-encrypts
// the private key, and writes the EJSON document. Errors surface to the
// caller so main() can fail fast — partial output is worse than none.
func encodeOne(spec caSpec, inDir, outDir string, masterKey []byte, now time.Time) error {
	certPath := filepath.Join(inDir, spec.certFile)
	keyPath := filepath.Join(inDir, spec.keyFile)

	certPEM, err := os.ReadFile(certPath)
	if err != nil {
		return fmt.Errorf("read cert %s: %w", certPath, err)
	}
	keyPEM, err := os.ReadFile(keyPath)
	if err != nil {
		return fmt.Errorf("read key %s: %w", keyPath, err)
	}

	cert, err := parseCertPEM(certPEM)
	if err != nil {
		return fmt.Errorf("parse cert: %w", err)
	}

	env, err := envelopeEncrypt(masterKey, keyPEM)
	if err != nil {
		return fmt.Errorf("envelope encrypt: %w", err)
	}

	fingerprint := certFingerprintHex(cert.Raw)
	oid := deterministicOID(oidNamespace, spec.kind)

	doc := buildEJSONDoc(spec, oid, fingerprint, cert.NotBefore.UTC(), cert.NotAfter.UTC(), now, certPEM, env)

	body, err := json.MarshalIndent([]map[string]any{doc}, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	body = append(body, '\n')
	return os.WriteFile(filepath.Join(outDir, spec.outFile), body, 0o644)
}

// buildEJSONDoc returns the document map shaped for EJSON.parse so the
// mongodb-init container can insertMany directly. Field names mirror
// the CertificateAuthority entity bson tags one-for-one.
func buildEJSONDoc(spec caSpec, oid, fingerprint string, notBefore, notAfter, now time.Time, certPEM []byte, env *envelope) map[string]any {
	return map[string]any{
		"_id":          ejsonOID(oid),
		"kind":         spec.kind,
		"isSystem":     true,
		"subjectCN":    spec.subjectCN,
		"fingerprint":  fingerprint,
		"notBefore":    ejsonDate(notBefore),
		"notAfter":     ejsonDate(notAfter),
		"encryptedDEK": ejsonBinary(env.encryptedDEK),
		"dekNonce":     ejsonBinary(env.dekNonce),
		"encryptedKey": ejsonBinary(env.encryptedData),
		"keyNonce":     ejsonBinary(env.dataNonce),
		"certPEM":      ejsonBinary(certPEM),
		"created":      ejsonDate(now),
		"updated":      ejsonDate(now),
	}
}

// envelope holds the four AES-GCM blobs the EnvelopePort persists.
// Mirrors envelope.EncryptedEnvelope without importing mapexGoKit so
// this helper stays a stdlib-only binary.
type envelope struct {
	encryptedDEK  []byte
	dekNonce      []byte
	encryptedData []byte
	dataNonce     []byte
}

// envelopeEncrypt mirrors mapexGoKit/utils/envelope.EnvelopeService.Encrypt
// byte-for-byte. Re-implemented here to avoid pulling the gokit module
// into this standalone tool; cross-checked with envelope_test.go vectors.
func envelopeEncrypt(masterKey, plaintext []byte) (*envelope, error) {
	dek := make([]byte, masterKeySize)
	if _, err := io.ReadFull(rand.Reader, dek); err != nil {
		return nil, fmt.Errorf("gen dek: %w", err)
	}
	encryptedData, dataNonce, err := aesGCMSeal(dek, plaintext)
	if err != nil {
		return nil, fmt.Errorf("seal data: %w", err)
	}
	encryptedDEK, dekNonce, err := aesGCMSeal(masterKey, dek)
	if err != nil {
		return nil, fmt.Errorf("seal dek: %w", err)
	}
	return &envelope{
		encryptedDEK:  encryptedDEK,
		dekNonce:      dekNonce,
		encryptedData: encryptedData,
		dataNonce:     dataNonce,
	}, nil
}

func aesGCMSeal(key, plaintext []byte) ([]byte, []byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, nil, err
	}
	nonce := make([]byte, gcmNonceSize)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, nil, err
	}
	return gcm.Seal(nil, nonce, plaintext, nil), nonce, nil
}

func parseCertPEM(certPEM []byte) (*x509.Certificate, error) {
	block, _ := pem.Decode(certPEM)
	if block == nil {
		return nil, fmt.Errorf("no PEM block found")
	}
	return x509.ParseCertificate(block.Bytes)
}

func certFingerprintHex(der []byte) string {
	sum := sha256.Sum256(der)
	return hex.EncodeToString(sum[:])
}

// deterministicOID derives a stable 12-byte ObjectID hex string from a
// namespace + kind tuple. Re-running the bootstrap produces the same _id
// for the same CA kind, so seed re-insertion is idempotent at the doc
// identity level (the collection's unique index on `kind` is the real
// guard, but stable _ids make diffs reviewable).
func deterministicOID(namespace, kind string) string {
	h := sha1.Sum([]byte(namespace + "/" + kind))
	return hex.EncodeToString(h[:12])
}

func ejsonOID(hexID string) map[string]string {
	return map[string]string{"$oid": hexID}
}

func ejsonDate(t time.Time) map[string]string {
	return map[string]string{"$date": t.UTC().Format(time.RFC3339Nano)}
}

func ejsonBinary(b []byte) map[string]any {
	return map[string]any{
		"$binary": map[string]string{
			"base64":  base64.StdEncoding.EncodeToString(b),
			"subType": "00",
		},
	}
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, "seed-encryptor: "+msg)
	os.Exit(1)
}
