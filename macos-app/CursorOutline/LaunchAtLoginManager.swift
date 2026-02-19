import Foundation
import ServiceManagement

enum LaunchAtLoginError: LocalizedError {
  case notInApplications(currentPath: String)
  case registrationFailed(underlying: Error, status: SMAppService.Status)

  var errorDescription: String? {
    switch self {
    case .notInApplications:
      return "Move Cursor Outline to /Applications before enabling launch at login."
    case let .registrationFailed(error, status):
      return "Unable to update launch-at-login setting: \(error.localizedDescription) (status: \(String(describing: status)))."
    }
  }
}

final class LaunchAtLoginManager {
  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    let appURL = Bundle.main.bundleURL
    if enabled && !isRunningFromApplications(appURL: appURL) {
      let path = appURL.resolvingSymlinksInPath().standardizedFileURL.path
      throw LaunchAtLoginError.notInApplications(currentPath: path)
    }

    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      throw LaunchAtLoginError.registrationFailed(
        underlying: error,
        status: SMAppService.mainApp.status
      )
    }
  }

  func isRunningFromApplications(appURL: URL = Bundle.main.bundleURL) -> Bool {
    let appPath = appURL.resolvingSymlinksInPath().standardizedFileURL.path
    let roots = applicationsRoots()
    return roots.contains(where: { isDescendant(path: appPath, root: $0) })
  }

  private func applicationsRoots() -> [String] {
    let fileManager = FileManager.default

    var roots: [String] = []
    roots.append(
      URL(fileURLWithPath: "/Applications", isDirectory: true)
        .resolvingSymlinksInPath()
        .standardizedFileURL
        .path
    )
    roots.append(
      URL(fileURLWithPath: "/System/Volumes/Data/Applications", isDirectory: true)
        .resolvingSymlinksInPath()
        .standardizedFileURL
        .path
    )

    for url in fileManager.urls(for: .applicationDirectory, in: .localDomainMask) {
      roots.append(url.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    return Array(Set(roots))
  }

  private func isDescendant(path: String, root: String) -> Bool {
    if path == root { return true }
    let normalizedRoot = root.hasSuffix("/") ? String(root.dropLast()) : root
    return path.hasPrefix(normalizedRoot + "/")
  }
}
