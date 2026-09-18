import SwiftUI
import AIQuotaCore

/// Tela de contas: o status de cada IA que o app conhece (conectada, com a conta e o plano; ou
/// não, com o motivo em português). Mesma dieta do painel — sem molduras, só espaçamento.
struct ProvidersScreenView: View {
    @ObservedObject var store: QuotaStore
    let onBack: () -> Void

    /// `store.sources` traz TODOS os provedores registrados (inclusive os sem dado nenhum) na
    /// ordem certa; `store.providerRows` traz o retrato rico (e-mail, plano, motivo) de cada um.
    /// Cruza os dois pelo id em vez de escolher um só, porque nenhum dos dois sozinho tem as
    /// duas coisas.
    private var presentationsById: [String: ProviderPresentation] {
        Dictionary(uniqueKeysWithValues: store.providerRows.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Contas")

            if store.sources.isEmpty {
                Text("Varrendo o disco…")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, Theme.Metric.padding)
                    .padding(.vertical, 10)
            } else {
                let presentations = presentationsById
                ForEach(Array(store.sources.enumerated()), id: \.element.id) { _, source in
                    accountRow(source, presentation: presentations[source.id])
                        .padding(.horizontal, Theme.Metric.padding)
                        .padding(.vertical, 9)
                }
            }

            if !store.configWarnings.isEmpty {
                warnings
            }

            actions
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.mono(Theme.Size.micro, .bold))
            .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkMuted)
            .padding(.horizontal, Theme.Metric.padding)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    // MARK: - Linha de conta

    private func accountRow(_ source: ProviderSource, presentation: ProviderPresentation?) -> some View {
        let isConnected = presentation?.maskedAccountEmail != nil
        return HStack(alignment: .top, spacing: 8) {
            ProviderLogoView(
                providerId: source.id,
                glyphColor: isConnected ? Theme.inkDim : Theme.inkFaint
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.displayName)
                        .font(Theme.mono(Theme.Size.small, .medium))
                        .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.small))
                        .textCase(.uppercase)
                        .foregroundStyle(isConnected ? Theme.ink : Theme.inkFaint)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if isConnected {
                        Text("CONECTADO")
                            .font(Theme.mono(Theme.Size.micro, .bold))
                            .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                            .foregroundStyle(Theme.calm)
                    }

                    if let letter = presentation?.planBadgeLetter, isConnected {
                        PlanBadgeSquare(letter: letter, side: 14)
                    }
                }

                Text(statusLine(source: source, presentation: presentation))
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(isConnected ? Theme.inkDim : Theme.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .help(Self.shortenHome(source.sourcePath))
    }

    /// O que mostrar embaixo do nome: o e-mail mascarado para quem está conectado, ou o motivo
    /// em português de por que não está (nunca o caminho cru — esse fica só na dica do hover).
    private func statusLine(source: ProviderSource, presentation: ProviderPresentation?) -> String {
        if let email = presentation?.maskedAccountEmail { return email }
        if !source.isInstalled { return "Não instalado neste Mac" }
        if let note = presentation?.note { return note }
        return "Instalado, sem dado de uso ainda"
    }

    /// É por aqui que o usuário descobre que errou o JSON — nunca silencioso.
    private var warnings: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(store.configWarnings, id: \.self) { warning in
                Text(warning)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 10)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            TextAction(title: "Detectar contas") { store.refreshNow() }
            ActionSeparator()
            TextAction(title: "Voltar", action: onBack)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private static func shortenHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
