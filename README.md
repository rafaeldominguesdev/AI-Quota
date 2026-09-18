# AI Quota

App de barra de menu do macOS que mostra, por IA que você usa (Claude Code, Codex, Cursor,
Gemini, Grok e qualquer CLI customizado), quanto já foi consumido da janela de uso atual e
quando ela reseta — direto na barra de menu, sem abrir terminal nem entrar no site de cada uma.

Tudo roda localmente: o app lê os logs/config que cada CLI já grava no seu disco. A única exceção
é o Claude Code, que também pode buscar o percentual ao vivo direto da Anthropic (ver
[Privacidade](#privacidade) abaixo) — nada é enviado para nenhum servidor deste projeto.

## O painel

Clicar no ícone da barra de menu abre um painel com uma seção por IA: logo, e-mail mascarado da
conta, selo do plano (`[P]`/`[M]`) e uma barra por janela de cota que a IA reporta (sessão de 5h,
semanal...). Quem tem mais de uma conta logada na mesma IA (ver
[Múltiplas contas](#múltiplas-contas) abaixo) vê as duas empilhadas sob o mesmo cabeçalho.

```
AI QUOTA                                                    1h17m

● [logo]  CLAUDE CODE
          r•••@g•••.com                                       [P]
          5H      [██████░░░░░░░░░░░░░░]  50%           em 1h17m
          SEMANAL  [███░░░░░░░░░░░░░░░░░]  30%            em 6d0h

● [logo]  CODEX (GPT)
          r•••@g•••.com                                       [P]
          5H      [██░░░░░░░░░░░░░░░░░░]  13%           em 3h54m
          SEMANAL  [███████████░░░░░░░░]  75%           em 2d18h

US$ 22,32 · 83,2 M tokens

Retrospecto
Abre no navegador o histórico de consumo das contas

· Iniciar no login

Ajustes
Atualizar leituras
Encerrar
```

- A cor da barra segue o nível de uso (verde → âmbar → vermelho), igual em toda janela de cota.
- **Retrospecto** gera, na hora, um relatório HTML local (dia a dia: tokens e custo estimado) a
  partir dos logs do Claude Code, e abre no navegador padrão — nenhum dado sai da máquina.
- **Atualizar leituras** força uma checagem imediata; o app já atualiza sozinho a cada 30s
  enquanto estiver aberto, então isso é só para confirmar na hora (ex.: acabou de rodar o CLI).

## Múltiplas contas

Se você roda mais de uma conta do Claude Code ou do Codex ao mesmo tempo — cada terminal
apontando `CLAUDE_CONFIG_DIR`/`CODEX_HOME` para uma pasta diferente —, o app detecta
automaticamente qualquer pasta em `$HOME` que comece com `.claude`/`.codex` (ex.: `.claude-work`)
e contenha o arquivo de conta esperado, e mostra cada uma como uma conta separada sob o mesmo
cabeçalho do provedor. É heurística (não há API documentada para isso), então se uma segunda conta
de verdade não aparecer, esse é o primeiro lugar a revisar (`MultiAccountDiscovery.swift`).

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
ele vive só na barra de menu. "Iniciar no login" no rodapé do painel registra o app como item
de login de verdade (via `SMAppService`), sem otimismo: só marca quando o macOS confirma.

## Rodando só o núcleo (CLI)

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

### A logo da sua IA

O app procura a imagem nesta ordem:

1. `~/.config/ai-quota/logos/<id-do-provedor>.png` — também aceita `.svg`, `.webp`, `.jpg` e
   `.jpeg`. É só criar a pasta e soltar o arquivo com o `id` que você deu ao provedor no
   `providers.json` (ex.: `~/.config/ai-quota/logos/glm.png` para o exemplo acima).
2. A logo que já vem embutida no app, quando existe: Claude Code, Codex, Grok, DeepSeek, Meta
   e Antigravity.
3. Um glifo geométrico desenhado pelo próprio app, para quem não tem nenhuma das duas.

## Privacidade

- O app só lê arquivos que já existem no seu disco (logs, configs, o `~/.claude.json` que o
  próprio Claude Code mantém) — nada é enviado para nenhum servidor deste projeto, e não há
  telemetria nem analytics de nenhum tipo.
- **Exceção**: para o Claude Code, o app também pode buscar o percentual de uso **direto no
  endpoint oficial da Anthropic** (o mesmo que o `claude.ai`/CLI usam), porque o cache local
  (`~/.claude.json`) só é atualizado quando você roda o `claude` — se você passa um tempo sem
  usá-lo, o número local fica desatualizado. Essa chamada usa o **seu próprio token OAuth**,
  lido de `~/.claude/.credentials.json` ou do Keychain do macOS (item "Claude Code-credentials",
  o mesmo que o CLI já usa), enviado só para `api.anthropic.com` — nunca para nenhum outro
  destino. Ver `Sources/AIQuotaCore/ClaudeCode/ClaudeLiveUsageReader.swift`.
- O e-mail da conta aparece sempre mascarado no painel (`r•••@g•••.com`).
- `~/.grok` guarda a chave de API do Grok em texto puro — o app nunca lê esse arquivo (não há
  uso local pra ler ali mesmo), mas trate-o como sensível por conta própria.

## Limites

- O **teto de custo usado para estimar o percentual quando não há limite oficial disponível
  (padrão US$ 50 por bloco de 5h) é uma referência configurável, não um limite documentado pela
  Anthropic** — ajuste em `QuotaConfig` conforme o seu plano real. Isso só é usado como último
  recurso: quando não há limite oficial nem cache local nem resposta da rede.
- O custo em si é uma **estimativa** calculada a partir da tabela de preços em
  `Sources/AIQuotaCore/Pricing/ModelPricing.swift`, que precisa ser atualizada manualmente
  se a Anthropic mudar os valores. Para modelos desconhecidos, o app usa o preço do Sonnet
  como aproximação e sinaliza isso nos dados (`isEstimatedPricing`).
- Os dados do **Cursor** e do **Gemini** trazem apenas contagem (usos por modelo, ou
  interações) — essas fontes não expõem tokens nem custo (ver `docs/DATA-SOURCES.md`).
- O **Codex** tem tokens completos (entrada/saída separados), mas **nunca tem custo em
  dólar** — é assinatura, não paga por token. Quando a sessão local tem um `rate_limits`
  oficial preenchido, o app mostra esse percentual em vez de estimar algo por conta própria.
- O **Grok** não tem leitura implementada porque não há o que ler: `~/.grok` só guarda
  configuração, sem nenhuma sessão ou histórico de uso local.
- O endpoint ao vivo do Claude Code **não é documentado publicamente pela Anthropic** —
  é o mesmo que o próprio CLI usa, mas o formato da resposta pode mudar sem aviso. O parse é
  tolerante e qualquer falha cai de volta pro cache local e, por fim, pra estimativa por custo —
  nunca trava o app.
- Provedores **customizados** (via `providers.json`) dependem inteiramente do que você
  configurar — se o CLI de terceiros mudar o formato dos logs, os caminhos configurados
  param de bater e o provedor aparece como "sem dado de token" ou "não instalado", nunca
  quebra o resto do app.
