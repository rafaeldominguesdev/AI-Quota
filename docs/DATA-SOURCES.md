# Fontes de Dados de Uso de IA

## 1. CLAUDE CODE

### Localização
- **Arquivos principais**: `~/.claude/projects/[project-hash]/[session-uuid].jsonl`
- **Diretório de referência**: `~/.claude/history.jsonl` (índice global)
- **Pastas adicionais**: `~/.claude/sessions/`, `~/.claude/telemetry/`
- **Total**: 17+ projetos, 108k+ linhas de logs

### Dados Aproveitáveis
✅ **SIM** — Contém dados completos de tokens de todas as sessões Claude Code.

### Estrutura Real de uma Linha (tipo "assistant")

```json
{
  "type": "assistant",
  "timestamp": "2026-09-17T16:39:27.573Z",
  "model": "claude-opus-5",
  "sessionId": "391b6f54-4b67-4b59-aeff-d4701dfb24e2",
  "message": {
    "model": "claude-opus-5",
    "usage": {
      "input_tokens": 2,
      "cache_creation_input_tokens": 23113,
      "cache_read_input_tokens": 20137,
      "output_tokens": 438,
      "output_tokens_details": {
        "thinking_tokens": 266
      },
      "service_tier": "standard",
      "cache_creation": {
        "ephemeral_1h_input_tokens": 23113,
        "ephemeral_5m_input_tokens": 0
      },
      "speed": "standard"
    }
  }
}
```

### Campos de Interesse

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `timestamp` | String ISO 8601 | Quando a resposta foi gerada. Ex: `2026-09-17T16:39:27.573Z` |
| `model` | String | Modelo usado. Ex: `claude-opus-5` |
| `type` | String | Tipo de evento; procurar por `"assistant"` para respostas com uso. |
| `message.usage.input_tokens` | Integer | Tokens de entrada normais |
| `message.usage.output_tokens` | Integer | Tokens de saída gerados |
| `message.usage.cache_creation_input_tokens` | Integer | Tokens usados para criar cache (prompt caching) |
| `message.usage.cache_read_input_tokens` | Integer | Tokens já em cache (economia) |
| `message.usage.output_tokens_details.thinking_tokens` | Integer | Tokens de "thinking" (raciocínio) |
| `sessionId` | String UUID | Identifica a sessão/conversa |

### Range de Timestamps
- **Mais antigo**: Variável por projeto (ex: 1781471750649 em unix ms)
- **Mais recente**: 2026-09-17T16:39:27.573Z (ISO 8601)
- **Formato**: ISO 8601 em `.jsonl` (`2026-09-17T16:39:27.573Z`), Unix milliseconds em `history.jsonl`

### Como Calcular Uso da Sessão Atual

1. **Filtrar** linhas onde `type === "assistant"` no arquivo `.jsonl` da sessão atual
2. **Somar** `input_tokens + cache_creation_input_tokens` (tokens de entrada pagos)
3. **Somar** `output_tokens` (tokens de saída pagos)
4. **Ignorar** `cache_read_input_tokens` (não custam, apenas rastreados)
5. **Agrupar** por `model` para custo separado por modelo (ex: Opus vs Sonnet)
6. **Aplicar multiplicador de custo** conforme tabela de preços Anthropic (ex: Opus ~$15/$60 por M tokens)

---

## 2. CODEX (OpenAI Codex CLI)

### Localização
- **Diretório**: `~/.codex/`
- **Sessões**: `~/.codex/sessions/AAAA/MM/DD/rollout-<timestamp>-<uuid>.jsonl` (145 arquivos na máquina de referência)
- **Histórico global**: `~/.codex/history.jsonl`
- **Outros**: `~/.codex/thread_history_1.sqlite`, `~/.codex/logs_2.sqlite`, arquivos de configuração

### Dados Aproveitáveis
✅ **SIM** — CORREÇÃO: uma versão anterior deste documento afirmava que não havia tokens aqui.
Isso estava **errado**. Os arquivos `.jsonl` em `~/.codex/sessions/` têm, sim, tokens completos
de entrada e saída, e em alguns casos até um limite de uso **oficial** (rate limit).

### Estrutura Verificada

Linhas com `"type": "event_msg"` e `payload.type == "token_count"` trazem:

