import Foundation

final class AppLogger {
  enum Level: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var label: String {
      switch self {
      case .debug: return "DEBUG"
      case .info: return "INFO"
      case .warning: return "WARN"
      case .error: return "ERROR"
      }
    }
  }

  static let shared = AppLogger()

  private let queue = DispatchQueue(label: "CursorOutline.AppLogger")
  private let fileManager = FileManager.default
  private let maxFileSizeBytes: UInt64 = 1_000_000
  private let maxRotatedFiles = 3

  private(set) var logDirectoryURL: URL
  private(set) var logFileURL: URL

  private let minimumLevel: Level = {
    #if DEBUG
    return .debug
    #else
    return .info
    #endif
  }()

  private init() {
    let root = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent("CursorOutline", isDirectory: true)

    logDirectoryURL = root
    logFileURL = root.appendingPathComponent("cursor-outline.log", isDirectory: false)

    do {
      try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    } catch {
      NSLog("CursorOutline: failed to create log directory: \(error)")
    }
  }

  func log(_ level: Level, _ message: String) {
    guard level.rawValue >= minimumLevel.rawValue else { return }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) [\(level.label)] \(message)\n"

    queue.async { [weak self] in
      guard let self else { return }
      self.rotateIfNeeded()
      self.append(line: line)
    }

    #if DEBUG
    NSLog("CursorOutline: \(message)")
    #endif
  }

  func availableLogFiles() -> [URL] {
    queue.sync {
      var urls: [URL] = []
      for index in 0...maxRotatedFiles {
        let url = index == 0 ? logFileURL : rotatedLogURL(index: index)
        if fileManager.fileExists(atPath: url.path) {
          urls.append(url)
        }
      }
      return urls
    }
  }

  private func append(line: String) {
    guard let data = line.data(using: .utf8) else { return }

    if !fileManager.fileExists(atPath: logFileURL.path) {
      fileManager.createFile(atPath: logFileURL.path, contents: data)
      return
    }

    do {
      let handle = try FileHandle(forWritingTo: logFileURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
    } catch {
      NSLog("CursorOutline: failed writing log: \(error)")
    }
  }

  private func rotateIfNeeded() {
    guard
      let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
      let size = attributes[.size] as? UInt64,
      size >= maxFileSizeBytes
    else {
      return
    }

    let oldest = rotatedLogURL(index: maxRotatedFiles)
    try? fileManager.removeItem(at: oldest)

    if maxRotatedFiles > 1 {
      for index in stride(from: maxRotatedFiles - 1, through: 1, by: -1) {
        let source = rotatedLogURL(index: index)
        let destination = rotatedLogURL(index: index + 1)
        if fileManager.fileExists(atPath: source.path) {
          try? fileManager.moveItem(at: source, to: destination)
        }
      }
    }

    let firstRotated = rotatedLogURL(index: 1)
    if fileManager.fileExists(atPath: firstRotated.path) {
      try? fileManager.removeItem(at: firstRotated)
    }
    try? fileManager.moveItem(at: logFileURL, to: firstRotated)
  }

  private func rotatedLogURL(index: Int) -> URL {
    logDirectoryURL.appendingPathComponent("cursor-outline.log.\(index)", isDirectory: false)
  }
}
