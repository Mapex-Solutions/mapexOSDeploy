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

	// KEK seeding (the encryptionKeys collection consumed by mapexVault's
	// kek module). A KEK is a random 32-byte key, hex-encoded then
	// envelope-encrypted, so the Vault returns it ready for envelope.New.
	kekSize         = 32
	kekOIDNamespace = "mapex-kek-seed-v1"
	kekCollection   = "encryptionKeys"
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

// kekSpec describes one platform KEK by context. Like caCatalog, this
// slice is the single source of truth: adding a new KEK context means
// appending here and adding one insertMany line to kek-bootstrap.sh.
type kekSpec struct {
	context string
	outFile string
}

var kekCatalog = []kekSpec{
	{
		context: "lorawan_device_keys",
		outFile: "lorawan_device_keys.json",
	},
}

func main() {
	in := flag.String("in", "", "input dir containing root_ca.{crt,key} and intermediate_ca.{crt,key}")
	out := flag.String("out", "", "output dir for CA seed JSON files")
	kekOut := flag.String("kek-out", "", "output dir for encryptionKeys (KEK) seed JSON files")
	flag.Parse()

	caMode := *in != "" && *out != ""
	kekMode := *kekOut != ""
	if !caMode && !kekMode {
		fatal("provide --in and --out (CA seed) and/or --kek-out (KEK seed)")
	}

	masterHex := os.Getenv("CREDENTIAL_MASTER_KEY")
	if masterHex == "" {
		fatal("CREDENTIAL_MASTER_KEY env required (64 hex chars = 32 bytes AES-256)")
	}
	masterKey, err := hex.DecodeString(masterHex)
	if err != nil || len(masterKey) != masterKeySize {
		fatal("CREDENTIAL_MASTER_KEY must be 64 hex chars (32 bytes)")
	}

	now := time.Now().UTC()

	if caMode {
		if err := os.MkdirAll(*out, 0o755); err != nil {
			fatal(fmt.Sprintf("mkdir out: %v", err))
		}
		for _, spec := range caCatalog {
			if err := encodeOne(spec, *in, *out, masterKey, now); err != nil {
				fatal(fmt.Sprintf("[%s] %v", spec.kind, err))
			}
			fmt.Printf("OK  %s -> %s\n", spec.kind, filepath.Join(*out, spec.outFile))
		}
		fmt.Printf("\nCA seed JSON ready in %s. Collection: %s\n", *out, collection)
	}

	if kekMode {
		if err := os.MkdirAll(*kekOut, 0o755); err != nil {
			fatal(fmt.Sprintf("mkdir kek-out: %v", err))
		}
		for _, spec := range kekCatalog {
			if err := encodeKEK(spec, *kekOut, masterKey, now); err != nil {
				fatal(fmt.Sprintf("[%s] %v", spec.context, err))
			}
			fmt.Printf("OK  kek/%s -> %s\n", spec.context, filepath.Join(*kekOut, spec.outFile))
		}
		fmt.Printf("\nKEK seed JSON ready in %s. Collection: %s\n", *kekOut, kekCollection)
	}
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

// encodeKEK generates a fresh 32-byte KEK for one context, hex-encodes it,
// envelope-encrypts the hex (so the Vault returns a value ready for
// envelope.New), and writes the encryptionKeys EJSON document. The KEK never
// touches disk in plaintext. Field names mirror the EncryptionKey entity bson
// tags one-for-one.
func encodeKEK(spec kekSpec, outDir string, masterKey []byte, now time.Time) error {
	raw := make([]byte, kekSize)
	if _, err := io.ReadFull(rand.Reader, raw); err != nil {
		return fmt.Errorf("gen kek: %w", err)
	}
	kekHex := hex.EncodeToString(raw)

	env, err := envelopeEncrypt(masterKey, []byte(kekHex))
	if err != nil {
		return fmt.Errorf("envelope encrypt: %w", err)
	}

	oid := deterministicOID(kekOIDNamespace, spec.context)
	doc := map[string]any{
		"_id":          ejsonOID(oid),
		"context":      spec.context,
		"isSystem":     true,
		"encryptedDEK": ejsonBinary(env.encryptedDEK),
		"dekNonce":     ejsonBinary(env.dekNonce),
		"encryptedKey": ejsonBinary(env.encryptedData),
		"keyNonce":     ejsonBinary(env.dataNonce),
		"created":      ejsonDate(now),
		"updated":      ejsonDate(now),
	}

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
