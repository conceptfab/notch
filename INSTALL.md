# Installing NotchShelf

NotchShelf 1.0 is distributed ad-hoc signed (no Apple Developer ID yet).
macOS Gatekeeper may refuse to open it on first launch with a message such as
"NotchShelf is damaged and can't be opened" or "cannot be opened because the
developer cannot be verified." This is expected for an app downloaded from
the internet without Developer ID notarization.

## One-time setup (recommended)

1. Open the downloaded `NotchShelf-<version>.dmg`.
2. Drag **NotchShelf.app** into the `/Applications` folder shown in the
   window.
3. Eject the DMG.
4. Open **Terminal** and run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchShelf.app
   ```

5. Launch NotchShelf from Spotlight, Launchpad, or `/Applications`.

## Alternative: right-click > Open

If you prefer not to use Terminal:

1. Drag **NotchShelf.app** into `/Applications`.
2. Right-click (or Control-click) **NotchShelf.app** and choose **Open**.
3. In the dialog that appears, click **Open** again.
4. If macOS still refuses, open **System Settings > Privacy & Security**,
   scroll down to the "NotchShelf was blocked" notice, and click
   **Open Anyway**.

## Verifying the download (optional)

Each release publishes a `NotchShelf-<version>.dmg.sha256` file. From the
folder containing the DMG and checksum file, run:

```bash
shasum -a 256 -c NotchShelf-<version>.dmg.sha256
```

Expected output: `NotchShelf-<version>.dmg: OK`.

## Uninstalling

1. Quit NotchShelf.
2. Drag `/Applications/NotchShelf.app` to the Trash.
3. Optional: remove the app's local data:

   ```bash
   rm -rf ~/Library/Containers/dev.conceptfab.notchshelf
   ```

4. Optional: remove the launch-at-login agent if you used
   `scripts/install-autostart.sh`:

   ```bash
   scripts/install-autostart.sh uninstall
   ```
