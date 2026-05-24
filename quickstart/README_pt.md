# Quickstart MapexOS

Este guia te leva pela conexão de um sensor de temperatura ponta a
ponta numa stack MapexOS recém-instalada — usando a UI para o setup
e um script Node.js minúsculo para enviar dados quando tudo estiver no
lugar.

Escolha **um** caminho de ingestão (HTTP ou MQTT), ou faça os dois. Os
dois primeiros passos são compartilhados.

```
quickstart/
├── 01-asset-template/    # define como é um sensor de temperatura
├── 02-route-group/       # define o que fazer com os eventos (salvar)
├── 03-http-datasource/   # caminho HTTP: webhook URL + send-events.js
└── 04-mqtt-datasource/   # caminho MQTT: credenciais broker + publish-events.js
```

## Pré-requisitos

A stack está no ar e você consegue logar no frontend:

- Frontend: <http://localhost>
- Login: `admin@mapex.local` / `mapex@123`

Se a stack não está rodando, ver o [README raiz](../README_pt.md).

## Caso de uso

Uma estação meteorológica que reporta três valores:

| Campo          | Tipo   | Exemplo  |
|----------------|--------|----------|
| `temperature`  | number | `22.5`   |
| `humidity`     | number | `68`     |
| `batteryLevel` | number | `92`     |

Cada pasta traz payloads JSON prontos pra colar nos formulários da UI.
Depois do setup, o script `send-events.js` (HTTP) ou `publish-events.js`
(MQTT) na pasta correspondente dispara uma stream de leituras
sintéticas para você ver chegando no Grafana.

## O fluxo

1. **Asset template** (`01-asset-template/`) — descreve o device: que
   campos ele carrega, como extrair o identificador dele do payload
   que chega, e o script de conversão se houver.
2. **Route group** (`02-route-group/`) — descreve o que fazer com os
   eventos que chegam. O group do quickstart faz a coisa mais
   simples: armazena no ClickHouse para você consultar no Grafana.
3. **Datasource + Asset** (`03-` ou `04-`) — registra o caminho de
   ingestão (webhook HTTP ou acesso ao broker MQTT) e amarra ele a um
   asset concreto construído a partir do template.
4. **Mandar dados** — rode o script Node.js incluso. Ele empurra
   algumas leituras por segundo.
5. **Ver chegando** — abra o Grafana (<http://localhost:3001>,
   `admin` / `admin`) e visualize o que acabou de cair.

## Ordem

Faça as pastas em ordem numérica. As pastas HTTP e MQTT são
independentes entre si — pode fazer uma, a outra, ou as duas.

```
01-asset-template
   │
   ▼
02-route-group
   │
   ├─► 03-http-datasource   (escolha um ou os dois)
   │
   └─► 04-mqtt-datasource
```

## Limpeza

Tudo o que o quickstart cria é dado normal da plataforma. Apague pelo
UI (Assets, Datasources, Route Groups, Templates) quando terminar. Não
existe script de teardown separado.

## Quer um tour mais profundo?

O quickstart é deliberadamente estreito — um device, uma rota, um
script. Para o quadro completo (workflows, triggers, multi-tenant,
regras, plugins), ver a documentação da plataforma linkada no
[README raiz](../README_pt.md).
