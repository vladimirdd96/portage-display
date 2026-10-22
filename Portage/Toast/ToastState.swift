import Foundation
import Observation

@Observable
@MainActor
final class ToastState {
    var currentToast: ToastMessage?

    struct ToastMessage: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    func show(_ text: String, isError: Bool = false) {
        currentToast = ToastMessage(text: text, isError: isError)
    }

    func dismiss() {
        currentToast = nil
    }
}
