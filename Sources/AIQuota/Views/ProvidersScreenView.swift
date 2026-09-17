import SwiftUI
import AppKit
import AIQuotaCore

/// Tela de PROVEDORES: onde cada provedor é lido em disco e como adicionar outras IAs (GLM,
/// Qwen, DeepSeek) sem recompilar o app — só editando `~/.config/ai-quota/providers.json`.
struct ProvidersScreenView: View {
    @ObservedObject var store: QuotaStore
    let onBack: () -> Void

    private var configPath: String {
        Self.shortenHome(ProvidersConfigStore.defaultFile.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            detectedSection

            if !store.configWarnings.isEmpty {
                warningsSection
            }

            configSection
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 12)
    }

    // MARK: - Detectados

    private var detectedSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(
                text: "Provedores detectados",
                trailing: store.sources.isEmpty ? nil : "\(store.sources.count)"
            )

            if store.sources.isEmpty {
                Text("Ainda varrendo o disco…")
                    .font(Theme.mono(Theme.Size.small))
                    .foregroundStyle(Theme.inkFaint)
            } else {
                ForEach(Array(store.sources.enumerated()), id: \.element.id) { index, source in
                    sourceRow(source)
                        .staggeredAppear(index: index)
                }
            }
        }
    }

    private func sourceRow(_ source: ProviderSource) -> some View {
        let isPrimary = source.id == store.overview?.primaryProviderId
        let accent: Color = {
            if !source.isInstalled { return Theme.inkFaint }
            return source.kind == .unavailable ? Theme.inkMuted : Theme.success
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                StatusSquare(color: accent)

                Text(source.displayName)
                    .font(Theme.mono(Theme.Size.body, isPrimary ? .bold : .regular))
                    .foregroundStyle(source.isInstalled ? Theme.inkDim : Theme.inkFaint)
                    .lineLimit(1)

                if isPrimary {
                    Badge(text: "Principal", color: Theme.primary, emphasized: true)
                }

                Spacer(minLength: 6)

                Badge(
                    text: source.isInstalled ? "Instalado" : "Ausente",
                    color: source.isInstalled ? Theme.inkMuted : Theme.inkFaint
                )
            }

            HStack(spacing: 6) {
                Text(source.id)
                    .font(Theme.mono(Theme.Size.micro, .medium))
                    .foregroundStyle(Theme.role)

                Text(Self.shortenHome(source.sourcePath))
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.bgSoft))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.hairline, lineWidth: Theme.Metric.hairline)
        )
    }

    // MARK: - Avisos

    /// É por aqui que o usuário descobre que errou o JSON — em vermelho, nunca silencioso.
    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: "Erros em providers.json", color: Theme.danger)

            ForEach(store.configWarnings, id: \.self) { warning in
                Text("· " + warning)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.danger.opacity(0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.danger.opacity(0.35), lineWidth: Theme.Metric.hairline)
        )
    }

    // MARK: - Configuração

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Adicionar outras IAs")

            Text("Qualquer CLI que grave logs em JSONL pode entrar aqui — GLM, Qwen, DeepSeek, o que for. Copie o bloco de exemplo em \"custom\", aponte os caminhos do JSON para o formato do log e mude \"enabled\" para true. Não precisa recompilar: o app relê o arquivo na próxima atualização.")
                .font(Theme.mono(Theme.Size.small))
                .foregroundStyle(Theme.inkMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(configPath)
                .font(Theme.mono(Theme.Size.micro, .medium))
                .foregroundStyle(Theme.secondary)
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .strokeBorder(Theme.hairlineStrong, lineWidth: Theme.Metric.hairline)
                )

            HStack(spacing: 8) {
                TerminalButton(title: "Abrir configuração", color: Theme.secondary) {
                    openConfigFile()
                }
                TerminalButton(title: "Voltar", color: Theme.primary, action: onBack)
                Spacer(minLength: 0)
            }
        }
    }

    /// Cria o arquivo com os padrões comentados se ele ainda não existir, e só então abre — para
    /// o botão nunca levar o usuário a um "arquivo não encontrado".
    private func openConfigFile() {
        ProvidersConfigStore.ensureDefaultFileExists()
        NSWorkspace.shared.open(ProvidersConfigStore.defaultFile)
    }

    private static func shortenHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
