# AI Quota

App de barra de menu do macOS que mostra quanto você já consumiu da janela de uso atual do
Claude Code (bloco de 5 horas) e quando ela reseta — direto na barra de menu, sem precisar
abrir terminal.

## O que aparece na barra

Um ícone de medidor seguido do percentual da janela atual, com a cor do texto mudando
conforme o estado:

```
[gauge] 42%     ← verde   (uso tranquilo)
[gauge] 72%     ← laranja (atenção)
[gauge] 91%     ← vermelho (crítico)
[gauge] —       ← cinza   (sem bloco ativo no momento)
```

Ao clicar, abre um painel com o detalhamento:

```
AI Quota
Claude Code · janela de 5 horas

[███████████░░░░░░░░░░░░░░░░░]  42%

Tokens usados        12.984.414
Custo estimado        US$ 6.32
Início da janela         16:00
Reinicia em      3h56m · 21:00

Por modelo
claude-sonnet-5      10.320.971   US$ 3.71
claude-opus-5           512.477   US$ 0.83
claude-haiku-4-5        713.612   US$ 0.18

Atualizado às 17:04     Atualizar agora     Sair
```

Se o Cursor tiver dados de uso registrados na janela atual, uma seção extra "Cursor" aparece
com a contagem de usos por modelo (sem custo — essa fonte não expõe tokens, ver
`docs/DATA-SOURCES.md`).

## Como compilar

Requer apenas o Xcode Command Line Tools (sem Xcode completo) e Swift Package Manager.

```bash
bash scripts/build-app.sh
```

Isso gera `dist/AI Quota.app`, já assinado ad-hoc e pronto para rodar. O script é
idempotente — pode rodar quantas vezes quiser.

## Como instalar

Arraste `dist/AI Quota.app` para `/Applications`. Depois é só abrir normalmente
(Spotlight, Launchpad ou dando duplo clique). O app não aparece no Dock nem no Cmd+Tab —
ele vive só na barra de menu.

## Rodando só o núcleo (CLI)

Para inspecionar os números sem abrir a interface gráfica:

```bash
swift run aiquota-cli          # saída legível no terminal
swift run aiquota-cli --json   # saída em JSON
```

## Limites

- O **teto de custo usado para calcular o percentual da barra (padrão US$ 50 por bloco de
  5h) é uma referência configurável, não um limite oficial documentado pela Anthropic**.
  Ele existe só para dar uma noção visual de "quanto já gastei nesse bloco" — ajuste o
  valor em `QuotaConfig` conforme o seu uso real.
- O custo em si é uma **estimativa** calculada a partir da tabela de preços em
  `Sources/AIQuotaCore/Pricing/ModelPricing.swift`, que precisa ser atualizada manualmente
  se a Anthropic mudar os valores. Para modelos desconhecidos, o app usa o preço do Sonnet
  como aproximação e sinaliza isso nos dados (`isEstimatedPricing`).
- Os dados do **Cursor** trazem apenas contagem de usos por modelo — essa fonte não expõe
  tokens nem custo (ver `docs/DATA-SOURCES.md`).
- O **Codex** não tem leitura implementada: na máquina usada para mapear as fontes de
  dados o diretório `~/.codex` não existia com um formato documentado, então o núcleo só
  verifica a presença do diretório, sem inventar um parser.
