import SwiftUI
import UIKit

/// The answer box. A UIKit field, because the answer has to change while it's typed (romaji turns
/// into kana), and SwiftUI's TextField on iOS either drops fast keystrokes or keeps showing the
/// romaji when its text is rewritten. Here each keystroke is converted before UIKit applies it.
struct AnswerTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    /// Applied to the whole text after every keystroke.
    var transform: (String) -> String = { $0 }
    /// While true, typing is ignored: the answered text stays put until the next card.
    var isLocked = false
    /// Keeps the keyboard up while true.
    var wantsFocus = true
    var returnKey: UIReturnKeyType = .done
    let onReturn: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 26)
        field.textAlignment = .center
        field.textColor = .white
        field.tintColor = .white
        // Romaji turns into kana as you type, so the English keyboard is the one to use, and
        // the Japanese keyboard's own conversion would fight it.
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.addTarget(context.coordinator, action: #selector(Coordinator.edited(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder, attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)])
        if field.returnKeyType != returnKey {
            field.returnKeyType = returnKey
            field.reloadInputViews()
        }
        if wantsFocus, !field.isFirstResponder {
            // Not during the view update itself.
            DispatchQueue.main.async { field.becomeFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AnswerTextField

        init(_ parent: AnswerTextField) { self.parent = parent }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !parent.isLocked else { return false }
            let edited = ((field.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            let converted = parent.transform(edited)
            if converted == edited { return true }   // UIKit applies it; edited(_:) reports it
            field.text = converted
            parent.text = converted
            return false
        }

        @objc func edited(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onReturn()
            return false   // keep the keyboard up between cards
        }
    }
}
