import SwiftUI
import AppKit
import AIQuotaCore

/// Tela de provedores: onde cada IA é lida em disco, os erros do `providers.json` quando houver,
/// e como adicionar outras IAs. Mesma dieta do painel — sem molduras, só hairlines.
struct ProvidersScreenView: View {
    @ObservedObject var store: QuotaStore
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.sources.isEmpty {
                Text("Varrendo o disco…")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, Theme.Metric.padding)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(store.sources.enumerated()), id: \.element.id) { index, source in
                    if index > 0 {
                        Hairline()
                    }
                    sourceRow(source)
                        .padding(.horizontal, Theme.Metric.padding)
                        .padding(.vertical, 6)
                }
            }

            if !store.configWarnings.isEmpty {
                Hairline()
                warnings
            }

            Hairline()
            actions
        }
    }

    private func sourceRow(_ source: ProviderSource) -> some View {
        HStack(spacing: 8) {
            ProviderGlyphView(
                glyph: ProviderGlyph.forProvider(id: source.id),
                color: source.isInstalled ? Theme.inkDim : Theme.inkFaint,
                side: Theme.Metric.glyphSide
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(source.displayName)
                    .font(Theme.mono(Theme.Size.small, .medium))
                    .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.small))
                    .textCase(.uppercase)
                    .foregroundStyle(source.isInstalled ? Theme.ink : Theme.inkFaint)
                    .lineLimit(1)

                Text(Self.shortenHome(source.sourcePath))
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 0)
        }
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
        .padding(.vertical, 7)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Outras IAs entram editando providers.json.")
                .font(Theme.mono(Theme.Size.micro))
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                TextAction(title: "Abrir configuração") { openConfigFile() }
                ActionSeparator()
                TextAction(title: "Voltar", action: onBack)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 7)
    }

    /// Cria o arquivo com os padrões comentados se ainda não existir, e só então abre — para o
    /// botão nunca levar a um "arquivo não encontrado".
    private func openConfigFile() {
        ProvidersConfigStore.ensureDefaultFileExists()
        NSWorkspace.shared.open(ProvidersConfigStore.defaultFile)
    }

    private static func shortenHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
