<claude-mem-context>
# Memory Context

# [notch] recent context, 2026-05-16 2:31pm GMT+2

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (17,042t read) | 554,851t work | 97% savings

### May 15, 2026
S1506 Fix stack file list panel being half-obscured by the notch application window (May 15 at 9:56 PM)
S1507 Fix stack file list panel positioning — panel top edge was hidden under notch chrome (May 15 at 10:13 PM)
S1508 Restore blue dashed border frame to ShelfView; investigate sharp corners on frame bottom edge (May 15 at 10:34 PM)
S1509 Disable default macOS focus ring on ShelfView panel while maintaining keyboard functionality (May 15 at 10:39 PM)
S1510 Restore status icons (tray icon + file count badge) visible on the collapsed shelf notch (May 15 at 10:41 PM)
3802 11:24p 🔄 PreferencesView Adopts Modern Tab API with macOS 15+ / Legacy Fallback
### May 16, 2026
3803 1:23p 🔴 Status Icons Restored When Shelf Is Closed
3804 1:24p 🔵 CollapsedIndicators Architecture in ContentView
3805 " 🔵 ShelfRevealContent Uses Mask+Offset Animation to Stay Always Mounted
3806 1:25p 🔴 Collapsed Indicators Fixed With Explicit Width Frame
3807 " ✅ Fix Committed: Collapsed Status Icons Frame Constraint
S1511 Restore status icons (tray icon + file count badge) visible on collapsed shelf notch — fully fixed and committed (May 16 at 1:25 PM)
3808 1:28p 🔄 Collapsed Indicators Moved to Shape Overlay for Natural Width Inheritance
3809 " ✅ Overlay Approach Committed and App Relaunched for Verification
S1512 Restore status icons (tray icon + file count badge) visible on collapsed shelf notch — completed with 3 iterative commits (May 16 at 1:28 PM)
3810 1:29p 🔄 Removed Redundant zIndex From Shape With Collapsed Indicators Overlay
S1513 Restore status icons (tray icon + file count badge) on collapsed shelf notch — 4-commit iterative fix completed (May 16 at 1:29 PM)
3811 1:31p 🔴 NotchShelfShape Given Explicit Frame to Guarantee Overlay Width Matches Collapsed Size
3812 " ✅ Explicit Shape Frame Committed as Fourth Fix Iteration
S1514 Restore status icons on collapsed shelf notch — now in active visual debugging phase with red background overlay (May 16 at 1:32 PM)
3813 1:33p 🔵 Temporary Debug Overlay Added to Verify Collapsed Indicators Positioning
3814 1:34p 🔵 Debug: Switched From Conditional Rendering to Always-Mounted With Opacity Toggle
S1515 Restore status icons on collapsed shelf notch — active visual debugging, root cause still unconfirmed (May 16 at 1:34 PM)
3815 1:35p 🔵 Confirmed: collapsedIndicators No Longer Gated on hasItems in Current Debug Build
3816 " 🔴 Debug Changes Reverted — ContentView.swift Reset to Last Committed State
3817 1:38p 🔵 CollapsedIndicators Layout Architecture in NotchShelf ContentView
3818 " 🔵 ShelfRevealContent Uses Offset+Mask Animation to Stay Always Mounted
3819 1:39p 🔵 Root Cause: ShelfRevealContent Wide Frame Drives ZStack Width, Breaking CollapsedIndicators
3820 " 🔵 NotchShelf Build Infrastructure: xcodegen + xcodebuild, macOS 14+ Target, Swift 6.0
3821 " 🔵 SF Symbols Confirmed Available: tray.full, tray.full.fill, archivebox.fill
3822 1:40p 🔴 Collapsed Status Icons Fixed: Extracted to CollapsedShelfStatusView with Explicit Width
3823 " 🔵 Test Run Fails in Sandbox Due to testmanagerd Restriction, Not Compilation Error
3824 1:41p 🔴 Fixed collapsed notch shelf status icon layout and width mismatch
3825 " 🔵 xcodebuild tests fail in Codex sandbox due to testmanagerd connection restriction
3826 " 🔴 All 87 Tests Pass After CollapsedShelfStatusView Fix
3827 " 🟣 NotchShelf Deployed with Fixed Collapsed Status Icons
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

Access 555k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>