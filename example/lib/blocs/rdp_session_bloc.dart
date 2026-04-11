import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frdp/frdp.dart';

part "rdp_session_event.dart";
part "rdp_session_state.dart";

class RdpSessionBloc extends Bloc<RdpSessionEvent, RdpSessionState> {
  // Polling interval for checking the connection state of the RDP session
  static const Duration _connectionStatePollingInterval = Duration(seconds: 1);
  Timer? _connectionStateTimer;

  RdpSessionBloc() : super(const RdpSessionDisconnectedState()) {
    on<ConnectRdpSessionEvent>(_onConnect);
    on<DisconnectRdpSessionEvent>(_onDisconnect);
    on<PollRdpSessionStateEvent>(_onPollConnectionState);
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
          renderingBackend:
              event.performanceProfile == FrdpPerformanceProfile.custom
              ? FrdpRenderingBackend.gfx
              : event.renderingBackend,
          performanceProfile: event.performanceProfile,
          customPerformanceProfile: event.customPerformanceProfile,
          enableClipboard: event.enableClipboard,
        ),
      );

      emit(RdpSessionConnectedState(session.id));
      _startConnectionStatePolling();
    } catch (e) {
      _stopConnectionStatePolling();
      emit(RdpSessionErrorState(e.toString()));
    }
  }

  Future<void> _onDisconnect(
    DisconnectRdpSessionEvent event,
    Emitter<RdpSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RdpSessionConnectedState) {
      _stopConnectionStatePolling();
      emit(const RdpSessionDisconnectedState());
      return;
    }

    try {
      await Frdp().disconnect(currentState.id);
      _stopConnectionStatePolling();
      emit(const RdpSessionDisconnectedState());
    } catch (e) {
      emit(RdpSessionErrorState(e.toString()));
    }
  }

  Future<void> _onPollConnectionState(
    PollRdpSessionStateEvent event,
    Emitter<RdpSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RdpSessionConnectedState) {
      _stopConnectionStatePolling();
      return;
    }

    try {
      final connectionState = await Frdp().getConnectionState(currentState.id);

      if (connectionState == FrdpConnectionState.disconnected) {
        _stopConnectionStatePolling();
        emit(const RdpSessionDisconnectedState());
        return;
      }

      if (connectionState == FrdpConnectionState.error) {
        _stopConnectionStatePolling();
        emit(const RdpSessionErrorState('Session entered error state.'));
      }
    } catch (_) {
      _stopConnectionStatePolling();
      emit(const RdpSessionDisconnectedState());
    }
  }

  void _startConnectionStatePolling() {
    _stopConnectionStatePolling();
    _connectionStateTimer = Timer.periodic(
      _connectionStatePollingInterval,
      (_) => add(const PollRdpSessionStateEvent()),
    );
  }

  void _stopConnectionStatePolling() {
    _connectionStateTimer?.cancel();
    _connectionStateTimer = null;
  }

  @override
  Future<void> close() {
    _stopConnectionStatePolling();
    return super.close();
  }

  void connect({
    required String host,
    int port = 3389,
    required String username,
    required String password,
    String? domain,
    bool ignoreCertificate = false,
    FrdpRenderingBackend renderingBackend = FrdpRenderingBackend.gdi,
    FrdpPerformanceProfile performanceProfile = FrdpPerformanceProfile.medium,
    FrdpCustomPerformanceProfile? customPerformanceProfile,
    bool enableClipboard = true,
  }) => add(
    ConnectRdpSessionEvent(
      host: host,
      port: port,
      username: username,
      password: password,
      domain: domain,
      ignoreCertificate: ignoreCertificate,
      renderingBackend: renderingBackend,
      performanceProfile: performanceProfile,
      customPerformanceProfile: customPerformanceProfile,
      enableClipboard: enableClipboard,
    ),
  );

  void disconnect() => add(DisconnectRdpSessionEvent());
}
