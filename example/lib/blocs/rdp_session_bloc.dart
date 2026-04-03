import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frdp/frdp.dart';

part "rdp_session_event.dart";
part "rdp_session_state.dart";

class RdpSessionBloc extends Bloc<RdpSessionEvent, RdpSessionState> {
  RdpSessionBloc() : super(const RdpSessionDisconnectedState()) {
    on<ConnectRdpSessionEvent>(_onConnect);
    on<DisconnectRdpSessionEvent>(_onDisconnect);
  }

  Future<void> _onConnect(
    ConnectRdpSessionEvent event,
    Emitter<RdpSessionState> emit,
  ) async {
    emit(const RdpSessionConnectingState());
    try {
      final FrdpSession session = await Frdp().connect(
        FrdpConnectionConfig(
          host: event.host,
          port: event.port,
          username: event.username,
          password: event.password,
          domain: event.domain,
          ignoreCertificate: event.ignoreCertificate,
          performanceProfile: event.performanceProfile,
        ),
      );
      emit(RdpSessionConnectedState(session.id));
    } catch (e) {
      emit(RdpSessionErrorState(e.toString()));
    }
  }

  Future<void> _onDisconnect(
    DisconnectRdpSessionEvent event,
    Emitter<RdpSessionState> emit,
  ) async {
    try {
      await Frdp().disconnect(
        sessionId: (state as RdpSessionConnectedState).id,
      );
      emit(const RdpSessionDisconnectedState());
    } catch (e) {
      emit(RdpSessionErrorState(e.toString()));
    }
  }

  void connect({
    required String host,
    int port = 3389,
    required String username,
    required String password,
    String? domain,
    bool ignoreCertificate = false,
    FrdpPerformanceProfile performanceProfile = FrdpPerformanceProfile.medium,
  }) => add(
    ConnectRdpSessionEvent(
      host: host,
      port: port,
      username: username,
      password: password,
      domain: domain,
      ignoreCertificate: ignoreCertificate,
      performanceProfile: performanceProfile,
    ),
  );

  void disconnect() => add(DisconnectRdpSessionEvent());
}
