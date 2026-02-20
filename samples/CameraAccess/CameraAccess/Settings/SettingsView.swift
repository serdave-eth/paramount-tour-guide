import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  var connectAction: (() -> Void)? = nil
  var disconnectAction: (() -> Void)? = nil

  var body: some View {
    NavigationView {
      Form {
        if let connectAction {
          Section {
            Button("Connect Glasses") {
              connectAction()
              dismiss()
            }
          }
        }
        if let disconnectAction {
          Section {
            Button("Disconnect Glasses", role: .destructive) {
              disconnectAction()
              dismiss()
            }
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}
