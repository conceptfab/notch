# Privacy Policy

**Last updated:** 2026-05-22

NotchShelf is a macOS utility that displays a shelf attached to the system
notch for quickly accessing files you drag into it.

## What NotchShelf accesses

- **User-selected files.** Files you drop on the shelf are accessed through
  macOS security-scoped bookmarks. NotchShelf reads only the file URLs you
  explicitly add. Bookmarks are stored locally in the app's sandbox.
- **System notification events (best effort).** NotchShelf observes the local
  notification window appearing on screen to play an optional glow animation.
  No notification content is read, transmitted, or persisted.

## What NotchShelf does NOT do

- **No network access.** NotchShelf does not include any network entitlement
  and makes no HTTP/DNS calls.
- **No analytics or telemetry.** Nothing is reported back to the developer.
- **No third-party SDKs.** The app links only against Apple platform frameworks.
- **No advertising identifiers.**

## Where data lives

- Shelf items, preferences, and security-scoped bookmarks are stored locally
  in `~/Library/Containers/dev.conceptfab.notchshelf/Data/` under the macOS
  App Sandbox. Deleting this container removes stored data and preferences.

## Contact

Questions or concerns: please open an issue on the project repository.
