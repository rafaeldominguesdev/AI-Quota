import SwiftUI
import AppKit
import AIQuotaCore

struct PopoverContentView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let snapshot = store.snapshot {
                usageSection(snapshot)
                Divider()
                modelSection(snapshot)

                if !store.cursorUsageByModel.isEmpty {
                    Divider()
                    cursorSection
                }
            } else {
                emptyState
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear { store.refreshNow() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AI Quota")
                .font(.headline)
            Text("Claude Code · janela de 5 horas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func usageSection(_ snapshot: QuotaSnapshot) -> some View {
        let color = snapshot.isActive ? StatusColor.color(for: snapshot.state) : StatusColor.neutralColor

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProgressBarView(percent: snapshot.usagePercent, color: color)
                Text("\(Int(snapshot.usagePercent.rounded()))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .frame(minWidth: 52, alignment: .trailing)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "Tokens usados", value: QuotaFormatting.tokens(snapshot.totalTokens))
                infoRow(label: "Custo estimado", value: QuotaFormatting.cost(snapshot.totalCost))
                infoRow(label: "Início da janela", value: QuotaFormatting.time(snapshot.windowStart))

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    infoRow(
                        label: "Reinicia em",
                        value: "\(QuotaFormatting.remaining(until: snapshot.resetAt, now: context.date)) · \(QuotaFormatting.time(snapshot.resetAt))"
                    )
                }
            }

            if !snapshot.isActive {
                Text("Sem atividade recente — este é o último bloco registrado.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }

    private func modelSection(_ snapshot: QuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Por modelo")
                .font(.subheadline.bold())

            ForEach(snapshot.byModel, id: \.model) { entry in
                HStack {
                    Text(entry.model)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(QuotaFormatting.tokens(entry.totalTokens))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(QuotaFormatting.cost(entry.cost))
                        .font(.caption.monospacedDigit())
                        .frame(width: 68, alignment: .trailing)
                }
            }
        }
    }

    private var cursorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cursor")
                .font(.subheadline.bold())

            ForEach(store.cursorUsageByModel.sorted(by: { $0.key < $1.key }), id: \.key) { model, count in
                HStack {
                    Text(model)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("\(count) uso\(count == 1 ? "" : "s")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        Text("Nenhum uso do Claude Code encontrado em ~/.claude/projects.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var footer: some View {
        HStack {
            if let lastUpdated = store.lastUpdated {
                Text("Atualizado às \(QuotaFormatting.time(lastUpdated))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Carregando…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Atualizar agora") {
                store.refreshNow()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            Button("Sair") {
                NSApp.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}
