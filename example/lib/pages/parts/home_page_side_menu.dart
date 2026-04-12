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
  required bool enableClipboard,
  required Function() onEnableClipboardChanged,
  required Function() onButtonPressed,
}) => Padding(
  padding: const EdgeInsets.only(left: Spaces.medium, right: Spaces.small),
  child: ListView(
    children: [
      _badge(state),
      SizedBox(height: Spaces.extraLarge),
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
        enableClipboard,
        onEnableClipboardChanged,
        state,
      ),
      SizedBox(height: Spaces.extraLarge),
      _button(onButtonPressed, state),
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
      label: "Error",
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
  bool enableClipboard,
  Function() onEnableClipboardChanged,
  RdpSessionState state,
) => FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(
    spacing: Spaces.medium,
    children: [
      TextFormField(
        enabled: state is! RdpSessionConnectedState,
        controller: hostController,
        decoration: const InputDecoration(
          icon: Text("Host"),
          hintText: "192.168.1.1",
        ),
        autofocus: true,
      ),
      TextFormField(
        enabled: state is! RdpSessionConnectedState,
        controller: portController,
        decoration: const InputDecoration(icon: Text("Port"), hintText: "3389"),
        keyboardType: TextInputType.number,
      ),
      TextFormField(
        enabled: state is! RdpSessionConnectedState,
        controller: usernameController,
        decoration: const InputDecoration(
          icon: Text("Username"),
          hintText: "riccardo.tralli",
        ),
      ),
      TextFormField(
        enabled: state is! RdpSessionConnectedState,
        controller: passwordController,
        decoration: const InputDecoration(
          icon: Text("Password"),
          hintText: "mysecretpassword",
        ),
        obscureText: true,
      ),
      TextFormField(
        enabled: state is! RdpSessionConnectedState,
        controller: domainController,
        decoration: const InputDecoration(
          icon: Text("Domain"),
          hintText: "mydomain",
        ),
      ),
      Divider(),
      SwitchListTile(
        value: ignoreCertificate,
        onChanged: state is! RdpSessionConnectedState
            ? (_) => onIgnoreCertificateChanged()
            : null,
        title: const Text("Ignore SSL validation"),
      ),
      DropdownButtonFormField<FrdpPerformanceProfile>(
        initialValue: performanceProfile,
        decoration: const InputDecoration(icon: Text("Performance Profile")),
        items: const [
          DropdownMenuItem(
            value: FrdpPerformanceProfile.low,
            child: Text("Low"),
          ),
          DropdownMenuItem(
            value: FrdpPerformanceProfile.medium,
            child: Text("Medium"),
          ),
          DropdownMenuItem(
            value: FrdpPerformanceProfile.high,
            child: Text("High"),
          ),
          DropdownMenuItem(
            value: FrdpPerformanceProfile.custom,
            child: Text("Custom"),
          ),
        ],
        onChanged: state is! RdpSessionConnectedState
            ? (value) => onPerformanceProfileChanged(value!)
            : null,
      ),
      SwitchListTile(
        value: enableClipboard,
        onChanged: state is! RdpSessionConnectedState
            ? (_) => onEnableClipboardChanged()
            : null,
        title: const Text("Enable Clipboard"),
      ),
      Divider(),
      Row(
        spacing: Spaces.medium,
        children: [
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              icon: Icon(Icons.copy),
              label: Text("Send data to remote clipboard"),
              onPressed: state is RdpSessionConnectedState && enableClipboard
                  ? () => FrdpClipboard.sendToRemote(
                      sessionId: state.id,
                      text: "Hello from Flutter!",
                    )
                  : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              icon: Icon(Icons.keyboard),
              label: Text("Ctrl+Alt+Del"),
              onPressed: state is RdpSessionConnectedState
                  ? () {
                      Frdp().sendKeyEvent(
                        sessionId: state.id,
                        keyCode: PhysicalKeyboardKey.controlLeft.usbHidUsage,
                        isDown: true,
                      );
                      Frdp().sendKeyEvent(
                        sessionId: state.id,
                        keyCode: PhysicalKeyboardKey.altLeft.usbHidUsage,
                        isDown: true,
                      );
                      Frdp().sendKeyEvent(
                        sessionId: state.id,
                        keyCode: PhysicalKeyboardKey.delete.usbHidUsage,
                        isDown: true,
                      );
                      Frdp().sendKeyEvent(
                        sessionId: state.id,
                        keyCode: PhysicalKeyboardKey.controlLeft.usbHidUsage,
                        isDown: false,
                      );
                      Frdp().sendKeyEvent(
                        sessionId: state.id,
                        keyCode: PhysicalKeyboardKey.altLeft.usbHidUsage,
                        isDown: false,
                      );
                      Frdp().sendKeyEvent(
                        sessionId: state.id,
                        keyCode: PhysicalKeyboardKey.delete.usbHidUsage,
                        isDown: false,
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    ],
  ),
);

Widget _button(Function() onButtonPressed, RdpSessionState state) => SizedBox(
  width: double.infinity,
  child: FilledButton(
    onPressed: () => onButtonPressed(),
    child: Text(state is RdpSessionConnectedState ? "Disconnect" : "Connect"),
  ),
);
