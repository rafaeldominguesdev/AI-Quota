import SwiftUI
import AppKit
import AIQuotaCore

// MARK: - Aba

/// Aba do topo: fundo levemente avermelhado e sublinhado de 2px no acento quando ativa — as duas
/// coisas medidas do print (`#0E0404` de fundo, `#EF4444` de sublinhado).
struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: action) {
            // O sublinhado vai como OVERLAY, não como irmão num VStack: um `Rectangle` é
            // infinitamente flexível em largura, então empilhado ele esticava a aba inteira e as
            // três abas acabavam dividindo a largura da janela em partes iguais. Em overlay ele
            // herda a largura do texto já com o padding.
            Text(title)
                .font(Theme.mono(Theme.Size.label, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.label))
                .foregroundStyle(isActive ? Theme.ink : (isHovering ? Theme.inkDim : Theme.inkMuted))
                .padding(.horizontal, 16)
                .padding(.top, 9)
                .padding(.bottom, 9)
                .background(isActive ? Theme.accentWash : Color.clear)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isActive ? Theme.accent : Color.clear)
                        .frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Botões

/// Botão fantasma: só borda e texto, sem preenchimento. É o "Atualizar" do print.
struct GhostButton: View {
    let title: String
    let action: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(Theme.Size.micro, .medium))
                .foregroundStyle(isHovering ? Theme.ink : Theme.inkDim)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(isHovering ? Theme.inkFaint : Theme.lineStrong, lineWidth: Theme.Metric.border)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Botão primário: preenchido no vermelho REDLINE, texto preto. Só existe um por tela.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(Theme.Size.small, .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.accent.opacity(isHovering ? 0.88 : 1))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Estrutura

/// O rótulo de seção com o pontinho vermelho na frente — "• CONTAS MONITORADAS" do print.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 4, height: 4)

            Text(title)
                .font(Theme.mono(Theme.Size.micro, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkDim)

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.bottom, 12)
    }
}

/// A caixa do print: fundo um degrau acima do preto, hairline desenhando a borda, raio 8.
/// `borderColor` sobe para o verde quando a conta está conectada — o "outline verde" pedido —
/// e a borda engrossa um tiquinho para o realce não depender só da cor.
struct SettingsCard<Content: View>: View {
    var borderColor: Color = Theme.line
    var borderWidth: CGFloat = Theme.Metric.border
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Theme.Metric.Settings.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
    }
}

struct EmptyLine: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.mono(Theme.Size.micro))
            .foregroundStyle(Theme.inkFaint)
            .padding(.vertical, 8)
    }
}

// MARK: - Card de conta

/// Um card por conta: e-mail à esquerda, família da IA à direita, e uma linha por janela de cota.
struct AccountCard: View {
    let presentation: ProviderPresentation
    let family: String

    /// Conectado = tem conta logada legível. É o que acende o outline verde e a logo colorida.
    private var isConnected: Bool { presentation.maskedAccountEmail != nil }

    var body: some View {
        SettingsCard(
            borderColor: isConnected ? Theme.calm : Theme.line,
            borderWidth: isConnected ? 1.5 : Theme.Metric.border
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    ProviderLogoView(
                        providerId: presentation.id,
                        glyphColor: isConnected ? Theme.inkDim : Theme.inkFaint,
                        side: 20
                    )

                    Text(presentation.maskedAccountEmail ?? presentation.displayName)
                        .font(Theme.mono(Theme.Size.small, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    if isConnected {
                        Text("CONECTADO")
                            .font(Theme.mono(Theme.Size.micro, .bold))
                            .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                            .foregroundStyle(Theme.calm)
                    }

                    Text(family)
                        .font(Theme.mono(Theme.Size.micro, .medium))
                        .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.inkMuted)
                }

                if presentation.windows.isEmpty {
                    Text(presentation.note ?? "Sem janela de cota reportada")
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)
                } else {
                    VStack(spacing: Theme.Metric.Settings.barRowGap) {
                        ForEach(presentation.windows) { window in
                            QuotaBarRow(window: window)
                        }
                    }
                }

                if let value = presentation.fallbackValue {
                    Text(value + " nesta janela")
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
    }
}

/// A linha de uma janela de cota: rótulo · barra · percentual · quando reseta.
/// As larguras vêm medidas do print — rótulo 81, percentual 54, reset 84.
struct QuotaBarRow: View {
    let window: QuotaWindowPresentation

