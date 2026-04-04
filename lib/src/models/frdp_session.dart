import "frdp_connection_state.dart";
import "../channel/frdp_channel_contract.dart";

/// Represents an active RDP session with its unique identifier and current connection state.
class FrdpSession {
  /// The unique identifier of the session.
  final String id;

  /// The current connection state of the session.
  final FrdpConnectionState state;

  /// Constructs a [FrdpSession] instance with the given [id] and [state].
  const FrdpSession({required this.id, required this.state});

  /// Creates a [FrdpSession] instance from a map of key-value pairs.
  factory FrdpSession.fromMap(Map<dynamic, dynamic> map) => FrdpSession(
    id: (map[kSessionIdArg] ?? "").toString(),
    state: parseFrdpConnectionState(map[kStateArg]?.toString()),
  );
}
