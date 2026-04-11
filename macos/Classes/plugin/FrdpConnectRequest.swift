import Foundation

struct FrdpConnectRequest {
  enum ParseError: Error {
    case invalidArguments(String)

    var message: String {
      switch self {
      case .invalidArguments(let message):
        return message
      }
    }
  }

  static let defaultProfile = "medium"
  static let defaultRenderingBackend = "gdi"
  static let defaultTimeoutMs = 15_000
  static let minTimeoutMs = 1_000
  static let maxTimeoutMs = 120_000

  let host: String
  let port: Int
  let username: String
  let password: String
  let domain: String?
  let profile: String
  let renderingBackend: String
  let ignoreCertificate: Bool
  let enableClipboard: Bool
  let disableClipboardPerformanceFallback: Bool
  let timeoutMs: Int

  // Optional custom performance profile.  Present only when the caller
  // supplied at least `customDesktopWidth` + `customDesktopHeight`.
  let customDesktopWidth: Int?
  let customDesktopHeight: Int?
  /// Numeric FreeRDP CONNECTION_TYPE_* value (1–7).
  let customConnectionTypeValue: Int?
  let customColorDepth: Int?
  let customDisableWallpaper: Bool?
  let customDisableFullWindowDrag: Bool?
  let customDisableMenuAnimations: Bool?
  let customDisableThemes: Bool?
  let customAllowDesktopComposition: Bool?
  let customAllowFontSmoothing: Bool?
  let customGfxSurfaceCommandsEnabled: Bool?
  let customGfxProgressive: Bool?
  let customGfxProgressiveV2: Bool?
  let customGfxPlanar: Bool?
  let customGfxH264: Bool?
  let customGfxAvc444: Bool?
  let customGfxAvc444V2: Bool?

  var hasCustomProfile: Bool {
    return profile == "custom"
  }

  static func parse(arguments: Any?) -> Result<FrdpConnectRequest, ParseError> {
    guard let args = arguments as? [String: Any] else {
      return .failure(.invalidArguments("Expected connection configuration map."))
    }

    guard
      let host = args[FrdpChannel.Arg.host] as? String,
      let username = args[FrdpChannel.Arg.username] as? String,
      let password = args[FrdpChannel.Arg.password] as? String,
      let port = args[FrdpChannel.Arg.port] as? Int,
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      (1...65535).contains(port)
    else {
      return .failure(.invalidArguments("host, port, username, and password are required."))
    }

    let timeout = args[FrdpChannel.Arg.connectTimeoutMs] as? Int ?? defaultTimeoutMs
    let clampedTimeout = min(max(timeout, minTimeoutMs), maxTimeoutMs)

    // Parse custom performance profile fields.
    let customDesktopWidth  = args[FrdpChannel.Arg.customDesktopWidth]  as? Int
    let customDesktopHeight = args[FrdpChannel.Arg.customDesktopHeight] as? Int
    let customConnectionTypeName = args[FrdpChannel.Arg.customConnectionType] as? String
    let customColorDepth    = args[FrdpChannel.Arg.customColorDepth]    as? Int

    return .success(
      FrdpConnectRequest(
        host: host,
        port: port,
        username: username,
        password: password,
        domain: args[FrdpChannel.Arg.domain] as? String,
        profile: (args[FrdpChannel.Arg.performanceProfile] as? String) ?? defaultProfile,
        renderingBackend: (args[FrdpChannel.Arg.renderingBackend] as? String) ?? defaultRenderingBackend,
        ignoreCertificate: (args[FrdpChannel.Arg.ignoreCertificate] as? Bool) ?? false,
        enableClipboard: (args[FrdpChannel.Arg.enableClipboard] as? Bool) ?? true,
        disableClipboardPerformanceFallback:
          (args[FrdpChannel.Arg.disableClipboardPerformanceFallback] as? Bool) ?? false,
        timeoutMs: clampedTimeout,
        customDesktopWidth: customDesktopWidth,
        customDesktopHeight: customDesktopHeight,
        customConnectionTypeValue: FrdpConnectRequest.connectionTypeValue(for: customConnectionTypeName),
        customColorDepth: customColorDepth,
        customDisableWallpaper:        args[FrdpChannel.Arg.customDisableWallpaper]        as? Bool,
        customDisableFullWindowDrag:   args[FrdpChannel.Arg.customDisableFullWindowDrag]   as? Bool,
        customDisableMenuAnimations:   args[FrdpChannel.Arg.customDisableMenuAnimations]   as? Bool,
        customDisableThemes:           args[FrdpChannel.Arg.customDisableThemes]           as? Bool,
        customAllowDesktopComposition: args[FrdpChannel.Arg.customAllowDesktopComposition] as? Bool,
        customAllowFontSmoothing:      args[FrdpChannel.Arg.customAllowFontSmoothing]      as? Bool,
        customGfxSurfaceCommandsEnabled: args[FrdpChannel.Arg.customGfxSurfaceCommandsEnabled] as? Bool,
        customGfxProgressive:            args[FrdpChannel.Arg.customGfxProgressive]            as? Bool,
        customGfxProgressiveV2:          args[FrdpChannel.Arg.customGfxProgressiveV2]          as? Bool,
        customGfxPlanar:                 args[FrdpChannel.Arg.customGfxPlanar]                 as? Bool,
        customGfxH264:                   args[FrdpChannel.Arg.customGfxH264]                   as? Bool,
        customGfxAvc444:                 args[FrdpChannel.Arg.customGfxAvc444]                 as? Bool,
        customGfxAvc444V2:               args[FrdpChannel.Arg.customGfxAvc444V2]               as? Bool
      )
    )
  }

  // MARK: - Helpers

  /// Converts a Dart `FrdpConnectionType.name` string to the numeric
  /// FreeRDP `CONNECTION_TYPE_*` constant (1–7).  Returns `nil` when the
  /// name is absent, so the caller can skip setting the custom profile.
  private static func connectionTypeValue(for name: String?) -> Int? {
    guard let name else { return nil }
    switch name.lowercased() {
    case "modem":         return 1
    case "broadbandlow":  return 2
    case "broadbandhigh": return 3
    case "satellite":     return 4
    case "wan":           return 5
    case "lan":           return 6
    case "autodetect":    return 7
    default:              return 2  // broadbandLow fallback
    }
  }
}

