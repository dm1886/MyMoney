# Android parity ledger

Branch: `Android-verison` (Git does not permit spaces). iOS baseline: `840bf03`.

This is a native Android port in progress, not a completed equivalent of iOS.

| Area | Android state | Remaining parity work |
|---|---|---|
| Orb presentation | Sora and the exact five iOS light/dark palette values; five-section navigation; two solid orb shapes | Match original account cards, all screen layouts, motion, six balance styles, custom theme editor, accessibility and tablet layouts |
| Accounts | Create/edit six account types; separate currency totals | Images/icons, credit-limit editing, deletion workflows, historical valuation |
| Transactions | Create/edit/delete income, expense, transfer, adjustment, liability payment; pending status | Full multicurrency UI, interest handling, scheduled execution and edit/delete series |
| Financial engine | BigDecimal amounts, historical account/destination amounts, pending exclusion, net credit calculation | Shared fixture comparison against iOS for all remaining calculation paths |
| Categories | Defaults and creation | Groups, icons, edit/delete, frequent categories/default accounts |
| Budgets | Monthly category limits and spent amount | All periods, currency conversion, notification thresholds and detailed charts |
| Reports | Monthly income/expense and category proportions | All original reports, filters and nine chart types |
| Home widgets | Initial summary and account/activity cards | Original fifteen configurable/reorderable widgets |
| Recurrences | Pure next-occurrence date rule | Persistence, scheduler, missed executions, notifications, working-day adjustment |
| Investments | Not ported | Ledger, trades, cash flows, projection, market service and all forms |
| Persistence | Atomic private JSON file per Firebase UID; preserves unreadable files; exact decimal strings | iOS-compatible backup import/export, migration, large-library performance |
| Authentication | Android email/password, verification, reset and account state in Settings; iOS optional Account MyMoney section with registration/login, verification, refresh and sign-out | Physical-device/cloud signup verification, account deletion, privacy/terms links and explicit existing-library migration |
| Family sharing | Firestore access rules and authorization tests | Trusted invite/member lifecycle, explicit sharing UI, sync/offline conflicts, revocation on cached devices |
| AI import | Not implemented | Deferred while Android foundation is established |

## Verification

Run from the repository root:

```sh
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' android/gradlew -p android :app:assembleDebug :app:testDebugUnitTest
cd firebase
npm ci
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' npm run test:rules
```

The debug Android build uses only `demo-mymoney` via local Auth/Firestore emulators at 10.0.2.2. Production configuration is not included. Financial data is not synchronized by the current Android build.

A passing build is not a certification of complete parity. Android release signing, Play publication, live cloud signup, iOS onboarding, shared expenses and physical-device behavior remain separate gates.

## Initial verification evidence (2026-10-26)

- Android Debug APK built; 20 tests passed (16 financial rules, 3 persistence/schema cases, 1 Compose account/expense flow). Lint completed with no errors; dependency/KTX suggestions remain warnings.
- Compose form flow creates a 1,000.25 EUR account, records a 12.35 EUR expense and verifies a persisted 987.90 EUR balance. The form was changed to expand and scroll correctly; semantic UI actions are used for save controls in the Robolectric test.
- Emulator manual check reached email signup, email verification through Auth Emulator, private Firestore profile creation and Home. This is not a live-production signup test.
- Nine Firestore Rules tests passed, including cross-user isolation, unverified access, membership elevation, forged authorship, viewer restrictions and revoked membership.
- The existing 31 iOS tests passed on iPhone 17 Pro simulator. iOS source has not been changed by the Android foundation.
- Exact palette strings are ported from `ThemePresets.swift`; matching every rendered iOS screen has not been verified. No claim of pixel-perfect parity is made.

## Adaptive visual alignment (2026-10-26)

- Android typography now maps all Material text roles to Sora and the iOS Orb base sizes: display 38, title 26, title2 22, title3 19, headline 16, body 14, subheadline 13, footnote 12, caption 11 and caption2 10 sp. System font scaling remains enabled.
- Capsule B now has a selected inline label, separate 60 dp secondary add button, 60 dp capsule height, 20 dp section icons and a centered maximum width matching the iOS baseline. Compact width/large text switches to accessible icon-only sections.
- Shared card radius/padding now follow iOS (20/14 dp); screen gutters follow 16 dp, with centered bounded content on tablets.
- The stationary orb uses the same 120-segment shape equation and secondary blending as the iOS component. Full motion parity remains pending.
- Layout tests cover navigation at widths 320, 390 and 768 dp with font scales 1, 1.4 and 2, checking visible controls and non-overlapping bounds; a compact large-text form test preserves a large decimal amount. These are layout checks, not a completed screenshot comparison of every screen.

## iOS Settings account trial (2026-10-26)

Settings → Account MyMoney now offers optional email/password signup and login, shows registered/verified status, resends verification email, refreshes status, resets passwords and signs out. Existing installations are not gated by login. Auth uses Firebase Apple SDK 12.14.0 with a locally downloaded, git-ignored GoogleService-Info.plist for `dm1886-mymoney`. No financial records are sent to Firebase, rebound to a UID, deleted or migrated. Existing CloudKit behavior is preserved. Family sharing is shown as inactive; no pretend activation switch is provided. Android Settings also exposes account identity and verification state.

All 33 iOS tests passed, including the synthetic Auth Emulator lifecycle (create, verify, refresh, restore session, sign out and sign in) and safe error messages. Android build, 22 tests and lint passed. A live user signing up from their own iPhone remains to be tried.
