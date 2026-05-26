# Quickstart MapexOS

Caminhe pela UI do MapexOS pra conectar um sensor de temperatura
ponta a ponta. Dois sabores, um por caminho de ingestão:

```
quickstart/
├── device-http/    # sensor que posta telemetria num webhook URL
└── device-mqtt/    # sensor que publica no broker MQTT  (chega em breve)
```

Cada pasta é **auto-contida**: um README que percorre cada
formulário da UI (asset template → route group → datasource →
asset → teste) campo por campo, mais um script Node.js que empurra
leituras sintéticas depois do setup.

## Pré-requisitos

A stack está no ar e você consegue logar no frontend:

- Frontend: <http://localhost> (ou seu `MAPEXOS_PUBLIC_HOST`)
- Login: `admin@mapex.local` / `mapex@123`

Se a stack não está rodando, ver o
[README raiz](../README_pt.md).

## Escolha um caminho

| Caminho | Indicado para | Pasta |
|---|---|---|
| **HTTP** | Devices que postam JSON num webhook (endpoints REST, gateways, lambdas). | [`device-http/`](./device-http/) |
| **MQTT** | Devices que publicam num broker MQTT (firmware IoT padrão de mercado). | [`device-mqtt/`](./device-mqtt/) |

## O que você terá no fim

- Um **asset template** (`Temperature Sensor`) declarando a forma
  de dado e os scripts de preprocessor / validator / conversion.
- Um **route group** (`Save Temperature Events`) que persiste cada
  leitura no ClickHouse.
- Para HTTP: um **datasource** com URL de webhook + API key.
- Um **asset** (`weather-http-001` ou `weather-mqtt-001`) amarrado
  ao template, ao route group e ao protocolo escolhido.
- Leituras chegando ao Grafana — abra <http://localhost:3001>
  (`admin` / `admin`) e filtre o dashboard de eventos por
  `assetUUID`.

## Limpeza

Tudo criado pelo quickstart é dado normal da plataforma — apague
pelo UI (Assets, Datasources, Route Groups, Templates) quando
terminar. Sem script de teardown.

## Próximos passos

O quickstart é deliberadamente estreito — um device, uma rota, uma
stream de teste. Para workflows, plugins, multi-tenant, match
rules, triggers e cofre de credenciais, veja a documentação da
plataforma linkada no [README raiz](../README_pt.md).
