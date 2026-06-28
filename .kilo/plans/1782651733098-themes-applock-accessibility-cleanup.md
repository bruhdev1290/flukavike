# Plan: Warnings + README cleanup, themes, app lock, accessibility

## Context
Flukavike is a SwiftUI iOS client for Fluxer. Voice/mute/sync issues are now fixed, so the README "what doesn't work" block and a couple of build warnings should be tidied. Additionally: add sensible accessibility, a biometric + PIN app-data lock, and new UI themes (Sandstone + others). A confirmed bug: once a color theme is selected, the user cannot switch from OLED Dark to Light/Dark/System.

Root cause of theme bug (confirmed in code):
- `ThemeManager.colorScheme` returns `.dark` for **both** `.dark` and `.oled`, `.light` for `.light`, `nil` for `.system`.
- `FluxerApp.body` applies `.preferredColorScheme(themeManager.colorScheme)` at the root `Group`.
- `ThemeManager` is `@State` + `@Observable`; mutating `currentTheme` from a child must re-evaluate the root so `.preferredColorScheme` updates. The `.dark`/`.oled` collapse and lack of distinct OLED handling are the core defects.

## Out of scope
- No backend changes. App lock is client-side only.
- No voice-message transcripts (needs backend).
- No Dynamic Type retrofitting across all hardcoded fonts (Increase Contrast only).

---

## 1. Theme bug fix + palette extension
Files: `flukavike/Stores/ThemeManager.swift`, `flukavike/Views/Settings/SettingsView.swift`

### 1a. Fix the switching bug
- Ensure `currentTheme` mutation triggers root re-evaluation. Keep `ThemeManager` `@Observable`; verify `colorScheme` (computed) reads the tracked stored `currentTheme` so SwiftUI re-evaluates `FluxerApp.body`. If SwiftUI does not re-evaluate root on the computed read, change `FluxerApp` to observe `themeManager.currentTheme` explicitly (e.g. read it in body or use `.onChange(of: themeManager.currentTheme)`).
- Give OLED distinct handling: `colorScheme` still returns `.dark` for OLED (OLED is dark-mode with pure-black backgrounds), but all `background*` methods must branch `.oled` separately (already do). Add the new themes to `colorScheme`.
- Keep `.system` → `nil` (follows device).

### 1b. Add new `AppTheme` cases
Add to enum (CaseIterable order: system, light, dark, oled, sandstone, ocean, forest, solarized):
- `.sandstone = "Sandstone"` — warm desert: light scheme, sandy beige bg, terracotta accent overrides handled via accent color (theme itself controls bg/text).
- `.ocean = "Ocean"` — deep blue dark.
- `.forest = "Forest"` — deep green dark.
- `.solarized = "Solarized"` — classic warm light palette.

Each new case needs branches in:
- `colorScheme` → sandstone/solarized return `.light`; ocean/forest return `.dark`.
- `backgroundPrimary/Secondary/Tertiary` → bespoke color triples per theme (match the spirit above).
- `textPrimary/Secondary/Tertiary` and `separator` — these currently key only on `colorScheme`; extend to branch on `currentTheme` where the new themes need non-default values (e.g. Sandstone uses dark text on light; Solarized uses specific yellow/blue text). Keep existing system/light/dark/oled behavior identical.

### 1c. Settings UI
- `AppearanceSettingsView` "Theme" `ForEach` already iterates `AppTheme.allCases` — new cases appear automatically. Verify `cs` computed helper handles new cases (add to switch).
- Update the "Preview" section to show theme background so user can preview Sandstone etc.
- No change to accent color grid.

## 2. Build warnings
### 2a. `WebSocketService.swift:536` — delegate signature mismatch
The `urlSession(_:task:didCompleteWithError:)` "nearly matches" the `URLSessionTaskDelegate` optional requirement because the param type is `URLSessionWebSocketTask` instead of `URLSessionTask`. Per compiler note, mark the method `private` to silence (it is only called internally). Verify no external caller breaks.

### 2b. `FluxerApp.swift:478` — deprecated `OpenURLOptionsKey`
`UIApplication.OpenURLOptionsKey` is deprecated in iOS 26 in favor of `UIScene` lifecycle. Migrate the deep-link `open url:options:` handler to the `UIScene`/`UIOpenURLContext` API:
- In `FluxerApp`, add a `scene(_:openURLContexts:)`-style handler (via `windowGroup` / `WindowGroup` `onOpenURL` modifier) OR keep the UIApplication-level handler but silence with `@available` is NOT acceptable — do the proper `onOpenURL { url in handleDeepLink(url: url) }` SwiftUI modifier on the root view, and remove the deprecated `application(_:open:options:)` overload.
- Ensure existing deep-link behavior (`handleDeepLink`) is preserved.

## 3. Biometric lock + PIN
New files: `flukavike/Services/BiometricLockService.swift`, `flukavike/Views/Common/AppLockView.swift`, `flukavike/Views/Settings/PinSetupView.swift`
Modify: `flukavike/FluxerApp.swift`, `flukavike/Views/Settings/SettingsView.swift`, `flukavike/Info.plist`

### 3a. `BiometricLockService` (`@Observable`, `.shared`)
State:
- `isLockEnabled: Bool` (UserDefaults `appLockEnabled`)
- `isBiometricEnabled: Bool` (UserDefaults `biometricEnabled`) — true by default if device supports
- `isLocked: Bool` — true when app should show lock
- `failedAttempts: Int` (in-memory, resets on success)
- `lockoutUntil: Date?` (UserDefaults, 30s after 5 fails)
- `biometryType: LABiometryType` via `LAContext.canEvaluatePolicy`

