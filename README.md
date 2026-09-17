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

O núcleo é multi-provedor: além do Claude Code, ele também lê Codex, Gemini, Grok, Cursor e
qualquer provedor customizado que você configurar (veja a seção abaixo). O painel gráfico (por
enquanto) ainda mostra só Claude Code + Cursor — o CLI é a forma completa de ver todo mundo.

```bash
swift run aiquota-cli              # um bloco por provedor, saída legível
swift run aiquota-cli --json       # o mesmo, em JSON (QuotaOverview)
swift run aiquota-cli --providers  # só lista os provedores detectados e o caminho de cada um
```

## Adicionando outras IAs

Se você usa um CLI de IA que este app não conhece (GLM, Qwen, DeepSeek, ou qualquer outro que
escreva logs em JSONL), dá pra adicionar sem recompilar nada. Edite
`~/.config/ai-quota/providers.json` (o app cria esse arquivo sozinho, com um exemplo comentado,
na primeira vez que rodar) e acrescente um item em `"custom"`:

```json
{
  "primaryProviderId": "claude-code",
  "custom": [
    {
      "id": "glm",
      "displayName": "GLM",
      "enabled": true,
      "logGlob": "~/.glm/sessions/**/*.jsonl",
      "timestampPath": "timestamp",
      "modelPath": "model",
      "inputTokensPath": "usage.input_tokens",
      "outputTokensPath": "usage.output_tokens",
      "totalTokensPath": "usage.total_tokens",
      "cumulative": false,
      "pricing": { "inputPer1M": 0.5, "outputPer1M": 1.5 }
    }
  ]
}
```

Campo a campo:

- `logGlob`: onde procurar os arquivos de log. Suporta um `**` para busca recursiva (ex.:
  `~/.glm/sessions/**/*.jsonl`).
- `timestampPath`, `modelPath`, `inputTokensPath`, `outputTokensPath`, `totalTokensPath`:
  caminhos de chave separados por ponto dentro de cada linha JSON do log (ex.: um campo em
  `payload.info.usage.input_tokens` vira `"payload.info.usage.input_tokens"`). Todos exceto
  `timestampPath` são opcionais — sem `inputTokensPath`/`outputTokensPath` mas com
  `totalTokensPath`, o provedor vira "só total de tokens"; sem nenhum dos três, vira "só
  contagem de interações".
- `cumulative`: `true` se os contadores de token no log forem totais acumulados da sessão
  (como o Codex) em vez de já virem por evento — nesse caso o app calcula os deltas sozinho,
  por arquivo, na ordem em que aparecem.
- `pricing`: opcional. Se seu provedor cobra por token (diferente de assinatura fixa), informe
  o preço por 1 milhão de tokens de entrada/saída para ter uma estimativa de custo.

Um provedor customizado malformado (sem `id`, `logGlob` etc.) é **ignorado**, não derruba o
resto — a mensagem de erro aparece em `configWarnings` no `--json` e como aviso no CLI normal.

## Limites

- O **teto de custo usado para calcular o percentual da barra (padrão US$ 50 por bloco de
  5h) é uma referência configurável, não um limite oficial documentado pela Anthropic**.
  Ele existe só para dar uma noção visual de "quanto já gastei nesse bloco" — ajuste o
  valor em `QuotaConfig` conforme o seu uso real.
- O custo em si é uma **estimativa** calculada a partir da tabela de preços em
  `Sources/AIQuotaCore/Pricing/ModelPricing.swift`, que precisa ser atualizada manualmente
  se a Anthropic mudar os valores. Para modelos desconhecidos, o app usa o preço do Sonnet
  como aproximação e sinaliza isso nos dados (`isEstimatedPricing`).
- Os dados do **Cursor** e do **Gemini** trazem apenas contagem (usos por modelo, ou
  interações) — essas fontes não expõem tokens nem custo (ver `docs/DATA-SOURCES.md`).
- O **Codex** tem tokens completos (entrada/saída separados), mas **nunca tem custo em
  dólar** — é assinatura, não paga por token, então não há preço pra multiplicar. Quando a
  sessão local tem um `rate_limits` oficial preenchido, o app mostra esse percentual em vez
  de estimar algo por conta própria.
- O **Grok** não tem leitura implementada porque não há o que ler: `~/.grok` só guarda
  configuração (incluindo a chave de API do usuário — trate esse arquivo como sensível),
  sem nenhuma sessão ou histórico de uso local.
- Provedores **customizados** (via `providers.json`) dependem inteiramente do que você
  configurar — se o CLI de terceiros mudar o formato dos logs, os caminhos configurados
  param de bater e o provedor aparece como "sem dado de token" ou "não instalado", nunca
  quebra o resto do app.
