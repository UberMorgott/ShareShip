# Changelog

All notable changes to ShareShip are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-05-04 — Format fix for 2026-04-30 engine update

### Fixed
- **Mod broken after Windrose engine update (2026-04-30).** The update tightened AsyncLoading2's export validation (`TemplateObject->IsA(LoadClass)`) which rejected the patched import redirect in Zen (IoStore) format. The export was skipped entirely, breaking both owner and non-owner ship management access. Repackaged as legacy V8B `.pak` which uses a different linker that resolves the redirect cleanly.

### Changed
- **Format switched from IoStore triple to single legacy V8B `.pak`.** Install now requires only one file (`ShareShip_P.pak`, ~5.3 KB) instead of three (`.pak` + `.ucas` + `.utoc`). Users upgrading from v1.1.x must delete the old `.ucas` and `.utoc` files.
- Both patch mechanisms (v1.0 import redirect + v1.1 helm Options null-patch) are preserved unchanged in the legacy format. No gameplay or UX changes.

### Tested
- Client log verification (2026-05-04): pak mounts cleanly, zero `CreateExport` errors, zero `template object type` warnings.
- Listen-server smoke test: owner and non-owner ship management works as expected.

## [1.1.1] - 2026-04-27 — Strip UE4SS leftovers from the release archive

### Fixed
- **Game freezes on the loading screen with a `R5JsonAssets` crash.** v1.1.0 (and v0.1.0) shipped three legacy UE4SS files alongside the IoStore triple — `mod.json`, `enabled.txt`, and `Scripts/main.lua` — kept "for archival" inside the release zip. They were never used by the IoStore pak loader, but Windrose's own `R5JsonAssets` plugin auto-scans every `*.json` it finds inside mounted `~mods` directories and tries to construct a `UObject` from each one. The UE4SS-style `mod.json` lacks the engine's expected `Class` field, so the plugin asserts:
  ```
  R5LogCheck: Class of type '' doesnt exists. Asset: /Game/Paks/~mods/ShareShip/mod
  R5LogJsonAssets: Cannot create asset: '/Game/Paks/~mods/ShareShip/mod'
  R5NoEntry: [json.exception.type_error.302] type must be string, but is null
  R5NoEntry: Data inconsistent
  ```
  After the third `R5NoEntry` the engine's exception handler latches `Data inconsistent`, an internal `TR5BLPromise` is destroyed incomplete, and the loading screen wedges. Removing the three legacy files clears all four log errors and the mod mounts cleanly. Reproduced from a user-supplied `R5.log` against game build `0.10.0.3.104-256f9653` (Windrose `Version 0.10.0`, UE 5.6.1).

### Removed
- `ShareShip/mod.json`, `ShareShip/enabled.txt`, `ShareShip/Scripts/main.lua` from both the repository and the release archive.

