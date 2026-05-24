# 01 — Asset template

Um **asset template** é o blueprint de um tipo de device. Ele declara
os campos que o device reporta, o caminho para extrair o id único do
device dos payloads que chegam, e qualquer script de conversão que
rode antes do roteamento.

Neste quickstart o template descreve um sensor de temperatura genérico
que reporta `temperature`, `humidity` e `batteryLevel`.

## Arquivos nesta pasta

- [`temperature-sensor-template.json`](./temperature-sensor-template.json)
  — cole isto no formulário de criação de template.

## Passo a passo na UI

1. No menu lateral, abra **Admin → Asset Templates**.
2. Clique em **Novo Template** (canto superior direito).
3. Abra o
   [`temperature-sensor-template.json`](./temperature-sensor-template.json)
   no seu editor.
4. Copie os valores para os campos do formulário — ou use a visão JSON
   se a página oferecer.
5. Clique em **Salvar**.

Você deve ver "Temperature Sensor" listado em Asset Templates.

## O que cada campo faz

| Campo             | Por que está aí                                                           |
|-------------------|---------------------------------------------------------------------------|
| `name`            | Nome de exibição mostrado na UI e nas listas.                             |
| `enabled`         | Mantenha `true` — templates desabilitados não podem ser usados ao criar asset. |
| `assetIdPath`     | Caminho JSON usado para achar o id único do asset nos payloads que chegam. Os payloads do quickstart carregam o id em `assetUUID`, então o caminho é apenas `assetUUID`. |
| `scriptConversion`| Expressão JS que transforma o payload antes do roteamento. O quickstart devolve o payload sem alterações. |
| `availableFields` | Nomes expostos ao autocomplete de regras na UI (para você montar regras que referenciem esses campos). |
| `dynamicFields`   | Campos que são indexados e armazenados em colunas tipadas. O quickstart declara 3 campos numéricos; a plataforma armazena em colunas dedicadas para consultas eficientes. |

## Próximo

Siga para [`02-route-group/`](../02-route-group/) — todo asset
precisa apontar para pelo menos um route group, para que a plataforma
saiba o que fazer com os eventos que chegam.
