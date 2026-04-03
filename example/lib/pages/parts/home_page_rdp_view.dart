part of "../home_page.dart";

Widget _rdpView({required String sessionId}) => Padding(
  padding: const EdgeInsets.only(
    left: Spaces.small,
    right: Spaces.medium,
    bottom: Spaces.medium,
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(RRadius.medium),
    child: FrdpView(key: ValueKey<String>(sessionId), sessionId: sessionId),
  ),
);
