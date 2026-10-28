import BlockportCore
import SwiftUI

struct InstallingView: View {
    let current: Installer.Step

    private var total: Int { Installer.Step.allCases.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Installing Minecraft").font(.largeTitle.bold())
                Text("Step \(current.rawValue + 1) of \(total): \(current.title)")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(current.rawValue), total: Double(total))
                .tint(Theme.accent)
                .accessibilityLabel("Installation progress")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Installer.Step.allCases, id: \.self) { step in
                    HStack(spacing: 10) {
                        icon(for: step).frame(width: 18)
                        Text(step.title)
                            .fontWeight(step == current ? .semibold : .regular)
                            .foregroundStyle(step.rawValue > current.rawValue ? .secondary : .primary)
                    }
                }
            }
            Spacer()
            Text("Keep Blockport open during installation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func icon(for step: Installer.Step) -> some View {
        if step.rawValue < current.rawValue {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentBright)
        } else if step == current {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }
}
