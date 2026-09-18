import AppKit
import Foundation
import AIQuotaCore

/// Gera um relatório HTML estático a partir dos eventos locais do Claude Code, dia a dia, e abre
/// no navegador padrão — sem servidor, sem conta, sem nada saindo desta máquina.
///
/// Hoje só cobre Claude Code: é o único provedor cujo leitor de eventos brutos
/// (`ClaudeCodeLogReader`) é público no `AIQuotaCore` — o parser de sessão do Codex é interno ao
/// módulo. Cobrir o Codex aqui também é um passo natural depois, expondo um wrapper público
/// equivalente em `CodexProvider`.
enum Retrospecto {
    /// A leitura ao vivo (`ClaudeCodeProvider`, a cada 30s) filtra por `recentWindow` de 24h de
    /// propósito, pra não reler o histórico inteiro sem necessidade (ver `ClaudeCodeLogReader`).
    /// Aqui é o oposto: uma ação explícita e rara do usuário, então vale abrir mão da otimização
    /// e olhar tudo.
    private static let fullHistoryWindow: TimeInterval = 10 * 365 * 24 * 3600

    static func open() {
        let reader = ClaudeCodeLogReader(recentWindow: fullHistoryWindow)
        let events = reader.readAllEvents()
        guard !events.isEmpty else {
            NSSound.beep()
            return
        }

        guard let url = write(html: renderHTML(for: events)) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func renderHTML(for events: [UsageEvent]) -> String {
        let byDay = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.timestamp) }
        let days = byDay.keys.sorted(by: >)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd/MM/yyyy"

        var totalTokens = 0
        var totalCost = 0.0
        let rows = days.map { day -> String in
            let dayEvents = byDay[day] ?? []
            let tokens = dayEvents.reduce(0) { $0 + $1.totalTokens }
            let cost = CostCalculator.totalCost(for: dayEvents)
            totalTokens += tokens
            totalCost += cost
            return """
            <tr><td>\(dayFormatter.string(from: day))</td><td class="num">\(QuotaFormatting.compactTokens(tokens))</td><td class="num">\(QuotaFormatting.cost(cost))</td></tr>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
        <meta charset="utf-8">
        <title>Retrospecto — AI Quota</title>
        <style>
          body { background:#0D1117; color:#D6D6D6; font-family: "JetBrains Mono", "SF Mono", ui-monospace, monospace; padding: 32px; }
          h1 { font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; color:#D7DBDF; margin: 0 0 6px; }
          .muted { color:#858585; font-size: 12px; margin: 0 0 24px; }
          table { border-collapse: collapse; width: 100%; max-width: 480px; }
          th, td { text-align: left; padding: 6px 12px; border-bottom: 1px solid #28303A; font-size: 12px; }
          th { color:#6E747D; text-transform: uppercase; letter-spacing: 0.08em; font-size: 10px; font-weight: normal; }
          td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
          tfoot td { color:#D6D6D6; font-weight: bold; border-top: 1px solid #323C48; border-bottom: none; }
        </style>
        </head>
        <body>
          <h1>Retrospecto — Claude Code</h1>
          <p class="muted">Gerado localmente a partir de ~/.claude/projects, dia a dia — nada sai desta máquina.</p>
          <table>
            <thead><tr><th>Dia</th><th class="num">Tokens</th><th class="num">Custo estimado</th></tr></thead>
            <tbody>
            \(rows)
            </tbody>
            <tfoot><tr><td>Total (\(days.count) dia\(days.count == 1 ? "" : "s"))</td><td class="num">\(QuotaFormatting.compactTokens(totalTokens))</td><td class="num">\(QuotaFormatting.cost(totalCost))</td></tr></tfoot>
          </table>
        </body>
        </html>
        """
    }

    private static func write(html: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ai-quota-retrospecto.html")
        return (try? html.write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
    }
}
