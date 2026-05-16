<claude-mem-context>
# Memory Context

# [notch] recent context, 2026-05-16 11:44pm GMT+2

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (18,344t read) | 559,202t work | 97% savings

### May 15, 2026
S1507 Fix stack file list panel positioning — panel top edge was hidden under notch chrome (May 15 at 10:13 PM)
S1508 Restore blue dashed border frame to ShelfView; investigate sharp corners on frame bottom edge (May 15 at 10:34 PM)
S1509 Disable default macOS focus ring on ShelfView panel while maintaining keyboard functionality (May 15 at 10:39 PM)
S1510 Restore status icons (tray icon + file count badge) visible on the collapsed shelf notch (May 15 at 10:41 PM)
### May 16, 2026
S1511 Restore status icons (tray icon + file count badge) visible on collapsed shelf notch — fully fixed and committed (May 16 at 1:25 PM)
S1512 Restore status icons (tray icon + file count badge) visible on collapsed shelf notch — completed with 3 iterative commits (May 16 at 1:28 PM)
S1513 Restore status icons (tray icon + file count badge) on collapsed shelf notch — 4-commit iterative fix completed (May 16 at 1:29 PM)
S1514 Restore status icons on collapsed shelf notch — now in active visual debugging phase with red background overlay (May 16 at 1:32 PM)
S1515 Restore status icons on collapsed shelf notch — active visual debugging, root cause still unconfirmed (May 16 at 1:33 PM)
3827 1:41p 🟣 NotchShelf Deployed with Fixed Collapsed Status Icons
3828 1:42p 🔴 NotchShelf Running with Collapsed Status Icon Fix Confirmed Live at PID 5690
3829 1:43p 🔄 CollapsedShelfStatusView Redesigned to Float Over Full Window Width
3832 1:44p 🔴 Second CollapsedShelfStatusView Iteration Compiles and Links Successfully
3830 " 🔴 CollapsedShelfStatusView Icons Invisible Due to clipShape Masking
3831 " 🔄 CollapsedShelfStatusView Signature Changed to Window-Relative Layout
3833 1:47p 🔵 Root cause of extra empty shelf row after clearAll identified
3834 " 🔴 SlotCountPolicy now normalizes unaligned currentVisible before shrink/grow logic
3835 1:50p 🔴 SlotCountPolicy row-shrink fix verified with 88 passing tests
3836 1:54p 🔄 MinSlotCount hardcoded to 4 via ShelfMetrics constant
3837 " ⚖️ Legacy minSlotCount UserDefaults key preserved for disk-stability
3844 2:07p 🟣 NotchShelf Full Test Suite Passes — 88 Tests Green
3845 " 🟣 SlotCountPolicy: Dynamic Width Scaling with Minimum-4 Semantics
3855 2:21p 🟣 Slot icons switched from QuickLook thumbnails to NSWorkspace real icons
3856 " ⚖️ Notch app collapsed UI width formula: notchWidth + 2× notchHeight
3863 2:27p 🟣 NotchShelf shelf slots refactored to row-based layout model
3864 " 🔵 NotchShelf startup glow mechanism – reuse potential for system event signaling
3866 " 🟣 Added "glowOnSystemEvents" preference key and UI toggle
3867 " 🟣 ShelfWindowModel gains glowPulse counter and requestGlow() for event-driven glow signaling
3868 2:28p 🔄 ContentView glow logic extracted to reusable playGlow() with task cancellation
3870 " 🟣 AppDelegate wires system event observers for notch glow on wake/screen change/session activation
3871 " 🟣 Tests added for glowOnSystemEvents preference key and glowPulse model behavior
3872 " 🔵 Pre-existing Swift 6 actor isolation warning in StackFileListPanel.swift
3874 " 🟣 System-event notch glow feature fully implemented and all 89 tests pass
3875 2:29p 🔵 System-event glow feature staged but not yet committed; slot refactor was already committed
3876 2:32p 🟣 Flash-on-system-events toggle added to NotchShelf
4015 10:57p 🔵 NotchShelf System Event Glow Architecture Mapped
4016 10:58p 🔵 swift -e Cannot Post DistributedNotification Due to Module Cache Permission Error
4017 " 🔵 swift -e Works With -module-cache-path /tmp Flag to Post DistributedNotifications
4018 " 🟣 scripts/trigger-system-event.sh Created for Manual Notch Glow Testing
4019 " 🟣 trigger-system-event.sh Verified Working — Runs in ~0.74s
S1560 Create a test script that triggers system events that the NotchShelf app reacts to (notch glow) (May 16 at 10:59 PM)
4020 11:00p 🔵 pgrep Unavailable in Agent Sandbox — sysmond Service Not Found
4021 11:01p 🟣 trigger-system-event.sh Gains Real Notification Mode via osascript
4022 " 🔵 defaults write Fails for Sandboxed NotchShelf App Container
4023 " 🔵 trigger-system-event.sh Works End-to-End With Escalated Permissions
4024 " 🟣 Added `scripts/trigger-system-event.sh` for NotchShelf system event testing
4025 " 🔵 NotchShelf sandboxed container blocks `defaults write` from outside the app
4026 " 🔵 zsh "log" Built-in Shadows /usr/bin/log in Agent Shell
4027 " 🔵 /usr/bin/log Cannot Run While Sandboxed — No In-Agent Log Verification Possible
4028 11:02p 🔵 No "System glow requested" Log Entries Found — NotchShelf Not Running During Test
4029 " 🔵 SystemNotificationWindowMonitor Detects Any Top-Right Banner by Geometry Alone
4030 11:03p 🔵 NotchShelf Running (PID 8763) and Complete Glow Signal Chain Mapped
4031 " 🔵 End-to-End Verified: trigger-system-event.sh Triggers NotchShelf Glow
4032 " 🔵 "notification" Mode Confirmed: SystemNotificationWindowMonitor Detects osascript Banner and Fires Glow
4033 11:04p 🔵 NSUserNotification Produces No Visible CGWindowList Banner on macOS 14 — and Polish Locale May Break Owner Name Matching
4034 " 🔵 Glow Animation Timing Fully Mapped: 18ms In, 650ms Hold, 550ms Out
4035 " 🔴 SystemNotificationWindowMonitor Extended With Polish Locale "Centrum powiadomień" Owner Name
4036 11:05p 🔴 Fixed Polish-locale notification detection in SystemNotificationWindowMonitor
4037 " 🔵 CGWindowList probe confirms Polish locale for macOS system processes
4038 11:06p 🔵 xcodebuild Tests Require Escalated Permissions — Sandbox Blocks testmanagerd Connection

Access 559k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>