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
  static let defaultTimeoutMs = 15_000
  static let minTimeoutMs = 1_000
  static let maxTimeoutMs = 120_000

  let host: String
  let port: Int
  let username: String
  let password: String
  let domain: String?
  let profile: String
  let ignoreCertificate: Bool
  let timeoutMs: Int

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

    return .success(
      FrdpConnectRequest(
        host: host,
        port: port,
        username: username,
        password: password,
        domain: args[FrdpChannel.Arg.domain] as? String,
        profile: (args[FrdpChannel.Arg.performanceProfile] as? String) ?? defaultProfile,
        ignoreCertificate: (args[FrdpChannel.Arg.ignoreCertificate] as? Bool) ?? false,
        timeoutMs: clampedTimeout
      )
    )
  }
}
