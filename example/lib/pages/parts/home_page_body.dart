part of "../home_page.dart";

Widget _homePageBody({
  required BuildContext context,
  required RdpSessionState state,
  required TextEditingController hostController,
  required TextEditingController portController,
  required TextEditingController usernameController,
  required TextEditingController passwordController,
  required TextEditingController domainController,
  required bool ignoreCertificate,
  required Function() onIgnoreCertificateChanged,
  required FrdpPerformanceProfile performanceProfile,
  required Function(FrdpPerformanceProfile) onPerformanceProfileChanged,
  required bool enableClipboard,
  required Function() onEnableClipboardChanged,
  required Function() onButtonPressed,
}) => Row(
  children: [
    Expanded(
      flex: 3,
      child: _sideMenu(
        context: context,
        state: state,
        hostController: hostController,
        portController: portController,
        usernameController: usernameController,
        passwordController: passwordController,
        domainController: domainController,
        ignoreCertificate: ignoreCertificate,
        onIgnoreCertificateChanged: () => onIgnoreCertificateChanged(),
        performanceProfile: performanceProfile,
        onPerformanceProfileChanged: (value) =>
            onPerformanceProfileChanged(value),
        enableClipboard: enableClipboard,
        onEnableClipboardChanged: () => onEnableClipboardChanged(),
        onButtonPressed: () => onButtonPressed(),
      ),
    ),
    Expanded(
      flex: 7,
      child: _rdpView(
        context: context,
        sessionId: (state is RdpSessionConnectedState) ? state.id : "",
      ),
    ),
  ],
);
