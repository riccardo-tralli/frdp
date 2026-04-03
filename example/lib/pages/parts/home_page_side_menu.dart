part of "../home_page.dart";

Widget _sideMenu({
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
  required Function() onButtonPressed,
}) => Padding(
  padding: const EdgeInsets.only(left: Spaces.medium, right: Spaces.small),
  child: Column(
    spacing: Spaces.medium,
    children: [
      _badge(state),
      _form(
        hostController,
        portController,
        usernameController,
        passwordController,
        domainController,
        ignoreCertificate,
        onIgnoreCertificateChanged,
        performanceProfile,
        onPerformanceProfileChanged,
        onButtonPressed,
        state,
      ),
    ],
  ),
);

Widget _badge(RdpSessionState state) {
  if (state is RdpSessionConnectedState) {
    return IconChip(
      label: "Connected",
      icon: HugeIcons.strokeRoundedToggleOn,
      type: IconChipType.success,
    );
  }
  if (state is RdpSessionConnectingState) {
    return IconChip(
      label: "Connecting",
      icon: HugeIcons.strokeRoundedToggleOn,
      type: IconChipType.info,
    );
  }
  if (state is RdpSessionErrorState) {
    return IconChip(
      label: "Error: ${state.message}",
      icon: HugeIcons.strokeRoundedToggleOff,
      type: IconChipType.error,
    );
  }
  return IconChip(
    label: "Disconnected",
    icon: HugeIcons.strokeRoundedToggleOff,
    type: IconChipType.warning,
  );
}

Widget _form(
  TextEditingController hostController,
  TextEditingController portController,
  TextEditingController usernameController,
  TextEditingController passwordController,
  TextEditingController domainController,
  bool ignoreCertificate,
  Function() onIgnoreCertificateChanged,
  FrdpPerformanceProfile performanceProfile,
  Function(FrdpPerformanceProfile) onPerformanceProfileChanged,
  Function() onButtonPressed,
  RdpSessionState state,
) => Column(
  children: [
    TextFormField(
      controller: hostController,
      decoration: const InputDecoration(labelText: "Host/IP"),
    ),
    TextFormField(
      controller: portController,
      decoration: const InputDecoration(labelText: "Port"),
      keyboardType: TextInputType.number,
    ),
    TextFormField(
      controller: usernameController,
      decoration: const InputDecoration(labelText: "Username"),
    ),
    TextFormField(
      controller: passwordController,
      decoration: const InputDecoration(labelText: "Password"),
      obscureText: true,
    ),
    TextFormField(
      controller: domainController,
      decoration: const InputDecoration(labelText: "Domain (optional)"),
    ),
    CheckboxListTile(
      value: ignoreCertificate,
      onChanged: (_) => onIgnoreCertificateChanged(),
      title: const Text("Ignore SSL certificate validation"),
      // controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    ),
    DropdownButtonFormField<FrdpPerformanceProfile>(
      initialValue: performanceProfile,
      decoration: const InputDecoration(labelText: "Performance Profile"),
      items: const [
        DropdownMenuItem(
          value: FrdpPerformanceProfile.low,
          child: Text("Low (more fluid)"),
        ),
        DropdownMenuItem(
          value: FrdpPerformanceProfile.medium,
          child: Text("Medium"),
        ),
        DropdownMenuItem(
          value: FrdpPerformanceProfile.high,
          child: Text("High (more detailed)"),
        ),
      ],
      onChanged: (value) => onPerformanceProfileChanged(value!),
    ),
    ElevatedButton(
      onPressed: () => onButtonPressed(),
      child: Text(state is RdpSessionConnectedState ? "Disconnect" : "Connect"),
    ),
  ],
);
