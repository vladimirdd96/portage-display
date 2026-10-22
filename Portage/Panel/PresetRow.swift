import SwiftUI
import KeyboardShortcuts

struct PresetRow: View {
    let preset: Preset
    let onActivate: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.body)
                    .foregroundStyle(.tint)

                Text(preset.name)

                Spacer()

                Text(preset.hotkeyName.flatMap { KeyboardShortcuts.getShortcut(for: KeyboardShortcuts.Name($0)) }?.description
                    ?? "\(preset.displayCount) display(s)")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? .white.opacity(0.08) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help((preset.assignments.map { $0.targetInputLabel } + (preset.displaySettings ?? []).map { $0.summary }).joined(separator: ", "))
        .onHover { isHovered = $0 }
    }
}