```json
{
  "timestamp": "2026-08-29T22:26:30.511Z",
  "type": "event_msg",
  "payload": {
    "type": "token_count",
    "info": {
      "total_token_usage": {
        "input_tokens": 33728316, "cached_input_tokens": 32069760,
        "cache_write_input_tokens": 0, "output_tokens": 135076,
        "reasoning_output_tokens": 40667, "total_tokens": 33863392
      },
      "last_token_usage": {
        "input_tokens": 124695, "cached_input_tokens": 124544,
        "cache_write_input_tokens": 0, "output_tokens": 156,
        "reasoning_output_tokens": 0, "total_tokens": 124851
      },
      "model_context_window": 258400
    },
    "rate_limits": {
      "limit_id": "codex", "primary": { "used_percent": 11.0, "window_minutes": 300, "resets_at": 1788669903 },
      "secondary": { "used_percent": 2.0, "window_minutes": 10080, "resets_at": 1789256703 },
      "plan_type": "plus"
    }
  }
}
```

**Ponto crítico, confirmado inspecionando um arquivo real com 428 eventos `token_count`:**
`total_token_usage` é **cumulativo** dentro da sessão (chega a mais de 33 milhões de tokens
numa sessão longa). `last_token_usage` é o **delta daquele turno**. Para somar uso por janela
de tempo, use sempre `last_token_usage` por evento — somar `total_token_usage` infla o total
em ordens de grandeza.

`rate_limits.primary`/`secondary` costumam vir `null` (só `credits` preenchido), mas em várias
sessões vêm preenchidos com `used_percent`, `window_minutes` e `resets_at` (Unix segundos) — um
limite **oficial** do provedor, preferível a qualquer estimativa própria.

O modelo ativo aparece em linhas `"type": "turn_context"`, campo `payload.model` (ex.:
`"gpt-6-astra"`) — mais simples e confiável do que tentar extrair de `session_meta`.

### Histórico Global

`~/.codex/history.jsonl` contém apenas `display`, `timestamp` (Unix ms), `type`, `workspace` —
sem tokens. Não é essa a fonte usada para uso; os arquivos de sessão em `sessions/` é que importam.

### Como Proceder
Somar `last_token_usage` por evento dentro da janela de tempo desejada. Não é possível estimar
custo em dólar (Codex é assinatura, não paga por token diretamente), mas o `rate_limits.primary`,
quando presente, dá um percentual de uso oficial pronto para exibir.

---

## 3. GROK (xAI CLI)

### Localização
- **Diretório**: `~/.grok/`
- **Configuração**: `~/.grok/settings.json`, `~/.grok/user-settings.json`

### Dados Aproveitáveis
❌ **NÃO** — Apenas arquivos de configuração, sem dados de sessão ou uso.

### Conteúdo
```json
{
  "model": "grok-code-fast-1"
}
```

Não há pastas de sessão (`sessions/`, `history/`, `logs/`), nem arquivos `.jsonl` ou `.db` com registro de conversas.

### Como Proceder
Grok CLI (se usado) armazenaria dados em outro local (potencialmente servidor remoto ou arquivo não descoberto). Sem dados locais, é impossível rastrear uso sem integração com API da xAI.

---

## 4. GEMINI (Google Gemini CLI)

### Localização
- **Diretório**: `~/.gemini/`
- **CLI**: `~/.gemini/antigravity-cli/`
- **Histórico**: `~/.gemini/antigravity-cli/history.jsonl`
- **Logs**: `~/.gemini/antigravity-cli/brain/[id]/.system_generated/logs/`

### Dados Aproveitáveis
❌ **NÃO** — Contém histórico de conversas, mas **NÃO inclui dados de tokens de API**.

### Estrutura de history.jsonl

```json
{
  "display": "user's message or system action",
  "timestamp": 1695321600000,
  "type": "session|message",
  "workspace": "..."
}
```

Campos: `display`, `timestamp` (Unix ms), `type`, `workspace`. **Sem campos input_tokens, output_tokens, prompt_tokens ou completion_tokens.**

### Logs

Diretórios em `~/.gemini/antigravity-cli/brain/[session-id]/.system_generated/logs/chunks/` contêm transcripts, mas são textos sem metadados estruturados de tokens.

### Como Proceder
Gemini CLI não expõe dados de tokens de API em arquivos locais. Seria necessário integração com Google Cloud API para obter dados de uso/custo em tempo real.

---

## 5. CURSOR (Cursor IDE)

### Localização
- **Banco de dados**: `~/.cursor/ai-tracking/ai-code-tracking.db` (SQLite 3)
- **Arquivos adicionais**: `~/.cursor/projects/*/repo.json`, `~/.cursor/cli-config.json`

### Dados Aproveitáveis
❌ **NÃO** — Contém rastreamento de código gerado, mas **NÃO inclui tokens de entrada/saída de API**.

### Tabelas do Banco

