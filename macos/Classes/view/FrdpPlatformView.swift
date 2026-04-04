import Cocoa
import FlutterMacOS

final class FrdpPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let sessionStore: FrdpSessionStore

  init(sessionStore: FrdpSessionStore) {
    self.sessionStore = sessionStore
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    FrdpPlatformView(frame: .zero, viewId: viewId, args: args, sessionStore: sessionStore)
  }

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class FrdpPlatformView: NSView {
  private var embeddedView: NSView?
  private var inputOverlay: FrdpInputOverlayView?

  init(frame: NSRect, viewId: Int64, args: Any?, sessionStore: FrdpSessionStore) {
    super.init(frame: frame)

    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor

    let sessionId = (args as? [String: Any])?[FrdpChannel.Arg.sessionId] as? String
    if let sessionId, let session = sessionStore.getSession(id: sessionId) {
      attachSession(session)
    } else {
      showPlaceholder()
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Private helpers

  private func attachSession(_ session: FrdpSession) {
    let view = session.engine.renderView
    view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(view)
    embeddedView = view

    let overlay = FrdpInputOverlayView(engine: session.engine)
    overlay.translatesAutoresizingMaskIntoConstraints = false
    addSubview(overlay)
    inputOverlay = overlay

    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: leadingAnchor),
      view.trailingAnchor.constraint(equalTo: trailingAnchor),
      view.topAnchor.constraint(equalTo: topAnchor),
      view.bottomAnchor.constraint(equalTo: bottomAnchor),
      overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
      overlay.topAnchor.constraint(equalTo: topAnchor),
      overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func showPlaceholder() {
    let label = NSTextField(labelWithString: "Embedded RDP session not found")
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: centerXAnchor),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}
