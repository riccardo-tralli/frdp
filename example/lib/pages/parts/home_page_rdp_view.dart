part of "../home_page.dart";

Widget _rdpView({
  required BuildContext context,
  required RdpSessionState state,
}) => Padding(
  padding: const EdgeInsets.only(
    left: Spaces.small,
    right: Spaces.medium,
    bottom: Spaces.medium,
  ),
  child: state is RdpSessionConnectedState
      ? ClipRRect(
          borderRadius: BorderRadius.circular(RRadius.medium),
          child: FrdpView(key: ValueKey<String>(state.id), sessionId: state.id),
        )
      : Container(
          decoration: BoxDecoration(
            color: Theme.of(context).listTileTheme.tileColor,
            borderRadius: BorderRadius.circular(RRadius.medium),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Spaces.medium,
            children: [
              Text(
                "No active session",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (state is RdpSessionErrorState)
                Container(
                  padding: const EdgeInsets.all(Spaces.small),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(RRadius.medium),
                  ),
                  child: Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
);
