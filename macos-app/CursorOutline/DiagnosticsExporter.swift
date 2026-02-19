import AppKit
import Darwin
import Foundation

struct DiagnosticsContext {
  let settings: AppSettings
  let hotKeyStatus: String
  let outlineStatus: String
}

enum DiagnosticsExporterError: LocalizedError {
  case zipFailed(Int32)

  var errorDescription: String? {
    switch self {
    case let .zipFailed(code):
      return "Failed to package diagnostics archive (exit code \(code))."
    }
  }
}

final class DiagnosticsExporter {
  private let fileManager = FileManager.default
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()

  func defaultArchiveName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return "CursorOutline-Diagnostics-\(formatter.string(from: Date())).zip"
  }

  func exportArchive(to destinationURL: URL, context: DiagnosticsContext) throws {
    let rootDirectory = fileManager.temporaryDirectory
      .appendingPathComponent("CursorOutline-Diagnostics-\(UUID().uuidString)", isDirectory: true)

    try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

    defer {
      try? fileManager.removeItem(at: rootDirectory)
    }

    try writeSummary(to: rootDirectory.appendingPathComponent("summary.txt"), context: context)
    try writeSettings(to: rootDirectory.appendingPathComponent("settings.json"), settings: context.settings)
    try writeDisplayTopology(to: rootDirectory.appendingPathComponent("displays.json"))
    try copyLogs(to: rootDirectory.appendingPathComponent("logs", isDirectory: true))

    try createZip(sourceDirectory: rootDirectory, destinationURL: destinationURL)
  }

  func issueURL(diagnosticsArchiveName: String?) -> URL {
    let title = "Bug: <short description>"
    var body = "Please describe what happened and attach your diagnostics archive."
    if let diagnosticsArchiveName {
      body += "\n\nDiagnostics archive: `\(diagnosticsArchiveName)`"
    }

    var components = URLComponents(string: "https://github.com/II-ricky-bobby-II/display-outline-for-your-cursor/issues/new")!
    components.queryItems = [
      URLQueryItem(name: "template", value: "bug_report.yml"),
      URLQueryItem(name: "title", value: title),
      URLQueryItem(name: "body", value: body),
    ]
    return components.url!
  }

  private func writeSummary(to url: URL, context: DiagnosticsContext) throws {
    let bundle = Bundle.main
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

    let summary = [
      "App: Cursor Outline",
      "Version: \(version) (\(build))",
      "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "Architecture: \(ProcessInfo.processInfo.machineHardwareName)",
      "Hotkey status: \(context.hotKeyStatus)",
      "Outline status: \(context.outlineStatus)",
      "Exported at: \(ISO8601DateFormatter().string(from: Date()))",
    ].joined(separator: "\n")

    try summary.write(to: url, atomically: true, encoding: .utf8)
  }

  private func writeSettings(to url: URL, settings: AppSettings) throws {
    let data = try encoder.encode(settings)
    try data.write(to: url)
  }

  private func writeDisplayTopology(to url: URL) throws {
    struct DisplaySnapshot: Codable {
      let displayID: UInt32?
      let frame: String
      let visibleFrame: String
      let scale: Double
      let isMain: Bool
    }

    let mainScreenID = NSScreen.main?.displayID
    let snapshots = NSScreen.screens.map { screen in
      DisplaySnapshot(
        displayID: screen.displayID,
        frame: NSStringFromRect(screen.frame),
        visibleFrame: NSStringFromRect(screen.visibleFrame),
        scale: Double(screen.backingScaleFactor),
        isMain: screen.displayID == mainScreenID
      )
    }

    let data = try encoder.encode(snapshots)
    try data.write(to: url)
  }

  private func copyLogs(to logDirectory: URL) throws {
    try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)

    for source in AppLogger.shared.availableLogFiles() {
      let destination = logDirectory.appendingPathComponent(source.lastPathComponent, isDirectory: false)
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.copyItem(at: source, to: destination)
    }
  }

  private func createZip(sourceDirectory: URL, destinationURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = [
      "-c",
      "-k",
      "--sequesterRsrc",
      "--keepParent",
      sourceDirectory.path,
      destinationURL.path,
    ]

    if fileManager.fileExists(atPath: destinationURL.path) {
      try fileManager.removeItem(at: destinationURL)
    }

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw DiagnosticsExporterError.zipFailed(process.terminationStatus)
    }
  }
}

private extension ProcessInfo {
  var machineHardwareName: String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String(cString: machine)
  }
}
