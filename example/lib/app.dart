import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:frdp_example/blocs/rdp_session_bloc.dart";
import "package:frdp_example/misc/themes/light.dart";
import "package:frdp_example/pages/home_page.dart";

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<RdpSessionBloc>(
    create: (context) => RdpSessionBloc(),
    child: MaterialApp(
      title: "frdp: Flutter Remote Desktop Protocol",
      theme: Light.make,
      home: const HomePage(),
    ),
  );
}
