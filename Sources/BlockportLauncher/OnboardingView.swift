import SwiftUI

struct OnboardingView: View {
    let dropTargeted: Bool
    let chooseIPA: () -> Void

    private let steps: [(title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("Download the Minecraft IPA", "With ipatool and the Apple account that owns the game."),
        ("Decrypt it", "With unfairplay, on this Mac."),
        ("Drop it here", "Blockport converts it for the Mac in a few seconds."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Install Minecraft").font(.largeTitle.bold())
                Text("Blockport runs the iOS version of the game natively on your Mac.")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text(index + 1, format: .number)
                            .font(.callout.bold().monospacedDigit())
                            .frame(width: 26, height: 26)
                            .background(Theme.accent.opacity(0.2), in: Circle())
                            .foregroundStyle(Theme.accentBright)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.headline)
                            Text(step.detail).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            dropZone
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(dropTargeted ? Theme.accentBright : .secondary)
                .accessibilityHidden(true)
            Text(dropTargeted ? "Release to install" : "Drop the decrypted IPA here").font(.headline)
            Button("Choose a File…", action: chooseIPA)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(dropTargeted ? Theme.accent.opacity(0.12) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(dropTargeted ? Theme.accentBright : .secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }
}
