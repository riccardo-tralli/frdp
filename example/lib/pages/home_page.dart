import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:frdp/frdp.dart";
import "package:frdp_example/blocs/rdp_session_bloc.dart";
import "package:frdp_example/const/rradius.dart";
import "package:frdp_example/const/spaces.dart";
import "package:frdp_example/widgets/icon_chip.dart";
import "package:hugeicons/hugeicons.dart";

part "parts/home_page_appbar.dart";
part "parts/home_page_body.dart";
part "parts/home_page_side_menu.dart";
part "parts/home_page_rdp_view.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: "3389",
  );
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();

  bool _ignoreCertificate = true;
  FrdpPerformanceProfile _performanceProfile = FrdpPerformanceProfile.medium;
  final FrdpCustomPerformanceProfile _customPerformanceProfile =
      FrdpCustomPerformanceProfile(
        desktopWidth: 1380,
        desktopHeight: 855,
        connectionType: FrdpConnectionType.lan,
        allowFontSmoothing: true,
        disableWallpaper: false,
        gfxH264: true,
      );

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RdpSessionBloc, RdpSessionState>(
        builder: (context, state) => Scaffold(
          appBar: _homePageAppBar(),
          body: _homePageBody(
            context: context,
            state: state,
            hostController: _hostController,
            portController: _portController,
            usernameController: _usernameController,
            passwordController: _passwordController,
            domainController: _domainController,
            ignoreCertificate: _ignoreCertificate,
            onIgnoreCertificateChanged: () =>
                setState(() => _ignoreCertificate = !_ignoreCertificate),
            performanceProfile: _performanceProfile,
            onPerformanceProfileChanged: (value) =>
                setState(() => _performanceProfile = value),
            onButtonPressed: () {
              if (state is RdpSessionConnectedState) {
                context.read<RdpSessionBloc>().disconnect();
              } else {
                context.read<RdpSessionBloc>().connect(
                  host: _hostController.text,
                  port: int.tryParse(_portController.text) ?? 3389,
                  username: _usernameController.text,
                  password: _passwordController.text,
                  domain: _domainController.text.isNotEmpty
                      ? _domainController.text
                      : null,
                  ignoreCertificate: _ignoreCertificate,
                  performanceProfile: _performanceProfile,
                  customPerformanceProfile: _customPerformanceProfile,
                );
              }
            },
          ),
        ),
      );
}
