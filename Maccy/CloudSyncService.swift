import CryptoKit
import Defaults
import Foundation

struct CloudClipboardContent: Codable {
  let type: String
  let value: Data?
}

struct CloudClipboardItem: Codable, Identifiable {
  let id: String
  let title: String
  let application: String?
  let firstCopiedAt: Date
  let lastCopiedAt: Date
  let numberOfCopies: Int
  let pin: String?
  let contents: [CloudClipboardContent]
  let sourceDeviceID: String

  @MainActor
  init(item: HistoryItem, sourceDeviceID: String = Defaults[.cloudSyncDeviceID]) {
    self.id = item.cloudSyncID
    self.title = item.title
    self.application = item.application
    self.firstCopiedAt = item.firstCopiedAt
    self.lastCopiedAt = item.lastCopiedAt
    self.numberOfCopies = item.numberOfCopies
    self.pin = item.pin
    self.contents = item.contents.map { CloudClipboardContent(type: $0.type, value: $0.value) }
    self.sourceDeviceID = sourceDeviceID
  }

  @MainActor
  func makeHistoryItem() -> HistoryItem {
    let item = HistoryItem(contents: contents.map { HistoryItemContent(type: $0.type, value: $0.value) })
    item.application = application
    item.firstCopiedAt = firstCopiedAt
    item.lastCopiedAt = lastCopiedAt
    item.numberOfCopies = numberOfCopies
    item.pin = pin
    item.title = title.isEmpty ? item.generateTitle() : title
    return item
  }
}

struct CloudSyncPushRequest: Codable {
  let deviceID: String
  let items: [CloudClipboardItem]
}

struct CloudSyncPullResponse: Codable {
  let items: [CloudClipboardItem]
  let nextSince: Double?
}

final class CloudSyncService {
  static let shared = CloudSyncService()

  private var configurationTask: Task<Void, Never>?
  private var periodicSyncTask: Task<Void, Never>?
  private var syncTask: Task<Void, Never>?

  private var isConfigured: Bool {
    Defaults[.cloudSyncEnabled] && baseURL != nil
  }

