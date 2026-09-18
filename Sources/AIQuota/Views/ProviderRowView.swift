import SwiftUI
import AIQuotaCore

/// Um provedor no painel, e o painel é só uma pilha deles:
///
///     [logo]  NOME-DA-IA                                  PLUS
///             5H      [barrinha]  27%              em 3h17m
///             SEMANA  [barrinha]  46%              em 4d10h
///
/// Provedor sem nenhuma janela de cota troca as linhas pelo dado que existir em texto apagado
/// (tokens somados, contagem de usos) ou por um traço, quando não há nenhum dado.
struct ProviderRowView: View {
    let presentation: ProviderPresentation
    /// `false` quando um `ProviderGroupHeaderView` já desenhou a logo + o nome acima — o caso de
    /// uma segunda (terceira...) conta do mesmo provedor, que não repete cabeçalho.
    var showHeader: Bool = true

    private var windows: [QuotaWindowPresentation] { presentation.windows }
    private var isDim: Bool { windows.isEmpty && presentation.fallbackValue == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if showHeader { header }
            if let email = presentation.maskedAccountEmail {
                accountRow(email: email)
            }
            if windows.isEmpty {
                fallbackRow
            } else {
                ForEach(windows) { window in
                    windowRow(window)
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 8) {
            ProviderLogoView(
                providerId: presentation.id,
                glyphColor: isDim ? Theme.inkFaint : Theme.inkDim
            )

            Text(presentation.displayName)
                .font(Theme.mono(Theme.Size.small, .medium))
                .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.small))
                .textCase(.uppercase)
                .foregroundStyle(isDim ? Theme.inkFaint : Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)
        }
    }

    // MARK: - Conta

    /// "r•••@g•••.com                                      [P]" — o e-mail mascarado da conta
    /// logada, com o selo quadrado do plano à direita.
    private func accountRow(email: String) -> some View {
        HStack(spacing: 6) {
            Text(email)
                .font(Theme.mono(Theme.Size.small, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if let letter = presentation.planBadgeLetter {
                PlanBadgeSquare(letter: letter)
            }
        }
        .padding(.leading, Theme.Metric.windowIndent)
    }

    // MARK: - Linha de janela

    private func windowRow(_ window: QuotaWindowPresentation) -> some View {
        HStack(spacing: 6) {
            Text(window.label.uppercased())
                .font(Theme.mono(Theme.Size.small, .medium))
                .foregroundStyle(Theme.inkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Theme.Metric.windowLabelWidth, alignment: .leading)

            UsageBar(fraction: window.percent / 100, color: window.color)
                .animation(Theme.Motion.bar, value: window.percent)

            Text(QuotaFormatting.percent(window.percent))
                .font(Theme.mono(Theme.Size.body, .medium))
                .foregroundStyle(window.color)
                .frame(width: Theme.Metric.percentColumnWidth, alignment: .trailing)

            Spacer(minLength: 4)

            if let resetsAt = window.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(QuotaFormatting.resetIn(until: resetsAt, now: context.date))
                        .font(Theme.mono(Theme.Size.small))
                        // Crítico ganha o mesmo tom vermelho do percentual — "em 60d" com a
                        // barra estourada não devia parecer um tempo qualquer, neutro.
                        .foregroundStyle(window.level == .critical ? window.color : Theme.inkFaint)
                        .lineLimit(1)
                        .frame(width: Theme.Metric.resetColumnWidth, alignment: .trailing)
                }
            } else {
                Text(window.isOfficial ? "" : "estim.")
                    .font(Theme.mono(Theme.Size.small))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .frame(width: Theme.Metric.resetColumnWidth, alignment: .trailing)
            }
        }
        .frame(height: Theme.Metric.windowRowHeight)
        .padding(.leading, Theme.Metric.windowIndent)
        .help(tooltip(for: window))
    }

    // MARK: - Sem nenhuma janela

    private var fallbackRow: some View {
        HStack(spacing: 8) {
            Text(presentation.fallbackValue ?? presentation.note ?? "sem dado")
                .font(Theme.mono(Theme.Size.micro))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .frame(height: Theme.Metric.windowRowHeight)
        .padding(.leading, Theme.Metric.windowIndent)
    }

    /// Quem quiser saber o que a linha esconde passa o mouse — é o único lugar onde a explicação
    /// aparece, para o painel não virar texto.
    private func tooltip(for window: QuotaWindowPresentation) -> String {
        if window.isOfficial {
            var text = "Limite oficial do provedor — janela \"\(window.label)\""
            if let resetsAt = window.resetsAt {
                text += " — reseta às \(QuotaFormatting.time(resetsAt))"
            }
            return text
        }
        if let note = presentation.note { return note }
        if let resetsAt = window.resetsAt {
            return "Uso estimado — reseta às \(QuotaFormatting.time(resetsAt))"
        }
        return presentation.displayName
    }
}

/// Cabeçalho de um `ProviderGroup`: a logo e o nome aparecem UMA vez por provedor, mesmo quando
/// ele tem mais de uma conta (`MultiAccountDiscovery`) — cada conta desenha só o bloco de
/// e-mail + janelas, via `ProviderRowView(showHeader: false)`, empilhado logo abaixo.
///
///     ● [logo]  NOME-DA-IA
///       g•••@l•••.com.br                                    [M]
///       Semana  [barrinha]  46%                        em 4d10h
///       5h      [barrinha]  27%                        em 3h17m
struct ProviderGroupHeaderView: View {
    let group: ProviderGroup

    private var isDim: Bool {
        group.accounts.allSatisfy { $0.windows.isEmpty && $0.fallbackValue == nil }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isDim ? Theme.inkFaint : Theme.groupDot)
                .frame(width: 5, height: 5)

            ProviderLogoView(
                providerId: group.id,
                glyphColor: isDim ? Theme.inkFaint : Theme.inkDim
            )

            Text(group.displayName)
                .font(Theme.mono(Theme.Size.micro, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                .textCase(.uppercase)
                .foregroundStyle(isDim ? Theme.inkFaint : Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)
        }
        .padding(.top, 10)
    }
}