    var body: some View {
        HStack(spacing: 0) {
            Text(window.label)
                .font(Theme.mono(Theme.Size.micro))
                .foregroundStyle(Theme.inkDim)
                .lineLimit(1)
                .frame(width: Theme.Metric.Settings.barLabelWidth, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(window.color)
                        .frame(width: max(0, geometry.size.width * CGFloat(min(window.percent / 100, 1))))
                }
                .frame(height: Theme.Metric.Settings.barHeight)
                .frame(maxHeight: .infinity)
            }

            Text("\(Int(window.percent.rounded()))%")
                .font(Theme.mono(Theme.Size.micro, .medium))
                .foregroundStyle(window.color)
                .frame(width: Theme.Metric.Settings.barPercentWidth, alignment: .trailing)
                .padding(.leading, 24)

            Group {
                if let resetsAt = window.resetsAt {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(resetLabel(resetsAt, now: context.date))
                            .font(Theme.mono(Theme.Size.micro))
                            .foregroundStyle(resetsAt <= context.date ? Theme.calm : Theme.inkMuted)
                    }
                } else {
                    Text("—").font(Theme.mono(Theme.Size.micro)).foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(width: Theme.Metric.Settings.barResetWidth, alignment: .trailing)
            .padding(.leading, 7)
        }
        .frame(height: 13)
    }

    /// "✓ resetou" quando a janela já virou — o print trata isso como bom, não como ausência.
    private func resetLabel(_ resetsAt: Date, now: Date) -> String {
        resetsAt <= now ? "✓ resetou" : QuotaFormatting.resetIn(until: resetsAt, now: now)
    }
}

// MARK: - Card de provedor

struct ProviderCard: View {
    let source: ProviderSource
    let presentation: ProviderPresentation?

    private var isConnected: Bool { presentation?.maskedAccountEmail != nil }

    var body: some View {
        SettingsCard {
            HStack(alignment: .top, spacing: 10) {
                ProviderLogoView(
                    providerId: source.id,
                    glyphColor: isConnected ? Theme.inkDim : Theme.inkFaint,
                    side: 20
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(source.displayName)
                            .font(Theme.mono(Theme.Size.small, .medium))
                            .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.small))
                            .textCase(.uppercase)
                            .foregroundStyle(isConnected ? Theme.ink : Theme.inkFaint)

                        Spacer(minLength: 8)

                        Text(isConnected ? "CONECTADO" : (source.isInstalled ? "SEM DADO" : "AUSENTE"))
                            .font(Theme.mono(Theme.Size.micro, .bold))
                            .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                            .foregroundStyle(isConnected ? Theme.calm : Theme.inkFaint)
                    }

                    Text(statusLine)
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(isConnected ? Theme.inkDim : Theme.inkFaint)
                        .lineLimit(1)

                    Text(Self.shortenHome(source.sourcePath))
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                // A CLI faz login sozinha (OAuth próprio) — o app não tem chave pra pedir.
                // O botão só leva até a página de conta; depois de logar na CLI, a próxima
                // leitura já detecta sozinha. Exceção: o Grok CLI não grava uso local (ver
                // GrokProvider) — "Conectar" prometeria uma barra que nunca vai aparecer, então
                // o rótulo aqui só oferece abrir o site, sem sugerir que algo vai mudar no app.
                if ProviderWebConsole.entry(forProviderId: source.id) != nil {
                    GhostButton(title: source.id == "grok" ? "Abrir site" : "Conectar") {
                        ProviderWebConsole.open(providerId: source.id)
                    }
                }
            }
        }
    }

    private var statusLine: String {
        if let email = presentation?.maskedAccountEmail { return email }
        if !source.isInstalled { return "Não instalado neste Mac" }
        if let note = presentation?.note { return note }
        return "Instalado, sem dado de uso ainda"
    }

    private static func shortenHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

// MARK: - Linhas da aba AJUSTES

struct CheckRow: View {
    let title: String
    let detail: String
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 10) {
                Text(isOn ? "✓" : "·")
                    .font(Theme.mono(Theme.Size.small, .bold))
                    .foregroundStyle(isOn ? Theme.accent : Theme.inkFaint)
                    .frame(width: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.mono(Theme.Size.small, .medium))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Caminho de arquivo com ação de revelar no Finder — e um aviso honesto quando ele ainda não
/// existe, em vez de abrir o Finder em nada.
struct PathRow: View {
    let title: String
    let path: URL
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.mono(Theme.Size.small, .medium))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkMuted)
                Text(shortened + (exists ? "" : "  (ainda não criado)"))
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if exists {
                GhostButton(title: "Revelar") {
                    NSWorkspace.shared.activateFileViewerSelecting([path])
                }
            }
        }
    }

    private var exists: Bool { FileManager.default.fileExists(atPath: path.path) }

    private var shortened: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.path.hasPrefix(home) ? "~" + path.path.dropFirst(home.count) : path.path
    }
}
