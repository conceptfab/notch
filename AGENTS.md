<claude-mem-context>
# Memory Context

# [notch] recent context, 2026-05-23 10:12pm GMT+2

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (17,155t read) | 159,648t work | 89% savings

### May 16, 2026
S1514 Restore status icons on collapsed shelf notch — now in active visual debugging phase with red background overlay (May 16 at 1:32 PM)
S1515 Restore status icons on collapsed shelf notch — active visual debugging, root cause still unconfirmed (May 16 at 1:33 PM)
S1560 Create a test script that triggers system events that the NotchShelf app reacts to (notch glow) (May 16 at 1:34 PM)
S1582 Move stack and plus icons outside the main application window boundary (NotchShelf macOS app) (May 16 at 10:59 PM)
### May 17, 2026
S1617 Code audit of NotchShelf macOS SwiftUI app before merging notchshelf-mvp → stable branch (May 17 at 1:57 PM)
S1618 Fix (popraw) glow animation in NotchShelf macOS app — ContentView.swift startup glow refactor (May 17 at 8:38 PM)
S1619 NotchShelf macOS app — post-audit code improvement plan created before merging to stable branch (May 17 at 8:40 PM)
S1620 Execute plan_poprawek.md — post-audit SwiftUI/architecture refactor for NotchShelf macOS app (May 17 at 8:48 PM)
S1792 NotchShelf distribution readiness plan — prepare a 15-task implementation plan to make the app shippable as a direct-download .dmg (ad-hoc signed, no Developer ID) (May 17 at 8:51 PM)
### May 22, 2026
S1793 NotchShelf distribution readiness plan finalized — permanent pipeline designation added, awaiting execution mode choice (May 22 at 11:53 PM)
### May 23, 2026
5511 1:29p 🔵 BundleResourceTests Red Run: LICENSE.txt and buy-me-a-coffee.png Not Yet Bundled in App
5512 " 🟣 NotchShelf/Resources/ Directory Created with LICENSE.txt and buy-me-a-coffee.png
5513 " 🔵 xcodegen Auto-Discovers Resources in NotchShelf/Resources/ Without project.yml Changes
5514 1:30p 🟣 AboutViewContentTests Added to Drive Static URL and Metadata Properties on AboutPreferencesView
5515 " 🔵 AboutViewContentTests Red Run: Compile Errors Confirm 5 Static Properties Missing from AboutPreferencesView
5516 " 🟣 AboutPreferencesView Fully Rewritten with ConceptFab Branding, Static URLs, and Bundled Resource Loading
5517 1:31p 🔴 AboutViewContentTests Green; @MainActor Added to Fix Swift 6 Concurrency Warning on Static Properties
5518 " ✅ AboutViewContentTests and AboutPreferencesView Committed Clean — No Warnings
5519 " ✅ Distribution Readiness Steps 1–3 Complete: Docs, ConceptFab Identity, Resources, About View All Landed
5520 " 🟣 Shell Contract Test Suite Created for Release Scripts Pipeline
5521 1:32p 🔵 Release Scripts Contract Test Red Run: 13 Failures Confirm All 3 Scripts Missing
5522 " 🟣 Release Pipeline Scripts Implemented: release.sh, package-dmg.sh, distribute.sh
5523 1:33p 🟣 Release Scripts Contract Tests Pass: All 13 Assertions Green After Scripts Created
5524 " 🔵 Full Test Suite Passes with All Shell Contracts and Swift Tests Combined
5525 " 🔵 Release Build Produces Universal Binary Despite arm64-Only LSArchitecturePriority Setting
5526 1:34p 🔵 Release Build Contains get-task-allow Entitlement — Debug-Only Entitlement Must Be Stripped for Distribution
5527 " 🔵 get-task-allow Root Cause: CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES Injects Debug Entitlement into Release Build
5528 " 🔵 DMG Smoke Test Passed: Correct Contents — Apps Symlink, INSTALL.md, LICENSE, NotchShelf.app
5529 " 🟣 Two New Contract Assertions Added to test-release-scripts.sh to Guard get-task-allow Fix
5530 1:35p 🔴 get-task-allow Fixed: CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO Added to Release Config in project.yml and release.sh
5531 " 🔴 get-task-allow Entitlement Confirmed Absent from Release Build After CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO Fix
5532 " ✅ Final Distribution Audit Running: Full Test Suite and DMG Re-Package with Fixed Entitlements
5533 " ✅ Final Distribution Audit Complete: Full Test Suite Green and Fixed DMG Verified
5534 1:36p ✅ Distribution Pipeline Committed as b4a7930: 10 Commits Total on codex/distribution-readiness
5535 " ✅ Distribution Readiness Plan Steps 1–4 Complete; Step 5 (Audit and Finalize) Now In-Progress
5536 1:37p 🔵 v1.0.0 Tag Pre-Exists on Repo — Tagged May 15 by CONCEPTFAB Before Distribution Readiness Work
5537 " 🟣 Full scripts/distribute.sh Pipeline Completed: NotchShelf-1.0.0.dmg and SHA-256 Checksum Produced
5541 1:58p 🔵 Wrong Email Displayed in UI Window — Should Be conceptfab.com
5542 " 🔵 Root Cause Found: Info.plist Copyright Shows "Michal Kleniewski", Not conceptfab.com
5543 1:59p 🔵 Full Scope of "Michal Kleniewski" Personal Name Across NotchShelf Codebase
5544 " 🔵 NotchShelf at v1.0.1 Tag on codex/distribution-readiness Branch
5545 " 🔴 Test Compilation Failure: PreferencesPanelMetrics.windowHeight Does Not Exist
5546 " 🔴 Info.plist Branding Updated to conceptfab.com + Preferences Window Height Increased
5547 2:00p 🔴 All Tests Green: conceptfab.com Branding Verified in Built App Bundle
5548 " 🟣 NotchShelf Relaunched with conceptfab.com Branding — App Confirmed Running
5549 " 🔴 BundleResourceTests Updated to Assert conceptfab.com Brand in LICENSE.txt
5550 " 🔵 TDD RED Confirmed: BundleResourceTests Fails on LICENSE.txt Personal Name
5551 2:01p 🔴 LICENSE Files Updated: "Michal Kleniewski" Replaced with "conceptfab.com" Across All Files
5552 " ✅ Full Branding Sweep Confirmed: 9 Files Changed, "Kleniewski" Absent from All Source Files
5553 " 🔴 Full Test Suite Green: conceptfab.com Branding Complete in NotchShelf
5554 2:02p 🔴 Committed: conceptfab.com Branding Replaces Personal Name Across All NotchShelf Metadata
5555 " ✅ NotchShelf v1.0.1 Committed with ConceptFab Branding on Distribution-Readiness Branch
5556 " 🔵 NotchShelf codex/distribution-readiness Branch Commit History
5557 2:03p 🟣 NotchShelf v1.0.1 DMG Successfully Built and Verified with ConceptFab Branding
5558 " 🔵 NotchShelf 1.0.1 DMG Installs and Passes Codesign Verification
5559 " 🔵 Branding Fix Did NOT Propagate Into DMG — Personal Name Still in Installed App
5560 2:04p 🟣 NotchShelf 1.0.1 DMG Release Verified and Installed
5561 2:06p 🔴 NotchShelf About View Preferences Window Height Tightened
5562 " ✅ NotchShelf 1.0.1 DMG Built and Verified Successfully
5563 2:07p 🔵 NotchShelf 1.0.1 Release App Passes All Distribution Checks

Access 160k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>