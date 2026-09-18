# Design System do PilotDeck

Guia da identidade visual adotada pelo AI Quota, extraída de
`~/pilotdeck/apps/web/src/app/globals.css`.

Substitui o `docs/DEVTERM-STYLE.md` como referência ativa da UI. O doc do DevTerm continua no
repositório por ser a origem da ESTRUTURA (mono, rótulos em caixa alta, densidade) — o que mudou
aqui é a PELE: de preto absoluto com acento vermelho para cinza-azulado com acento neutro.

## 1. Paleta

| Variável CSS | Valor Hex | Propósito |
|---|---|---|
| `--bg` | `#0b0d10` | Fundo (canvas) — cinza-azulado bem escuro, **não** preto |
| `--card` | `#12161b` | Superfície de card, um degrau acima do fundo |
| `--line` | `#242a32` | Linha/borda — presente, não sugerida |
| `--fg` | `#e8eaed` | Texto primário (branco levemente frio) |
| `--muted` | `#8b919a` | Texto secundário |
| `--accent` | `#d7dbdf` | Acento: cinza muito claro, quase branco — **neutro**, não colorido |
| `--danger` | `#e07070` | Vermelho suave, dessaturado — só estado de perigo |
| `--focus` | `#9aa3ad` | Cinza médio de foco |

Não existe verde nem âmbar na paleta. Nenhuma cor vibrante em nenhum estado.

## 2. O que caracteriza (e diferencia do DevTerm)

1. **Fundo cinza, com degrau de superfície real.** `#0b0d10 → #12161b` é uma diferença que se vê,
   ao contrário da escada quase imperceptível do DevTerm (`#000 → #050505 → #08080a`).
2. **A borda é um elemento presente.** `1px solid var(--line)` em todo painel, campo e botão
   ghost. `#242a32` contra `#0b0d10` é bem mais visível que a hairline `#161618` contra `#000`.
   No DevTerm a linha sugere divisão; aqui ela desenha a caixa.
3. **Acento neutro.** O botão primário é `background: var(--accent)` com texto `#111` e
   `font-weight: 560` — cinza claro tratado como cor de marca. Nada de vermelho de marca.
4. **Vermelho só como erro, e dessaturado.** `--danger` aparece exclusivamente em `.error`.
5. **Foco é anel externo, não borda que muda.** `outline: 2px solid var(--focus)` com
   `outline-offset: 1px`, o que não redimensiona o controle.
6. **Plano.** Nenhuma `box-shadow` no arquivo inteiro.

## 3. Forma

| Nome | Valor | Uso |
|---|---|---|
| Raio de painel | 12px | `.panel`, `form` |
| Raio de controle | 8px | `input`, `button` |
| Borda | 1px solid `--line` | tudo que é caixa |
| Sombra | nenhuma | — |
| Gap interno de painel | 14px | `.panel { gap: 14px }` |
| Padding de painel | 24px | `.panel` |

## 4. Tipografia

- **Corpo**: sans do sistema (`ui-sans-serif, system-ui, -apple-system`).
- **Mono** (`ui-monospace, SFMono-Regular, Menlo`): reservada à marca (`.brand`) e ao rodapé
  (`.foot`) — 11px, `letter-spacing: 0.12em`, `text-transform: uppercase`, cor `--muted`.
- **Título**: 28px, weight 500, `letter-spacing: -0.03em`.
- `button:disabled { opacity: 0.4 }`.

### Desvio deliberado no AI Quota

O AI Quota mantém a monoespaçada em **toda** a interface, e não só na marca e no rodapé. Dois
motivos: a estrutura em colunas do painel (nome · barra · percentual) depende de largura de
caractere fixa para os números não dançarem entre uma linha e outra; e é a leitura que o usuário
já aprovou. O que foi adotado do PilotDeck é o **tracking de 0.12em** dos rótulos em caixa alta,
no lugar dos 0.22em largos do DevTerm.

## 5. Cores de estado da barra de uso

O PilotDeck não tem semáforo — mas a partir da referência de painel de cotas estilo Telegram que
o usuário trouxe (2026-09), o AI Quota passou a ter um de propósito: cada janela de cota é um
limite real que estoura, e a cor precisa carregar essa informação à distância, sem exigir leitura
do número. É um desvio deliberado do §5 original, documentado aqui em vez de escondido:

| Nível | Cor | Leitura |
|---|---|---|
| Tranquilo (< 50%) | `Theme.calm` `#6fbf83` (verde) | folga |
| Atenção (50–80%) | `Theme.warn` `#e0a83d` (âmbar) | acompanhar |
| Crítico (≥ 80%) | `Theme.danger` `#e07070` (vermelho) | a única cor herdada do PilotDeck original |

O resto do painel (fundo, borda, tipografia, o botão-texto sem caixa) continua fiel ao PilotDeck —
o semáforo é a exceção pontual, não uma virada de identidade visual.

## 6. Mapeamento CSS ↔ SwiftUI

Todos os valores vivem em `Sources/AIQuota/Support/Theme.swift`, que é o único arquivo do app com
literal hexadecimal. As views só referenciam constantes nomeadas de lá.

| Conceito | CSS | `Theme` |
|---|---|---|
| Fundo | `--bg` | `Theme.bg` |
| Card | `--card` | `Theme.surface` |
| Linha | `--line` | `Theme.line` |
| Texto primário | `--fg` | `Theme.ink` |
| Texto secundário | `--muted` | `Theme.inkDim` |
| Acento neutro | `--accent` | `Theme.accent` |
| Perigo | `--danger` | `Theme.danger` |
| Foco | `--focus` | `Theme.focus` |

---

**Filosofia**: cinza sobre cinza, com a borda fazendo o trabalho que a cor faria em outro app. O
acento é um tom de claro, não um tom de vermelho. Quando algo finalmente aparece colorido, é
porque é problema.
