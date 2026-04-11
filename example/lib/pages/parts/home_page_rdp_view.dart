part of "../home_page.dart";

Widget _rdpView({required BuildContext context, required String sessionId}) =>
    Padding(
      padding: const EdgeInsets.only(
        left: Spaces.small,
        right: Spaces.medium,
        bottom: Spaces.medium,
      ),
      child: sessionId == ""
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).listTileTheme.tileColor,
                borderRadius: BorderRadius.circular(RRadius.medium),
              ),
              child: Center(
                child: Text(
                  "No active session",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(RRadius.medium),
              child: FrdpView(
                key: ValueKey<String>(sessionId),
                sessionId: sessionId,
              ),
            ),
    );
