# Custom init container: mongo:7 + openssl + seed-encryptor.
# Runs once per `docker compose up` to bring a fresh stack online with
# a working PKI: generates CA pair, writes broker server cert into the
# broker volume, envelope-encrypts the CA private keys, inserts the
# resulting documents into mongo. Idempotent — re-runs are no-ops when
# mapex_vault.pkiCertificateAuthorities already has docs.

FROM golang:1.25-alpine AS builder
WORKDIR /build
COPY seed-encryptor/go.mod ./go.mod
COPY seed-encryptor/main.go ./main.go
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/seed-encryptor ./...

FROM mongo:7
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /out/seed-encryptor /usr/local/bin/seed-encryptor
COPY seed.sh /usr/local/bin/seed.sh
COPY pki-bootstrap.sh /usr/local/bin/pki-bootstrap.sh
COPY kek-bootstrap.sh /usr/local/bin/kek-bootstrap.sh
RUN chmod +x /usr/local/bin/seed.sh /usr/local/bin/pki-bootstrap.sh /usr/local/bin/kek-bootstrap.sh /usr/local/bin/seed-encryptor
ENTRYPOINT ["/usr/local/bin/seed.sh"]