  private var baseURL: URL? {
    let value = Defaults[.cloudSyncServerURL].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty,
          let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme) else { return nil }
    return url
  }

  private init() {}

  func start() {
    ensureDeviceID()
    configurationTask?.cancel()
    configurationTask = Task {
      await observeConfigurationChanges()
    }
    schedulePeriodicSync()
  }

  private func ensureDeviceID() {
    guard Defaults[.cloudSyncDeviceID].isEmpty else { return }
    Defaults[.cloudSyncDeviceID] = UUID().uuidString
  }

  @MainActor
  func historyDidLoad() {
    syncNow()
  }

  func syncNow() {
    syncTask?.cancel()
    syncTask = Task {
      await synchronize()
    }
  }

  @MainActor
  func uploadNewCopy(_ item: HistoryItem) {
    guard isConfigured else { return }

    let payload = CloudClipboardItem(item: item)
    Task {
      await push([payload])
    }
  }

  private func observeConfigurationChanges() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        for await _ in Defaults.updates(.cloudSyncEnabled, initial: false) {
          self.schedulePeriodicSync()
          self.syncNow()
        }
      }
      group.addTask {
        for await _ in Defaults.updates(.cloudSyncServerURL, initial: false) {
          self.schedulePeriodicSync()
          self.syncNow()
        }
      }
      group.addTask {
        for await _ in Defaults.updates(.cloudSyncToken, initial: false) {
          self.syncNow()
        }
      }
      group.addTask {
        for await _ in Defaults.updates(.cloudSyncIntervalSeconds, initial: false) {
          self.schedulePeriodicSync()
        }
      }
    }
  }

  private func schedulePeriodicSync() {
    periodicSyncTask?.cancel()
    guard isConfigured else { return }

    let interval = max(15, Defaults[.cloudSyncIntervalSeconds])
    periodicSyncTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
        guard !Task.isCancelled else { return }
        self?.syncNow()
      }
    }
  }

  private func synchronize() async {
    guard Defaults[.cloudSyncEnabled] else { return }
    guard isConfigured else {
      await recordSyncError(CloudSyncError.invalidServerURL)
      return
    }

    let localItems = await MainActor.run {
      History.shared.all.map { CloudClipboardItem(item: $0.item) }
    }

    await push(localItems)
    await pullRemoteItems()
  }

  private func push(_ items: [CloudClipboardItem]) async {
    guard isConfigured, !items.isEmpty else { return }

    do {
      var request = try makeRequest(path: "v1/clipboard/items", method: "POST")
      request.httpBody = try jsonEncoder.encode(
        CloudSyncPushRequest(deviceID: Defaults[.cloudSyncDeviceID], items: items)
      )
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      try await send(request)
      await recordSuccessfulSync()
    } catch {
      await recordSyncError(error)
    }
  }

  private func pullRemoteItems() async {
    guard isConfigured else { return }

    do {
      let since = Defaults[.cloudSyncLastPulledAt]
      let response: CloudSyncPullResponse = try await send(
        makeRequest(path: "v1/clipboard/items", method: "GET", queryItems: [
          URLQueryItem(name: "since", value: String(since))
        ])
      )

      await MainActor.run {
        let localDeviceID = Defaults[.cloudSyncDeviceID]
        var knownIDs = Set(History.shared.all.map { $0.item.cloudSyncID })

        for payload in response.items where payload.sourceDeviceID != localDeviceID && !knownIDs.contains(payload.id) {
          let item = payload.makeHistoryItem()
          History.shared.add(item)
          knownIDs.insert(payload.id)
        }

        Defaults[.cloudSyncLastPulledAt] = response.nextSince ?? Date.now.timeIntervalSince1970
      }

      await recordSuccessfulSync()
    } catch {
      await recordSyncError(error)
    }
  }

  private func makeRequest(path: String, method: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
    guard let baseURL else { throw CloudSyncError.invalidServerURL }

    let endpoint = baseURL.appending(path: path)
    guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
      throw CloudSyncError.invalidServerURL
    }
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    guard let url = components.url else { throw CloudSyncError.invalidServerURL }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(Defaults[.cloudSyncDeviceID], forHTTPHeaderField: "X-ClipBridge-Device-ID")

    let token = Defaults[.cloudSyncToken].trimmingCharacters(in: .whitespacesAndNewlines)
    if !token.isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    return request
  }

  private func send(_ request: URLRequest) async throws {
    let (_, response) = try await URLSession.shared.data(for: request)
    try validate(response)
  }

  private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await URLSession.shared.data(for: request)
    try validate(response)
    return try jsonDecoder.decode(Response.self, from: data)
  }

  private func validate(_ response: URLResponse) throws {
    guard let response = response as? HTTPURLResponse else {
      throw CloudSyncError.invalidResponse
    }
    guard 200..<300 ~= response.statusCode else {
      throw CloudSyncError.httpStatus(response.statusCode)
    }
  }

  @MainActor
  private func recordSuccessfulSync() {
    Defaults[.cloudSyncLastError] = ""
    Defaults[.cloudSyncLastSyncedAt] = Date.now.timeIntervalSince1970
  }

  @MainActor
  private func recordSyncError(_ error: Error) {
    Defaults[.cloudSyncLastError] = error.localizedDescription
  }

  private var jsonEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private var jsonDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

enum CloudSyncError: LocalizedError {
  case invalidServerURL
  case invalidResponse
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .invalidServerURL:
      return "Cloud sync server URL is invalid."
    case .invalidResponse:
      return "Cloud sync server returned an invalid response."
    case .httpStatus(let statusCode):
      return "Cloud sync server returned HTTP \(statusCode)."
    }
  }
}

extension HistoryItem {
  var cloudSyncID: String {
    var hasher = SHA256()

    for content in contents.sorted(by: { $0.type < $1.type }) {
      hasher.update(data: Data(content.type.utf8))
      hasher.update(data: Data([0]))
      if let value = content.value {
        hasher.update(data: value)
      }
      hasher.update(data: Data([31]))
    }

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
}
