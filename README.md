# AI Quota

App de barra de menu do macOS que mostra, por IA, quanto da cota atual já foi usada e quando ela
reseta — sem abrir terminal nem entrar no site de cada uma. Suporta Claude Code, Codex,
Antigravity, Cursor, Grok e qualquer CLI customizado.

Tudo roda localmente: o app lê os logs e configs que cada CLI já grava no disco. Duas exceções,
que continuam usando só o seu próprio token e nunca um servidor deste projeto: o Claude Code, que
busca o percentual direto no endpoint da Anthropic, e o Antigravity, que roda o próprio CLI (`agy`)
para obter a cota. Ver [Privacidade](#privacidade).

## O painel

Clicar no ícone abre um painel com uma seção por IA: logo, e-mail mascarado da conta, uma barra
por janela de cota (5h, semanal) e uma tecla que abre a página da IA no navegador.

```
AI QUOTA                                          2h56m

  CLAUDE CODE                                       [C]
  r•••@g•••.com
  5H       [██████░░░░░░░░]  71%             em 2h56m
  SEMANAL  [██████░░░░░░░░]  66%             em 4d17h

  ANTIGRAVITY                                       [A]
  r•••@g•••.com
  SEMANAL  [█░░░░░░░░░░░░░]   5%             em 6d23h

  CODEX (GPT)                                       [X]
  r•••@g•••.com
  5H       [░░░░░░░░░░░░░░]   0%
  SEMANAL  [██████████░░░░]  75%             em 1d11h

  US$ 26,62 · 43,6 M tokens

  Retrospecto
  Ajustes
  Atualizar leituras
  Encerrar
```

- A cor da barra segue o nível de uso: verde, âmbar, vermelho.
- Cada IA tem uma tecla (Claude=C, Codex=X, Antigravity=A, Cursor=U, Grok=K) que abre a página de
  conta dela no navegador.
- **Retrospecto** gera um relatório HTML local (dia a dia: tokens e custo estimado dos logs do
  Claude Code) e abre no navegador. Nada sai da máquina.
- **Atualizar leituras** força uma checagem na hora; o app já atualiza sozinho a cada 30s.

## Ajustes

Item **Ajustes** abre uma janela com três abas:

- **STATUS**: as contas conectadas, uma por card com a barra de cota.
- **CONECTAR**: as IAs conhecidas que ainda não estão conectadas, com o caminho no disco.
- **AJUSTES**: "Iniciar no login" (via `SMAppService`, só marca quando o macOS confirma) e os
  caminhos dos arquivos de configuração.

## Compilar e instalar

Requer apenas o Xcode Command Line Tools e o Swift Package Manager.

```bash
bash scripts/build-app.sh
```

Gera `dist/AI Quota.app`, assinado ad-hoc e pronto para rodar (o script é idempotente). Arraste-o
para `/Applications` e abra normalmente. O app vive só na barra de menu — não aparece no Dock nem
no Cmd+Tab.

## CLI

O mesmo núcleo roda em linha de comando:

```bash
swift run aiquota-cli              # um bloco por provedor, saída legível
swift run aiquota-cli --json       # o mesmo, em JSON (QuotaOverview)
swift run aiquota-cli --providers  # lista os provedores detectados e o caminho de cada um
```

## Adicionar outras IAs

Um CLI que o app não conhece, desde que escreva logs em JSONL, entra sem recompilar. Edite
`~/.config/ai-quota/providers.json` (criado sozinho, com um exemplo comentado, na primeira
execução) e acrescente um item em `"custom"`:

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

- `logGlob`: onde procurar os logs. Aceita um `**` para busca recursiva.
- `timestampPath`, `modelPath`, `inputTokensPath`, `outputTokensPath`, `totalTokensPath`: caminhos
  de chave separados por ponto dentro de cada linha JSON. Só `timestampPath` é obrigatório; sem os
  de token o provedor vira "só total" ou "só contagem".
- `cumulative`: `true` se os contadores forem totais acumulados da sessão (como o Codex); o app
  calcula os deltas.
- `pricing`: opcional, preço por 1 milhão de tokens de entrada/saída, para estimar custo.

Um provedor malformado é ignorado (a mensagem sai em `configWarnings`), sem derrubar o resto.

Para a logo, o app procura, nesta ordem: `~/.config/ai-quota/logos/<id>.png` (também `.svg`,
`.webp`, `.jpg`, `.jpeg`); a logo embutida (Claude Code, Codex, Antigravity, Cursor, Grok,
DeepSeek, Meta); ou um glifo desenhado pelo próprio app.

## Privacidade

- O app só lê arquivos que já existem no disco. Sem telemetria, sem analytics, sem servidor deste
  projeto.
- **Claude Code**: além do cache local, busca o percentual no endpoint oficial da Anthropic
  (`api.anthropic.com`), usando o seu token OAuth de `~/.claude/.credentials.json` ou do Keychain.
  Ver `Sources/AIQuotaCore/ClaudeCode/ClaudeLiveUsageReader.swift`.
- **Antigravity**: roda `agy --print "/usage"` — o seu próprio CLI, que se autentica sozinho. O app
  não lê o token do Antigravity. Ver `Sources/AIQuotaCore/Antigravity/AntigravityUsageReader.swift`.
- O e-mail aparece sempre mascarado (`r•••@g•••.com`).

## Limites e estimativas

- **Claude Code**: tokens completos. Quando não há limite oficial (endpoint e cache indisponíveis),
  o percentual é estimado contra um teto de custo de referência (padrão US$ 50 por bloco de 5h,
  ajustável em `QuotaConfig`) — não é um limite documentado pela Anthropic. O custo vem da tabela em
  `Sources/AIQuotaCore/Pricing/ModelPricing.swift`, atualizada à mão; modelo desconhecido usa o
  preço do Sonnet e é marcado como estimado.
- **Antigravity**: cota semanal real do grupo Gemini, via `agy`. Não tem janela de sessão nem
  tokens. Se o `agy` falhar (offline, deslogado), cai para a contagem de sessões do CLI.
- **Codex**: tokens completos, mas sem custo em dólar (é assinatura). Usa o `rate_limits` oficial da
  sessão local quando existe.
- **Cursor**: só contagem de usos por modelo — a fonte não expõe tokens nem custo.
- **Grok**: sem leitura, porque `~/.grok` só guarda configuração, sem histórico de uso.
- O endpoint ao vivo do Claude Code e o `/usage` do Antigravity não são documentados publicamente;
  o parse é tolerante e qualquer falha cai para o próximo recurso, sem travar o app.

## Múltiplas contas

Rodando mais de uma conta do Claude Code ou do Codex ao mesmo tempo (cada terminal com
`CLAUDE_CONFIG_DIR`/`CODEX_HOME` apontando para uma pasta), o app detecta qualquer pasta em `$HOME`
que comece com `.claude`/`.codex` e tenha o arquivo de conta, e mostra cada uma separada sob o
mesmo provedor. É heurística; se uma segunda conta não aparecer, revise `MultiAccountDiscovery.swift`.
