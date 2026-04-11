/// A clipboard event emitted when the remote (RDP) host places new text on
/// its clipboard.
class FrdpClipboardEvent {
  /// The session that received the clipboard update.
  final String sessionId;

  /// The plain-text content copied on the remote host.
  final String text;

  const FrdpClipboardEvent({required this.sessionId, required this.text});
}
