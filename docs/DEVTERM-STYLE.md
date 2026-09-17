# Design System do DevTerm

Guia para recriar a identidade visual do DevTerm em SwiftUI para o app AI-Quota.

## 1. Paleta de Cores

### Cores Principais

| Variável CSS | Valor Hex | RGB | Propósito |
|---|---|---|---|
| `--color-bg` | `#000000` | 0, 0, 0 | Fundo principal (canvas) |
| `--color-bg-soft` | `#050505` | 5, 5, 5 | Fundo muito sutilmente elevado |
| `--color-surface` | `#08080a` | 8, 8, 10 | Superfícies (painéis, cards) |
| `--color-ink` | `#ffffff` | 255, 255, 255 | Texto primário |
| `--color-ink-dim` | `#9ca3af` | 156, 163, 175 | Texto secundário (labels, hints) |
| `--color-ink-muted` | `#6b7280` | 107, 114, 128 | Texto terciário (apoio) |
| `--color-ink-faint` | `#4b5563` | 75, 85, 99 | Texto muito apagado |

### Cores de Marca e Estado

| Variável CSS | Valor Hex | RGB | Propósito |
|---|---|---|---|
| `--color-primary` | `#ff3b3b` | 255, 59, 59 | Acento principal VERMELHO (marca do app) |
| `--color-primary-dim` | `#c73030` | 199, 48, 48 | Vermelho escuro (hover, inactive) |
| `--color-primary-press` | `#1a161a` | 26, 22, 26 | Fundo ao pressionar botão vermelho |
| `--color-secondary` | `#1fbcd8` | 31, 188, 216 | Acento secundário AZUL (contraste) |
| `--color-secondary-dim` | `#178ea3` | 23, 142, 163 | Azul escuro |
| `--color-success` | `#3ecf8e` | 62, 207, 142 | Verde para sucesso (saturado, vibrante) |
| `--color-tok` | `#8fd6b4` | 143, 214, 180 | Verde claro/fosco para contador de tokens (canto da tela, não compete) |
| `--color-role` | `#e0a33c` | 224, 163, 60 | Âmbar PAPEL para badges/rótulos de função (não é alerta) |
| `--color-danger` | `#ff5a5f` | 255, 90, 95 | Vermelho de erro/aviso (mais vivo que primary) |

### Cores de Borda e Linhas

| Variável CSS | Valor Hex | RGB | Propósito |
|---|---|---|---|
| `--color-hairline` | `#161618` | 22, 22, 24 | Linha fina neutra padrão (quase invisível) |
| `--color-hairline-strong` | `#242428` | 36, 36, 40 | Linha fina mais visível (hover) |
| `--color-line` | `#161618` | 22, 22, 24 | Alias para hairline (padrão) |
| `--color-line-bright` | `#242428` | 36, 36, 40 | Alias para hairline-strong |
| `--color-line-neutra` | `#161618` | 22, 22, 24 | Linha neutra explícita |
| `--color-line-neutra-forte` | `#242428` | 36, 36, 40 | Linha neutra forte |
| `--color-rain` | `#4a3a3e` | 74, 58, 62 | Cor de "chuva" (passado, histórico, cinza quente) |

### Tema

