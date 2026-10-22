import SwiftUI

struct ToastView: View {
    let message: ToastState.ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(
                systemName: message.isError
                    ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
            )
            .foregroundStyle(message.isError ? .red : .green)
            Text(message.text)
                .font(.subheadline)
                .lineLimit(message.isError ? 5 : 2)
            if message.isError {
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Dismiss message")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .task(id: message.id) {
            do { try await Task.sleep(for: .seconds(message.isError ? 7 : 3)) } catch { return }
            onDismiss()
        }
        .accessibilityElement(children: .contain)
    }
}
