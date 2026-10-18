# EMPIRE RUSH — iOS build and install guide (M2.2)

Status: **written and partly checked in a Linux container. It has not yet been followed end to end on a Mac.**
- Linux steps 1–3 were run for real: export templates, Xcode project export, build stamp (see `docs/M2_2_DEVICE_VALIDATION_REPORT.md` §2).
- Mac/Xcode steps 4–7 have not been run by anyone yet. The first person to do them should note in the report anything that differs.

## 0. What you need
| Item | Why | Notes |
|---|---|---|
| A Mac with a current macOS | Xcode only runs on macOS. Godot cannot build or sign a `.ipa` on Linux (verified: "`.ipa can only be built on macOS`") | Apple silicon or Intel |
| Xcode, new enough to support the iPhone's iOS version | Compiles, signs and installs. Also provides Instruments | Check that the iPhone's iOS version appears under Xcode → Settings → Platforms |
| Apple ID added in Xcode → Settings → Accounts | Signing | A **free personal team** can install on your own device. The profile expires after 7 days and the team limits how many apps it can sign. A paid **Apple Developer Program** membership is needed for TestFlight / external testers |
| Team ID (10 characters) | Required by Godot's iOS export: it refuses with "App Store Team ID not specified" (verified) | developer.apple.com → Membership, or Xcode → Accounts. **Never commit it**: `scripts/export_build.sh` takes it from `IOS_TEAM_ID` |
| A unique bundle ID | The committed preset uses the placeholder `com.example.empirerush` | Pass `IOS_BUNDLE_ID=com.<yourteam>.empirerush` |
| iPhone 14 Pro, USB cable, Developer Mode on | Install debug builds | iOS 16+: Settings → Privacy & Security → Developer Mode, then restart |
| Godot 4.7.2-stable editor + 4.7.2 export templates | Must match the project's pinned engine | Templates: `Godot_v4.7.2-stable_export_templates.tpz`. Verify SHA-512 against the release's `SHA512-SUMS.txt` |

Project facts that matter on iOS (checked in the repo):
- Renderer `mobile`, `rendering_device/driver.ios = metal` (engine default; MoltenVK is bundled as a fallback).
- Orientation `sensor` (portrait + landscape). The exported Info.plist lists Portrait, PortraitUpsideDown, LandscapeLeft and LandscapeRight.
- Minimum iOS version 16.0. `UIRequiredDeviceCapabilities` = A12 or newer.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are on, so the device reports in `user://` show up in the **Files** app (On My iPhone → Empire Rush).
- File logging is enabled on all platforms, so `user://logs/godot.log` is also on the device.
- The frame rate is not raised above 60 Hz: `CADisableMinimumFrameDurationOnPhone` is not set, so ProMotion stays at the iOS default for games. The target is 30 FPS, so this is intentional. Record it in results.

