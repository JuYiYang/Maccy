import SwiftUI
import Defaults

struct AdvancedSettingsPane: View {
  @Default(.cloudSyncEnabled) private var cloudSyncEnabled
  @Default(.cloudSyncServerURL) private var cloudSyncServerURL
  @Default(.cloudSyncToken) private var cloudSyncToken
  @Default(.cloudSyncLastError) private var cloudSyncLastError
  @Default(.cloudSyncLastSyncedAt) private var cloudSyncLastSyncedAt

  var body: some View {
    VStack(alignment: .leading) {
      Defaults.Toggle(key: .ignoreEvents) {
        Text("TurnOff", tableName: "AdvancedSettings")
      }
      Text("TurnOffDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      Text("TurnOffShellScript", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .font(.system(size: 11, design: .monospaced))
        .controlSize(.small)
        .padding(.vertical, 2)
      Text("TurnOffViaMenuIconDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      Text("TurnOffNextShellScript", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .font(.system(size: 11, design: .monospaced))
        .controlSize(.small)
        .padding(.vertical, 2)

      Divider()

      Defaults.Toggle(key: .clearOnQuit) {
        Text("ClearHistoryOnQuit", tableName: "AdvancedSettings")
      }.help(Text("ClearHistoryOnQuitTooltip", tableName: "AdvancedSettings"))

      Defaults.Toggle(key: .clearSystemClipboard) {
        Text("ClearSystemClipboard", tableName: "AdvancedSettings")
      }.help(Text("ClearSystemClipboardTooltip", tableName: "AdvancedSettings"))

      Divider()

      Toggle(isOn: $cloudSyncEnabled) {
        Text("CloudSync", tableName: "AdvancedSettings")
      }
      Text("CloudSyncDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)

      Text("CloudSyncServerURL", tableName: "AdvancedSettings")
        .controlSize(.small)
      TextField("https://api.example.com", text: $cloudSyncServerURL)
        .textFieldStyle(.roundedBorder)
        .disabled(!cloudSyncEnabled)

      Text("CloudSyncToken", tableName: "AdvancedSettings")
        .controlSize(.small)
      SecureField("", text: $cloudSyncToken)
        .textFieldStyle(.roundedBorder)
        .disabled(!cloudSyncEnabled)

      HStack {
        Button {
          CloudSyncService.shared.syncNow()
        } label: {
          Text("CloudSyncNow", tableName: "AdvancedSettings")
        }
        .disabled(!cloudSyncEnabled || cloudSyncServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if cloudSyncLastSyncedAt > 0 {
          Text(Date(timeIntervalSince1970: cloudSyncLastSyncedAt), style: .relative)
            .controlSize(.small)
            .foregroundStyle(.gray)
        }
      }

      if !cloudSyncLastError.isEmpty {
        Text(cloudSyncLastError)
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.red)
          .controlSize(.small)
      }
    }
    .frame(minWidth: 350, maxWidth: 450)
    .padding()
  }
}

#Preview {
  AdvancedSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
