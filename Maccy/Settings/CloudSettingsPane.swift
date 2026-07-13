import Defaults
import Settings
import SwiftUI

struct CloudSettingsPane: View {
  @Default(.cloudSyncDeviceID) private var cloudSyncDeviceID
  @Default(.cloudSyncEnabled) private var cloudSyncEnabled
  @Default(.cloudSyncIntervalSeconds) private var cloudSyncIntervalSeconds
  @Default(.cloudSyncLastError) private var cloudSyncLastError
  @Default(.cloudSyncLastSyncedAt) private var cloudSyncLastSyncedAt
  @Default(.cloudSyncServerURL) private var cloudSyncServerURL
  @Default(.cloudSyncToken) private var cloudSyncToken

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(title: "", bottomDivider: true) {
        Toggle(isOn: $cloudSyncEnabled) {
          Text("CloudSync", tableName: "CloudSettings")
        }
        Text("CloudSyncDescription", tableName: "CloudSettings")
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.gray)
          .controlSize(.small)
      }

      Settings.Section(bottomDivider: true, label: { Text("Connection", tableName: "CloudSettings") }) {
        VStack(alignment: .leading, spacing: 8) {
          Text("ServerURL", tableName: "CloudSettings")
            .controlSize(.small)
          TextField("https://clipbridge-server.example.workers.dev", text: $cloudSyncServerURL)
            .textFieldStyle(.roundedBorder)
            .disabled(!cloudSyncEnabled)

          Text("AccessToken", tableName: "CloudSettings")
            .controlSize(.small)
          SecureField("", text: $cloudSyncToken)
            .textFieldStyle(.roundedBorder)
            .disabled(!cloudSyncEnabled)

          Text("AccessTokenDescription", tableName: "CloudSettings")
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.gray)
            .controlSize(.small)
        }
      }

      Settings.Section(bottomDivider: true, label: { Text("Schedule", tableName: "CloudSettings") }) {
        Picker("", selection: $cloudSyncIntervalSeconds) {
          Text("15s").tag(15)
          Text("30s").tag(30)
          Text("1m").tag(60)
          Text("5m").tag(300)
          Text("15m").tag(900)
          Text("1h").tag(3600)
        }
        .labelsHidden()
        .frame(width: 180, alignment: .leading)
        .disabled(!cloudSyncEnabled)

        Text("ScheduleDescription", tableName: "CloudSettings")
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.gray)
          .controlSize(.small)
      }

      Settings.Section(bottomDivider: true, label: { Text("Status", tableName: "CloudSettings") }) {
        HStack {
          Button {
            CloudSyncService.shared.syncNow()
          } label: {
            Text("SyncNow", tableName: "CloudSettings")
          }
          .disabled(!canSync)

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

      Settings.Section(label: { Text("Device", tableName: "CloudSettings") }) {
        Text(deviceIDLabel)
          .font(.system(size: 11, design: .monospaced))
          .textSelection(.enabled)
          .foregroundStyle(.gray)
      }
    }
  }

  private var canSync: Bool {
    cloudSyncEnabled && !cloudSyncServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var deviceIDLabel: String {
    if cloudSyncDeviceID.isEmpty {
      return NSLocalizedString("DeviceIDPending", tableName: "CloudSettings", comment: "")
    }
    return cloudSyncDeviceID
  }
}

#Preview {
  CloudSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