- **Modo**: Escuro único (dark only)
- **Filosofia de cores**: Preto quase liso, cinzas NEUTROS (frios) para linhas, sem glow forte. Acento é vermelho (marca), azul é secundário para contraste.
- **Paleta de fundo**: Escada mínima de profundidade (bg #000 → bg-soft #050505 → surface #08080a), quase nenhuma diferenciação visual — a tipografia e o estado (active/hover) carregam a hierarquia.

## 2. Tipografia

### Famílias

- **Monoespaçada padrão**: `"JetBrains Mono"`, fallback `ui-monospace`, `"SF Mono"`, `Menlo`, `monospace`
- **Rótulos/cabeçalhos**: Mesma monoespaçada, mas em MAIÚSCULAS com `letter-spacing` largo

### Escalas e Pesos

| Contexto | Tamanho | Peso | Letter-spacing | Text-transform | Exemplo |
|---|---|---|---|---|---|
| Rótulo de seção | 0.64rem (10px) | 700 bold | 0.22em | uppercase | "CUSTO NO BOARD" |
| Label padrão | 0.9rem (14px) | 400 normal | 0 | normal | Texto de entrada, item de menu |
| Corpo padrão | 0.9rem (14px) | 400 normal | 0 | normal | Descrição, parágrafo |
| Pequeno (hint, dim) | 0.72-0.8rem (11-13px) | 400 normal | 0 | normal | Texto dimmed, títulos secundários |
| Botão primário | variável | 400 normal | 0.08em | uppercase | "Conectar", "Salvar" |
| "Pixel" (marca) | variável | 700 bold | 0.08em | uppercase | Headers especiais, status |

### Suavização

- `-webkit-font-smoothing: antialiased` (em todo o app)

## 3. Forma e Profundidade

### Border-radius

| Nome | Valor | Uso |
|---|---|---|
| `--radius-card` | 6px | Controles, cards, campos |
| `--radius-pop` | 8px | Elementos flutuantes (popover, menu) |
| Botão arredondado | 9999px | Botão primário (pill) |
| Quadrado pequeno | 4px | Close button, select box, scrollbar thumb |

### Bordas

- **Padrão**: 1px solid com `--color-hairline` (#161618) — linha quase invisível no preto
- **Hover/Active**: 1px solid com `--color-hairline-strong` (#242428) — linha mais visível
- **Com foco primário**: 1px solid com `--color-primary` (vermelho) + box-shadow de glow
- **Pop/Menu**: 1px solid `--color-hairline-strong` + soft shadow

### Box-shadows

| Contexto | Shadow | Uso |
|---|---|---|
| Painel normal | Nenhuma | Panel base |
| Pop/Menu | `0 16px 40px -16px rgba(0, 0, 0, 0.7)` | Menu, popover |
| Glow primário | `0 0 6px color-mix(in srgb, currentColor 14%, transparent)` | Texto em destaque (glow classe) |
| Glow de foco | `0 0 12px color-mix(in srgb, var(--color-primary) 18%, transparent)` | Campo/botão em foco |
| Pane "boot" (animação) | Varia: roxo/vermelho/azul | Enquanto agente carrega (animação) |

### Filtros e Efeitos

- **Scanline CRT**: Repeating-linear-gradient quase imperceptível
  ```css
  repeating-linear-gradient(0deg, rgba(255, 255, 255, 0.012) 0px, rgba(255, 255, 255, 0.012) 1px, transparent 1px, transparent 5px)
  ```
- **Blur**: Usado em animações de entrada (blur: 2px, fade, depois remove)
- **Sem backdrop-filter** — design é plano

### Gradientes

- **Select box (wizard)**: 
  - Gradient chevron customizado (duas diagonais para criar ▼)
  - `linear-gradient(45deg, transparent 50%, #9ca3af 50%)` + `linear-gradient(135deg, #9ca3af 50%, transparent 50%)`

## 4. Movimento

### Transições

| Propriedade | Duração | Curva de Bezier |
|---|---|---|
| Cor de borda, cor, background | 180ms | `ease` |
| Borda de foco em campo | 150ms | `cubic-bezier(0.4, 0, 0.2, 1)` |
| Transform em botão | 140ms | `cubic-bezier(0.22, 1, 0.36, 1)` (elástica) |
| Botão geral (todas as props) | Mix: 180ms & 140ms | Mix: `ease` & `cubic-bezier(0.22, 1, 0.36, 1)` |
| Settings: background | Definido por `--set-ease` | `0.15s cubic-bezier(0.4, 0, 0.2, 1)` |

### Animações

| Nome | Duração | Curva | Descrição |
|---|---|---|---|
| `paneIn` | 300ms | `cubic-bezier(0.2, 0.9, 0.25, 1)` | Terminal "encaixando" (fade + scale + Y elevado depois desce) |
| `slideIn` | 300ms | `cubic-bezier(0.22, 1, 0.36, 1)` | Terminal entrando da direita (translateX) |
| `paneOpen` | 620ms | `cubic-bezier(0.16, 1, 0.3, 1)` | Pane do agente abrindo de cima (Y + scaleY + blur) |
| `paneOpenMain` | 520ms | `cubic-bezier(0.16, 1, 0.3, 1)` | Pane do Piloto abrindo da esquerda |
| `fadeUp` | 400ms | `cubic-bezier(0.22, 1, 0.36, 1)` | Fade + Y curto (troca de aba) |
| `paneBoot` | 1400ms | `ease-in-out` (infinite) | Borda piscando roxo→vermelho→azul (carregando) |
| `tokPulse` | 1100ms | `ease-in-out` (infinite) | Opacidade pulsando (contador vivo) |
| `wizPop` | 420ms | `cubic-bezier(0.22, 1, 0.36, 1)` | Card do wizard aparecendo (scale + Y) |
| `wizStepIn` | 460ms | `cubic-bezier(0.22, 1, 0.36, 1)` | Passo entrando da direita (X positivo) |
| `wizStepInBack` | 460ms | `cubic-bezier(0.22, 1, 0.36, 1)` | Passo entrando da esquerda (X negativo) |

### Respeito à Acessibilidade

- `prefers-reduced-motion: reduce` desativa TODAS as animações
- Transições geralmente não desativam, só animações

## 5. Sensação Visual

O DevTerm é **escuro, denso, monoespacçado e limpo** — uma ferramenta séria de produção, não um brinquedo.

- **Preto e cinza frio**: Canvas #000 com cinzas neutros (não quentes). Sem cor nem brilho desnecessário.
- **Linhas finas e quase invisíveis**: Hairlines #161618 sugerem divisão sem desenhar moldura. Apenas o estado (active/hover) colore de vermelho.
- **Monoespaçada em tudo**: Nada de serif, nada de sans-serif soft — é código, é terminal, é monospace. Rótulos em CAPS com tracking para formality.
- **Vermelho como marca, não como alerta**: O vermelho #ff3b3b (marca) aparece em botões, foco, estado ativo. Erro usa #ff5a5f (mais vivo). Sem alarme visual constante.
- **Movimento discreto e preciso**: Animações usam curvas elásticas (cubic-bezier(0.22, 1, 0.36, 1)) pra dar bounce suave, mas breve. Não é arcade, é profissional.
- **Sem sombra pesada, sem blur**: Drop shadow mínimo (#000 com 0.7 alpha). Blur só em entrada/saída, depois some. Nenhum frosted glass.
- **Respira via espaçamento**: A profundidade vem do layout (margem, gap), não da cor. Muita coisa é display: none em repouso e aparece só em hover/active.

## 6. Mapeamento CSS ↔ SwiftUI

Para recriar em SwiftUI, use os valores de 0-1 que SwiftUI espera (divida 255 por cada canal RGB).

| Conceito CSS | Valor CSS | SwiftUI Color | Observações |
|---|---|---|---|
| Fundo principal | #000000 | `Color(red: 0, green: 0, blue: 0)` | Puro preto |
| Fundo soft | #050505 | `Color(red: 0.02, green: 0.02, blue: 0.02)` | Quase imperceptível, levemente elevado |
| Superfície/Card | #08080a | `Color(red: 0.031, green: 0.031, blue: 0.039)` | Levemente mais clara que soft |
| Texto primário | #ffffff | `Color(red: 1, green: 1, blue: 1)` | Branco puro |
| Texto dimmed | #9ca3af | `Color(red: 0.612, green: 0.639, blue: 0.686)` | Cinza neutro médio |
| Texto muted | #6b7280 | `Color(red: 0.420, green: 0.447, blue: 0.502)` | Cinza neutro claro |
| Texto faint | #4b5563 | `Color(red: 0.294, green: 0.333, blue: 0.388)` | Cinza neutro muito claro |
| Accent primário (vermelho) | #ff3b3b | `Color(red: 1, green: 0.231, blue: 0.231)` | Marca do app |
| Accent primário dim | #c73030 | `Color(red: 0.780, green: 0.188, blue: 0.188)` | Hover/inactive |
| Accent secundário (azul) | #1fbcd8 | `Color(red: 0.122, green: 0.737, blue: 0.847)` | Contraste |
| Sucesso (verde saturado) | #3ecf8e | `Color(red: 0.245, green: 0.812, blue: 0.557)` | Conclusão |
| Tokens (verde claro) | #8fd6b4 | `Color(red: 0.561, green: 0.839, blue: 0.706)` | Telemetria, não compete |
| Rótulo/âmbar | #e0a33c | `Color(red: 0.878, green: 0.639, blue: 0.235)` | Badges, papel |
| Linha (hairline) | #161618 | `Color(red: 0.086, green: 0.086, blue: 0.094)` | Borda fina invisível |
| Linha bright | #242428 | `Color(red: 0.141, green: 0.141, blue: 0.157)` | Borda mais visível (hover) |

### Transições em SwiftUI

```swift
.animation(.easeInOut(duration: 0.18), value: someValue)  // 180ms ease
.animation(.easeOut(duration: 0.14), value: someValue)    // 140ms cubic-bezier aprox.
```

Ou use `withAnimation` com `.easeInOut(duration:)`.

### Animações (CABasicAnimation/SwiftUI)

Para animações infinitas (pulse, boot), use `animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true))`.

---

**Filosofia**: Minimalista, funcional, monoespacçado. A marca (vermelho) aparece sem gritar. O design desaparece pra deixar o conteúdo falar. Cada pixel serve a um propósito.
