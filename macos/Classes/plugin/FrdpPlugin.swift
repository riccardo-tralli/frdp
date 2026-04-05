import Cocoa
import FlutterMacOS

public class FrdpPlugin: NSObject, FlutterPlugin {
  private let sessionStore = FrdpSessionStore()
  private let connectCoordinator = FrdpConnectCoordinator()

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
    let request: FrdpConnectRequest
    switch FrdpConnectRequest.parse(arguments: call.arguments) {
    case .success(let parsed):
      request = parsed
    case .failure(let error):
      result(invalidArgumentsError(error.message))
      return
    }

    connectCoordinator.connect(
      request: request,
      sessionStore: sessionStore,
      result: result
    )
  }

  private func handleDisconnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let sessionId = (call.arguments as? [String: Any])?[FrdpChannel.Arg.sessionId] as? String
    if let sessionId, !sessionId.isEmpty {
      sessionStore.removeSession(id: sessionId)
    } else {
      connectCoordinator.cancelAllPending()
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
