// Channel name and method identifiers shared between the Dart and native sides.
enum FrdpChannel {
  static let name = "frdp"

  enum Method {
    static let getPlatformVersion = "getPlatformVersion"
    static let connect            = "connect"
    static let disconnect         = "disconnect"
    static let getConnectionState = "getConnectionState"
    static let sendPointerEvent   = "sendPointerEvent"
    static let sendKeyEvent       = "sendKeyEvent"
  }

  enum Arg {
    static let sessionId          = "sessionId"
    static let host               = "host"
    static let port               = "port"
    static let username           = "username"
    static let password           = "password"
    static let domain             = "domain"
    static let ignoreCertificate  = "ignoreCertificate"
    static let performanceProfile = "performanceProfile"
    static let x                  = "x"
    static let y                  = "y"
    static let buttons            = "buttons"
    static let keyCode            = "keyCode"
    static let isDown             = "isDown"
  }

  enum State {
    static let disconnected = "disconnected"
    static let connecting   = "connecting"
    static let connected    = "connected"
    static let error        = "error"
  }

  enum ViewType {
    static let rdpView = "frdp/view"
  }
}
