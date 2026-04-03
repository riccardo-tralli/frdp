import Cocoa
import FlutterMacOS

public class FrdpPlugin: NSObject, FlutterPlugin {
  private let sessionStore = FrdpSessionStore()

  // MARK: - Registration

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: FrdpChannel.name,
      binaryMessenger: registrar.messenger
    )
    let instance = FrdpPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(
      FrdpPlatformViewFactory(sessionStore: instance.sessionStore),
      withId: FrdpChannel.ViewType.rdpView
    )
  }

  // MARK: - Method call dispatch

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case FrdpChannel.Method.getPlatformVersion:
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case FrdpChannel.Method.connect:
      handleConnect(call: call, result: result)
    case FrdpChannel.Method.disconnect:
      handleDisconnect(call: call, result: result)
    case FrdpChannel.Method.getConnectionState:
      handleGetConnectionState(call: call, result: result)
    case FrdpChannel.Method.sendPointerEvent:
      handleSendPointerEvent(call: call, result: result)
    case FrdpChannel.Method.sendKeyEvent:
      handleSendKeyEvent(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Handlers

  private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(invalidArgumentsError("Expected connection configuration map."))
      return
    }

    guard
      let host     = args[FrdpChannel.Arg.host]     as? String,
      let username = args[FrdpChannel.Arg.username] as? String,
      let password = args[FrdpChannel.Arg.password] as? String,
      let port     = args[FrdpChannel.Arg.port]     as? Int,
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      (1...65535).contains(port)
    else {
      result(invalidArgumentsError("host, port, username, and password are required."))
      return
    }

    let session = FrdpSession(
      host: host,
      port: port,
      username: username,
      domain: args[FrdpChannel.Arg.domain] as? String
    )

    session.engine.connectionStateDidChange = { [weak session] connected in
      guard let session else { return }
      session.state = connected ? FrdpChannel.State.connected : FrdpChannel.State.disconnected
    }

    session.state = FrdpChannel.State.connecting

    do {
      let profile = (args[FrdpChannel.Arg.performanceProfile] as? String) ?? "medium"
      try session.engine.connect(
        withHost: host,
        port: port,
        username: username,
        password: password,
        domain: args[FrdpChannel.Arg.domain] as? String,
        ignoreCertificate: (args[FrdpChannel.Arg.ignoreCertificate] as? Bool) ?? false,
        performanceProfile: profile
      )
    } catch {
      session.state = FrdpChannel.State.error
      result(FlutterError(code: "RDP_CONNECT_FAILED", message: error.localizedDescription, details: nil))
      return
    }

    session.state = FrdpChannel.State.connected
    sessionStore.addSession(session)
    result([FrdpChannel.Arg.sessionId: session.sessionId, "state": session.state])
  }

  private func handleDisconnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let sessionId = (call.arguments as? [String: Any])?[FrdpChannel.Arg.sessionId] as? String
    if let sessionId, !sessionId.isEmpty {
      sessionStore.removeSession(id: sessionId)
    } else {
      sessionStore.removeAll()
    }
    result(nil)
  }

  private func handleGetConnectionState(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let sessionId = (call.arguments as? [String: Any])?[FrdpChannel.Arg.sessionId] as? String
    if let sessionId, let session = sessionStore.getSession(id: sessionId) {
      result(session.state)
      return
    }
    result(sessionStore.globalState)
  }

  private func handleSendPointerEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args      = call.arguments as? [String: Any],
      let sessionId = args[FrdpChannel.Arg.sessionId] as? String,
      let x         = args[FrdpChannel.Arg.x]         as? Double,
      let y         = args[FrdpChannel.Arg.y]         as? Double,
      let buttons   = args[FrdpChannel.Arg.buttons]   as? Int,
      let session   = sessionStore.getSession(id: sessionId)
    else {
      result(invalidArgumentsError("Invalid pointer event payload or session not found."))
      return
    }
    session.engine.sendPointerEventWith(x: x, y: y, buttons: buttons)
    result(nil)
  }

  private func handleSendKeyEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args      = call.arguments as? [String: Any],
      let sessionId = args[FrdpChannel.Arg.sessionId] as? String,
      let keyCode   = args[FrdpChannel.Arg.keyCode]   as? Int,
      let isDown    = args[FrdpChannel.Arg.isDown]    as? Bool,
      let session   = sessionStore.getSession(id: sessionId)
    else {
      result(invalidArgumentsError("Invalid key event payload or session not found."))
      return
    }
    session.engine.sendKeyEvent(withKeyCode: keyCode, isDown: isDown)
    result(nil)
  }

  // MARK: - Error helper

  private func invalidArgumentsError(_ message: String) -> FlutterError {
    FlutterError(code: "INVALID_ARGUMENTS", message: message, details: nil)
  }
}