### Notes
- **No `.pak` / `.ucas` / `.utoc` byte changes.** The cooked-asset overrides are bit-for-bit identical to v1.1.0 — only the surrounding archive was cleaned. SHA-256 of the three pak files is unchanged from v1.1.0.
- **Existing v1.1.0 installs:** the simplest fix is to delete `mod.json`, `enabled.txt`, and the `Scripts/` folder out of `<install>\R5\Content\Paks\~mods\ShareShip\` and keep only the three `ShareShip_P.*` files. Reinstalling v1.1.1 does the same thing.

### Credit
- Thanks to the player who supplied the `R5.log` snapshot — the `R5LogJsonAssets` error pointed straight at the offending file.

## [1.1.0] - 2026-04-22 — Dock duplicate-prompt fix

### Fixed
- **Duplicate Q prompt when a ship is docked.** In v1.0 the helm showed two "Ship Management" options simultaneously for any player standing at a docked ship's wheel — the mod's always-on variant plus the vanilla dock-specific variant. Both bound to Q, confusing the UI. v1.1 eliminates the duplicate at the helm level: the helm now only ever advertises one Management option, regardless of dock state or ownership. All four cases (owner / non-owner × docked / not-docked) now resolve to exactly one Q prompt.

### Changed
- **Mechanism moved from DataAsset requirement swap to helm `Options` TArray null-patch.** v1.0 left both interaction options (`ShipManagement` and `ShipDockManagement`) registered on the helm and used a requirement-level swap on `ShipManagement` to bypass the owner check — which also removed the embedded dock-mutex, surfacing the duplicate prompt. v1.1 keeps the v1.0 requirement swap intact (so non-owners can still open the Management UI) and additionally overrides the helm target DataAsset `DA_InteractionTarget_ShipSteeringWheel`: a 4-byte edit to its `.uexp` at offset `0x14-0x17` rewrites the third `FPackageIndex` in the helm's `Options` TArray — the one pointing at `DA_InteractionOption_ShipDockManagement` — to a null index. The engine iterates the TArray, the null entry resolves to nullptr, the UI skips it, and the dock-specific Management option simply never appears at the helm. Same surgical byte-patch pattern as v1.0.
- **Pak triple sizes** grow from 347 + 1643 + 501 bytes (v1.0, ~2.5 KB) to 347 + 2434 + 673 bytes (v1.1, ~3.4 KB) because the override now carries two cooked DataAssets instead of one.
- **`mod.json`** version bumped from `0.0.1` to `1.1.0`.

### Cosmetic note
- When docked, the Q prompt label reverts to "Ship Management" instead of "Ship Management (docked)". Cosmetic only — the management UI itself is identical in both variants (same cargo hold, slot upgrades, etc.). No functional feature is lost.

### Tested
- Listen-server smoke test on Windows client (2026-04-22). All four test-matrix cases (owner / non-owner × docked / not-docked) resolve to one Q "Management" prompt. v1.0's duplicate-Q in dock is gone.
- `retoc to-zen --version UE5_6` Legacy→Zen container validator round-trips cleanly; `retoc verify` reports the triple as valid.

### Abandoned path (kept for transparency)
- An earlier v1.1-experimental build (`patched-v3/` in the toolkit repo) tried to fix the duplicate by additionally redirecting `R5Requirement_CanOpenShipDockManagement` to an always-true requirement. That made the DockManagement option visible to everyone, which did not reduce the prompt count for owners — the duplicate bug was untouched. v1.1 (Path E, helm-level cut) supersedes and drops that attempt.

### Completed (post-release)
- Dedicated-server cross-host smoke test passed (2026-04-25). All four test-matrix cases verified with a remote client.
- Nexus Mods v1.1.0 upload completed (2026-04-22).

## [0.1.0] - 2026-04-22 — Initial release

### Added
- IoStore triple (`ShareShip_P.pak` + `.ucas` + `.utoc`, ~2.5 KB total) that overrides the cooked DataAsset `/Game/Gameplay/Interaction/Options/DA_InteractionOption_ShipManagement`.
- Patched source `.uasset` + `.uexp` in `build/sources/` with a byte-level diff spec in `BUILD-NOTES.md`.
- `build/README.md` reproducing the extract → patch → repack pipeline from retail Windrose assets using `retoc` and the toolkit's Go-based `patch_uasset_redirect.exe`.

### Changed
- The `FObjectImport` entry for `R5Requirement_CanOpenShipManagement` (the owner-only check on the ship-management interaction) is redirected to `R5IsTargetAliveRequirement`, which is already imported by the same DataAsset and evaluates true for any live helm. Exactly 2 bytes differ from the retail `.uasset`.

### Tested
- Listen-server on Windows client: mod mounts (`LogPakFile: Mounting pak file ... ShareShip_P.pak` in `R5\Saved\Logs\R5.log`), non-owner Q prompt appears on another player's helm, and the management UI opens.
- `retoc to-zen --version UE5_6` Legacy→Zen structural validator round-trips cleanly.

### Known issues
- **In-dock duplicate prompt.** When the targeted ship is in a dock, the helm shows two Q options ("Ship Management" from this mod and "Ship Management (docked)" from vanilla). Root cause: vanilla `CanOpenShipManagement` contained both the owner check AND a dock-mutex embedded as C++ lambdas; replacing it with a trivially-true requirement dropped both. A fix requires wrapping `CanOpenShipDockManagement` with a `CommonComposition.CheckType = Not` gate via a `.uexp` byte-level edit, tracked for v0.2. Out-of-dock behaviour is unaffected.

### Pending
- Dedicated-server validation (cross-host smoke test).
- Nexus Mods release packaging.
- v0.2: composition-NOT wrap to suppress the mod's prompt when the ship is docked.

### Notes
- No Lua, no UE4SS, no runtime injection. Pure cooked-asset override. Coexists with Windrose's anti-cheat because the AC does not scan cooked pak contents.
- No save-schema changes, no replicated properties added, no sidecar state files. Uninstalling is a clean folder delete.
