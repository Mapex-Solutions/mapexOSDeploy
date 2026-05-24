# Source da imagem mongodb-init

Source da imagem Docker `thiagoanselmo/mongodb-init` que o
docker-compose de infra referencia como `mongodb-init`. Numa stack
nova, esse container:

1. Aguarda o MongoDB e inicializa o replica set `rs0`.
2. Roda o bootstrap de PKI (`pki-bootstrap.sh`) — gera o par de CA,
   escreve o cert do servidor do broker em `../../broker-certs`, e
   envelope-encripta as chaves privadas da CA em
   `${DB_PREFIX}mapex_vault.pkiCertificateAuthorities`.
3. Faz o seed de todo JSON em [`../seed/`](../seed/) para a collection
   MongoDB correspondente.

## Arquivos

| Arquivo | Função |
|---|---|
| `Dockerfile` | Build sobre `mongo:7` + openssl + o binário Go `seed-encryptor`. |
| `seed.sh` | Entrypoint. Orquestra wait → RS → PKI → seed. |
| `pki-bootstrap.sh` | Geração de PKI, encriptação e output de certificados. Idempotente. |
| `seed-encryptor/` | Pequeno programa Go que envelope-encripta as chaves privadas da CA com `CREDENTIAL_MASTER_KEY` antes de serem inseridas no mongo. |

## Idempotência

`seed.sh` faz upsert de todo documento de seed por `_id` (`bulkWrite`
com `replaceOne(_id, doc, {upsert: true})`). Re-rodar o container
nunca duplica documentos e restaura qualquer collection que tenha
sido apagada fora de banda — cada collection se reconcilia
independentemente.

## Build

A imagem publicada é o artefato canônico (`docker compose up` puxa
ela). Para build local:

```bash
cd infra/mongodb/init
docker build -t thiagoanselmo/mongodb-init:dev .
```

Depois aponte o compose para a tag local:

```bash
IMAGE_TAG=dev docker compose up -d mongodb-init --force-recreate
```
