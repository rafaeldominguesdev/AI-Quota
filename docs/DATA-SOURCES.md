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

## 2. CODEX / CHATGPT CLI

### Status
❌ **NÃO ENCONTRADO** — Não existe `~/.codex` ou `~/.config/codex`

### Resultado
Diretório não existe no sistema. OpenAI CLI (se instalada) armazenaria em local diferente.

---

## 3. CURSOR

### Localização
- **Banco de dados**: `~/.cursor/ai-tracking/ai-code-tracking.db` (SQLite 3)
- **Arquivos adicionais**: `~/.cursor/projects/*/repo.json`, `~/.cursor/cli-config.json`

### Dados Aproveitáveis
⚠️ **PARCIAL/NÃO RECOMENDADO** — Contém rastreamento de código gerado e conversas, mas **NÃO inclui tokens de entrada/saída de API**.

### Tabelas Relevantes

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

### Limitações
- **Sem dados de tokens**: Não há campos `input_tokens` ou `output_tokens`
- **Sem custo direto**: Impossível calcular consumo de API sem dados de token
- **Apenas contagem**: Conta quantas vezes o modelo foi usado, não quanto custou
- **Última atualização**: trackingStartTime = 1780356359647 (Unix ms, ~1 jun 2025)

### Como Proceder
Se precisar de dados Cursor: apenas conte quantidade de usos por modelo, não custo. Para custo real, seria necessário acessar logs internos de API do Cursor (não disponíveis publicamente).

---

## Recomendação para o App AI-Quota

✅ **Use Claude Code como fonte principal** — tem todos os dados necessários, estruturados e com precisão de tokens.

⚠️ **Cursor** — se incluir, fazer apenas contagem de usos (não será possível calcular custo em R$ sem dados de token).

❌ **ChatGPT CLI** — não encontrado; se integrar com OpenAI, exigiria integração com API deles ou acesso a logs.

