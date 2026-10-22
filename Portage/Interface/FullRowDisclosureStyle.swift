import SwiftUI

/// Make the label, whitespace, and chevron one accessible disclosure button.
struct FullRowDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 12)
                    configuration.label.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded {
                configuration.content.padding(.leading, 20)
            }
        }
    }
}

extension DisclosureGroupStyle where Self == FullRowDisclosureStyle {
    static var fullRow: FullRowDisclosureStyle { FullRowDisclosureStyle() }
}
