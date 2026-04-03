import "frdp_connection_state.dart";
import "../channel/frdp_channel_contract.dart";

class FrdpSession {
  final String id;
  final FrdpConnectionState state;

  const FrdpSession({required this.id, required this.state});

  factory FrdpSession.fromMap(Map<dynamic, dynamic> map) => FrdpSession(
    id: (map[kSessionIdArg] ?? "").toString(),
    state: parseFrdpConnectionState(map[kStateArg]?.toString()),
  );
}