PIN storage (client-side only):
- Generate random salt on first PIN set; store `SHA-256(salt + pin)` hex + salt in Keychain (new key, reuse `KeychainTokenStore` pattern or add helpers).
- `setPin(_:)`, `verifyPin(_:) -> Bool`, `clearPin()`.
- No plaintext PIN stored anywhere; no UserDefaults for PIN.

Methods:
- `lock()` — set `isLocked = true` (called on launch if enabled, and on `.background`→`.inactive` scene transition).
- `unlock()` / `tryBiometric() async -> Bool` — `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)`.
- `unlockWithPin(_ pin: String) -> Bool` — verify hash; on success reset failures + `isLocked=false`; on fail increment + set `lockoutUntil` if ≥5.
- `isInLockout: Bool` computed.
- `enrollPin` flow used by `PinSetupView`.

### 3b. `AppLockView`
- Full-screen opaque overlay (uses `themeManager` background) shown above everything when `BiometricLockService.shared.isLocked`.
- On appear: if biometric enabled & not in lockout, auto-prompt biometric.
- Fallback: 4-or-6-digit PIN pad (numeric keypad) — present when biometric fails/disabled/canceled.
- Lockout state: show countdown + disabled keypad.
- Dismiss: set via `isLocked` becoming false (Binding or observed).

### 3c. `PinSetupView`
- Used from Settings when enabling App Lock (or changing PIN).
- Enter PIN → Confirm PIN → on match call `setPin`. On mismatch, re-prompt.
- Option for 4 vs 6 digit.

### 3d. Settings integration (`SettingsView.swift`)
- New "Privacy" Section with:
  - `Toggle("App Lock", isOn: $biometricLock.isLockEnabled)` — enabling presents `PinSetupView` (sheet) if no PIN set; disabling clears PIN + biometric.
  - `Toggle("Use Face ID / Touch ID", isOn: $biometricLock.isBiometricEnabled)` — only if device supports + app lock enabled.
  - "Change PIN" button → `PinSetupView` sheet.
  - Footer: explains PIN protects app data; failed attempts lock out briefly.

### 3e. `FluxerApp.swift` integration
- Inject `BiometricLockService.shared` into environment.
- On `scenePhase` change to `.background` or `.inactive`: call `lockIfNeeded()` (sets `isLocked=true` if enabled).
- On launch (`onAppear`/`initializeServices`): if enabled, `isLocked=true`.
- Overlay `AppLockView()` in the root `ZStack` (inside `WindowGroup` `Group`) gated by `biometricLock.isLocked`, `zIndex` above call overlays.

### 3f. `Info.plist`
- Add `NSFaceIDUsageDescription` string (e.g. "Face ID is used to unlock Flukavike and protect your messages.")

## 4. Accessibility: Increase Contrast
Files: `flukavike/Stores/ThemeManager.swift`, `flukavike/Views/Settings/SettingsView.swift`

- Add `var increaseContrast: Bool` to `ThemeManager` (UserDefaults `increaseContrast`, `didSet` persists). `@Observable` makes it tracked.
- In `textSecondary`, `textTertiary`, `separator` (and `backgroundPrimary/Secondary/Tertiary` where low-contrast grays are used): when `increaseContrast` is true, use higher-contrast values (e.g. dark mode `textSecondary` → `Color(white: 0.85)` instead of `0.71`; light mode → `0.32` instead of `0.42`; separators darker/lighter).
- Add toggle in Settings → Appearance (or a new Accessibility row): `Toggle("Increase Contrast", isOn: $themeManager.increaseContrast)`.
- Do not change accent colors or layouts.

## 5. README cleanup
File: `README.md`

- Replace the "## what doesn't work" block (lines ~10-19) with a clean "## Known Issues" list. Remove server profile images, gifs, @mentions (now fixed) per user. If nothing remains broken, the section can state "No known issues — report via Settings → Contact Support." Keep concise.
- Update the Theme System feature rows (Design Guidelines "Customizable" + Features table) to reflect new themes + accent colors count (e.g. "Light, Dark, OLED Dark, Sandstone, Ocean, Forest, Solarized modes with 11 accent colors").
- Update "Customization → Adding a New Theme" example if enum changed (case list).
- Leave the two "Critical" sections (Message Decoding, Channel Loading) and the "What NOT to touch" notes untouched.

## Validation
1. `xcodebuild -workspace flukavike.xcworkspace -scheme flukavike -destination 'platform=iOS Simulator,name=iPhone 17' build` → `** BUILD SUCCEEDED **` with **0 warnings** (confirm the two warnings are gone; no new warnings introduced).
2. Manual (simulator where biometrics = none → tests PIN path; device for biometric):
   - Theme: open Settings → Appearance; cycle OLED Dark → Light → Dark → System → Sandstone → Ocean → Forest → Solarized; confirm UI re-themes immediately each time (bug fixed).
   - App Lock: enable App Lock → set PIN → background app → return → lock appears → biometric or PIN unlocks. Trigger 5 wrong PINs → 30s lockout.
   - Increase Contrast: toggle on → verify text/separator contrast visibly increases in Settings + Chat.
3. Grep: confirm no remaining `OpenURLOptionsKey` and the delegate method is `private`.

## Risks / Notes
- SwiftUI `@Observable` + computed `colorScheme` at root should re-evaluate; if not, fall back to explicit `themeManager.currentTheme` read in `body` or `.onChange`. The plan's step 1a covers this.
- New theme colors must keep text/background contrast ≥ 4.5:1 (especially Sandstone/Solarized light themes) — pick values accordingly.
- Do NOT touch `Models.swift` mixed-type decoding or `AppState.gatewayGuilds` (per README critical notes).
- Do NOT change channel-loading architecture.