```
ai_code_hashes        — Hashes de código gerado (modelo, timestamp)
conversation_summaries — Resumos de conversas (modelo, timestamp)
ai_deleted_files      — Arquivos excluídos via IA (modelo, timestamp)
tracked_file_content  — Conteúdo rastreado de arquivos
```

### Campos Disponíveis (ai_code_hashes)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `model` | String | Modelo Cursor usado (ex: `gpt-4`) |
| `createdAt` | Integer | Timestamp Unix em milissegundos |
| `conversationId` | String UUID | ID da conversa |
| `hash` | String (PK) | SHA da geração |
| `fileName` | String | Nome do arquivo gerado |
| `source` | String | Origem da geração |

### Limitações
- **Sem dados de tokens**: Não há campos `input_tokens`, `output_tokens`, `prompt_tokens` ou `completion_tokens`
- **Sem custo direto**: Impossível calcular consumo de API sem dados de token
- **Apenas contagem**: Conta quantas vezes o modelo foi usado, não quanto custou
- **Última atualização**: trackingStartTime = 1780356359647 (Unix ms, ~1 jun 2025)

### Como Proceder
Para dados Cursor: apenas conte quantidade de usos por modelo, não custo. Para custo real, seria necessário acessar logs internos de API do Cursor (não disponíveis publicamente).

---

## Tabela-resumo: Viabilidade por Provedor

| Provedor | Caminho Local | Dados de Token? | Custo Calculável? | Recomendação |
|---|---|---|---|---|
| **Claude Code** | `~/.claude/projects/*/*.jsonl` | ✅ SIM (entrada/saída separados) | ✅ SIM | ✅ Provedor principal |
| **Codex** | `~/.codex/sessions/**/*.jsonl` | ✅ SIM (entrada/saída separados, via `last_token_usage`) | ❌ Não (assinatura, sem preço por token) — mas tem **limite oficial** (`rate_limits`) quando disponível | ✅ Implementado |
| **Gemini** | `~/.gemini/antigravity-cli/history.jsonl` | ❌ Não (só timestamp de interação) | ❌ Não | ⚠️ Contagem apenas |
| **Cursor** | `~/.cursor/ai-tracking/*.db` | ❌ Não | ❌ Não | ⚠️ Contagem apenas |
| **Grok** | `~/.grok/` (apenas config) | ❌ Não | ❌ Não | ❌ Sem dados locais |

---

## Recomendação para o App AI-Quota

### Implementar com tokens completos

✅ **Claude Code** — provedor principal (padrão)
- Todos os dados de token estão presentes e estruturados
- Cálculo de custo em USD é direto (tabela de preços própria, editável)

✅ **Codex** — tokens completos, sem custo em dólar
- `last_token_usage` por evento dá entrada/saída separados de verdade
- Nunca somar `total_token_usage` (cumulativo) — ver seção 2 acima
- Quando `rate_limits.primary` vem preenchido, expor esse percentual **oficial** em vez de estimar

### Contagem apenas (sem token)

⚠️ **Cursor** — só contagem de usos por modelo, nunca custo
⚠️ **Gemini** — só contagem de interações (`history.jsonl` não tem nenhum campo de token em
lugar nenhum de `~/.gemini`, confirmado por busca em toda a árvore)

### Sem dados locais

❌ **Grok** — `~/.grok` só tem `settings.json`/`user-settings.json` (configuração, incluindo a
chave de API), nenhuma sessão, histórico ou log de uso local


## ANTIGRAVITY (cota real via `agy`)

O número da cota **nunca é gravado em disco** — nem o CLI nem a IDE salvam; só consultam o
servidor e mostram na tela. O token OAuth em texto puro (`~/.gemini/antigravity-cli/antigravity-oauth-token`)
expira e não é renovado ao usar a IDE, e não deve ser lido (credencial).

A fonte da cota é rodar o próprio CLI do usuário:

```bash
agy --print "/usage" --output-format json
```

Devolve `command.data.groups[].buckets[]`, cada bucket com `remaining_fraction` (0..1, quanto
SOBRA), `window` ("weekly") e `reset_time` (ISO). O AI Quota usa **só o grupo "Gemini Models"**
(o "Claude and GPT models" é ignorado a pedido do usuário) e converte para "usado %" = 100 − sobra.
Só existe janela **semanal** — não há bucket de sessão/5h nos dados do Antigravity.

`/usage` é comando de cliente: não gasta cota nem dispara turno (`num_turns: 0`). O `agy` fica em
`~/.local/bin/agy`. Ver `AntigravityUsageReader`.
