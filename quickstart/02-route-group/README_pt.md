# 02 — Route group

Um **route group** é a lista de ações que a plataforma executa quando
um evento chega para um asset. Cada entrada dentro do group é um
router de um `kind` específico: `save_event`, `trigger`, `workflow`,
`lake_house` ou `notification`.

Todo asset precisa apontar para um ou mais route groups (de 1 a 3). O
quickstart usa um único route group com um único router que apenas
armazena os eventos no ClickHouse, para você consultar e gerar
gráficos no Grafana.

## Arquivos nesta pasta

- [`save-temperature-events.json`](./save-temperature-events.json) —
  cole isto no formulário de criação de route group.

## Passo a passo na UI

1. No menu lateral, abra **Routes → Route Groups**.
2. Clique em **Novo Route Group**.
3. Abra o
   [`save-temperature-events.json`](./save-temperature-events.json)
   no seu editor.
4. Preencha o formulário:
   - **Nome**: `Save Temperature Events`
   - **Versão**: `1.0.0`
   - **Habilitado**: ligado
5. Em **Routers**, clique em **Adicionar Router** e escolha **Save
   Event** como tipo. Mantenha a metadata como
   `{"source": "quickstart"}`.
6. Clique em **Salvar**.

Você deve ver "Save Temperature Events" listado em Route Groups.

**Copie o ID**: abra o route group que você acabou de criar e copie o
id dele da URL (ou da página de detalhes). Você vai colar no campo
`routeGroupIds` do asset no próximo passo.

## O que cada campo faz

| Campo         | Por que está aí                                                           |
|---------------|---------------------------------------------------------------------------|
| `version`     | String semver. Route groups carregam sua própria versão para evoluírem independentemente dos assets que os referenciam. |
| `enabled`     | Groups desabilitados continuam selecionáveis mas o router não dispara.    |
| `routers`     | As ações para cada evento. Use `save_event` no quickstart. Outros kinds (`trigger`, `workflow`, ...) plugam pipelines mais ricos. |

## Próximo

Escolha um caminho de ingestão:

- Webhook HTTP → [`03-http-datasource/`](../03-http-datasource/)
- Broker MQTT → [`04-mqtt-datasource/`](../04-mqtt-datasource/)

As duas pastas são auto-contidas e referenciam o template + route
group que você acabou de criar.