## 1. Install the export templates (any OS)
Editor → Manage Export Templates → Install from file, or unzip the `.tpz` so that `templates/*` ends up in:
- macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
- Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`

`ios.zip` must be there.

## 2. Export
**Option A (recommended on a Mac):** from the repo root:
```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot" \
IOS_TEAM_ID=XXXXXXXXXX IOS_BUNDLE_ID=com.yourteam.empirerush \
scripts/export_build.sh ios internal release   # device testing: has the device panel and reports
# scripts/export_build.sh ios public release   # public release: no device tools, no Files-app access
```
- The script writes `client/data/build_info.json` (commit + UTC time; git-ignored). The device panel and every report then show the exact build.
- It injects the team and bundle IDs into a temporary copy of the presets and restores the committed file afterwards.

The preset has `application/export_project_only=true`, so the output is an Xcode project in `build/ios-internal/` (or `build/ios-public/`) (`EmpireRush.xcodeproj`, `EmpireRush.pck`, frameworks). To have Godot also build the `.ipa` on a Mac, set it to `false` in a local copy. Use **release** builds for FPS numbers; debug builds include extra checks.

**Option B (Linux container, already tested):** run the same command on Linux. It produces the same Xcode project; copy `build/ios-internal/` to the Mac.

## 3. Check the export
- `build/ios-internal/EmpireRush/EmpireRush-Info.plist` contains `UIFileSharingEnabled` = true and the four orientations (the public build has it false).
- `EmpireRush.pck` contains `data/rules/*.json` and `data/presentation/*.json` and no `tests/`. A unit test guards this (`test_device_validation.gd`).

### Phase 3 re-check (2026-10-18, commit `c973a60`, Linux container)

Command used, with a clearly fake Team ID that never leaves the temp copy: `IOS_TEAM_ID=ABCDE12345 scripts/export_build.sh ios internal|public release` in a throw-away worktree. It produced Xcode projects for both flavours.

| Check | Internal Test | Public Release |
|---|---|---|
| `UISupportedInterfaceOrientations` | Portrait, PortraitUpsideDown, LandscapeLeft, LandscapeRight | same |
| `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` | true / true (reports reachable in Files) | false / false |
| `UIRequiredDeviceCapabilities` | A12 minimum | same |
| Xcode settings | `IPHONEOS_DEPLOYMENT_TARGET = 16.0`, `TARGETED_DEVICE_FAMILY = 1` (iPhone), `PRODUCT_BUNDLE_IDENTIFIER = com.example.empirerush` (placeholder), `PROVISIONING_PROFILE = ""` | same |
| `PrivacyInfo.xcprivacy` | present. `NSPrivacyTracking = false`; declares the file-timestamp, boot-time and disk-space API categories that Godot uses | same |
| `EmpireRush.pck` | `data/rules/*.json` included; no `res://tests/` or `res://tools/` (the network test server/client are not shipped) | same |
| Repository after export | `export_presets.cfg` restored: no Team ID left (also checked in CI by `scripts/ci/check_repo_readiness.py`) | |

**Still not done:**
- signing;
- building the `.ipa`;
- installing on a device.

Steps 4–7 need a Mac, Xcode, an Apple account and the iPhone.

**Owner inputs needed:**
- the real Team ID (passed as an environment variable, never committed);
- the final bundle ID;
- the app icon (`GEN-002` is a placeholder).

## 4. Sign and run in Xcode (Mac — not yet done)
1. Open `build/ios-internal/EmpireRush.xcodeproj`.
2. Target **EmpireRush** → Signing & Capabilities: tick *Automatically manage signing* and select the team. Fix the bundle ID if Xcode reports it is taken.
3. Select the connected iPhone 14 Pro as the run destination. Product → Run (⌘R).
4. On first install, trust the developer certificate on the phone (Settings → General → VPN & Device Management), then open the app.

## 5. Measure (Mac + device)
**In-app (no Mac needed after install):**
- **Internal Test builds only** (or any debug build; see `BuildFlavor`). In a Public Release build the panel, the reports and the telemetry files do not exist.
- Hold the **Đồ họa** button for about one second, then release. The device panel opens.
- *HIỆN SỐ ĐO* shows live FPS, p50/p95/p99 frame time, the share of frames over 33 ms, draw calls and memory.
- *ĐO TỰ ĐỘNG* plays the match itself (HUD autopilot) and records 60 s each of Thấp / Vừa / Cao. The first 1.5 s of each step is ignored as warm-up.
- Reports: Files → On My iPhone → Empire Rush → `device_validation/run_<time>.json`. Match telemetry goes to `telemetry/`, the engine log to `logs/`.

**Xcode / Instruments (cross-check, required for memory and thermals):**
- Debug navigator gauges (CPU, Memory, Energy, FPS) during a debug run.
- Product → Profile:
  - *Time Profiler* for CPU hot spots;
  - *Metal System Trace* (or the *Game Performance* template) for GPU frame time and frame pacing;
  - *Allocations* / *VM Tracker* for memory growth across "play again".
- The process memory footprint from Xcode is the number that matters for iOS termination. The in-app "RAM" number is only Godot's static allocator.
- Optional: the iOS Metal Performance HUD (Settings → Developer → Graphics HUD on recent iOS versions) for an independent FPS / GPU-time readout.
- Thermal: record the room temperature and how warm the phone feels, and repeat the benchmark after 15 and 30 minutes of play. Instruments' *Thermal State* track shows nominal / fair / serious / critical.

## 6. Crashes
- On the next launch, the device panel says *"Lần chạy trước kết thúc bất thường"* when the app died while in the foreground. This is a marker-file heuristic.
- Real crash logs: Xcode → Window → Devices and Simulators → View Device Logs, or on the phone Settings → Privacy & Security → Analytics & Improvements → Analytics Data (`EmpireRush-*.ips`). Attach them to the report.

## 7. Distributing to playtesters
TestFlight needs the paid Developer Program, an App Store Connect app record and a release build archived in Xcode (Product → Archive). Out of scope for M2.2; listed as a next step.
