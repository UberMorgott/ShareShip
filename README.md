# ShareShip — Open Any Ship's Management UI for Any Player

**Download on Nexus Mods:** https://www.nexusmods.com/windrose/mods/147

In vanilla Windrose only the owner (or active helmsman) of a ship can press **Q** on the wheel to open the ship's management UI. ShareShip removes that single gate — any player who can reach the helm can now manage any ship's cargo hold, slot upgrades, and configuration. Owner-based systems outside the management UI (respawn, permanent customization, insurance, naming) are untouched; this mod only changes who can open the screen.

## Features

- Non-owner **Q** prompt shows on any ship's helm.
- Opens the full management UI: cargo hold, upgrades, slots, and other owner-only views.
- **Server-authoritative** — the dedicated server's copy is what matters. Clients who also install the pak additionally see the Q prompt render locally on non-owned ships.
- **No Lua, no UE4SS, no runtime injection.** ShareShip is a pure cooked-asset override, so it coexists with Windrose's anti-cheat (which does not scan cooked pak contents).
- Tiny. Total install size is **~3.4 KB** (three files: `.pak` + `.ucas` + `.utoc`).

## Install

**Requirements**
- Windrose (Steam AppID `3041230`) on a build using the R5 codename (Unreal Engine 5.6.1 with IoStore paks).

**Steps**
1. Download `ShareShip.zip` from the latest [Release](../../releases).
2. Extract it. You will get a folder called `ShareShip/` that contains `ShareShip_P.pak`, `ShareShip_P.ucas`, and `ShareShip_P.utoc`.
3. Move (or copy) that `ShareShip/` folder into:
   ```
   <Windrose install>\R5\Content\Paks\~mods\ShareShip\
   ```
   The final paths must be:
   ```
   <Windrose install>\R5\Content\Paks\~mods\ShareShip\ShareShip_P.pak
   <Windrose install>\R5\Content\Paks\~mods\ShareShip\ShareShip_P.ucas
   <Windrose install>\R5\Content\Paks\~mods\ShareShip\ShareShip_P.utoc
   ```
   Create the `~mods` and `ShareShip` subfolders if they don't exist.
4. For multiplayer, the **dedicated server** must also have the mod. If you run the server from Steam, the path is:
   ```
   <server install>\R5\Content\Paks\~mods\ShareShip\
   ```
5. Start the game / server. The log file `R5\Saved\Logs\R5.log` should report the mount:
   ```
   LogPakFile: Mounting pak file ... ShareShip_P.pak
   ```

**Uninstall.** Delete the `ShareShip/` folder. The mod adds no persistent state and no save-schema changes, so removal is safe at any time.

## How it works (brief)

ShareShip ships two cooked-asset overrides inside a single IoStore pak triple:

1. **`DA_InteractionOption_ShipManagement`** — the patched `.uasset` differs from the retail file by **exactly two bytes** in the `FObjectImport` table: the entry that used to point at `R5Requirement_CanOpenShipManagement` (the owner check) now points at `R5IsTargetAliveRequirement`, which is already imported by the same DataAsset and returns true for any live ship. The interaction's other gating requirements (boarding state, target-alive, common-composition) are kept intact, so the only behavioural change is that the owner check is bypassed.
2. **`DA_InteractionTarget_ShipSteeringWheel`** (new in v1.1) — a 4-byte edit to the helm target's `.uexp` sets the third `FPackageIndex` entry in the helm's `Options` TArray to null. That entry used to reference `DA_InteractionOption_ShipDockManagement`, the dock-specific Management option. With it nulled, the engine's UI skips the empty slot and the helm only ever advertises two options (Steering on E, Management on Q) instead of three. This removes the v1.0 duplicate-Q-prompt regression that appeared when a ship was docked.

The repo at [`uberMorgott/Windrose-Modding-Toolkit`](https://github.com/uberMorgott/Windrose-Modding-Toolkit) contains the full reverse-engineering notes, SDK-dump workflow, and the Go-based `.uasset` / `.uexp` patch utilities used to produce this override.

## Compatibility

- **Engine:** UE 5.6.1.
- **Game:** Windrose builds using the R5 codename and IoStore paks. If your Windrose install has `.pak` + `.ucas` + `.utoc` files in `R5\Content\Paks\`, you're on a compatible build.
- **Known conflicts:** none. Any other mod that overrides the exact same DataAsset (`DA_InteractionOption_ShipManagement`) will fight with this one — load order (alphabetical inside `~mods`) decides the winner.
- **Save-safe.** No replicated properties added, no schema change, no sidecar files.

## Cosmetic note

- When docked, the Q prompt label reverts to "Ship Management" instead of "Ship Management (docked)". Cosmetic only — the management UI itself is identical in both variants (same cargo hold, slot upgrades, etc.). No functional feature is lost.

## Build from source

See [`build/README.md`](build/README.md) for prerequisites, extraction of the retail `.uasset`, the 2-byte redirect patch, and repacking the IoStore triple with `retoc`.

## License

[GPL-3.0](LICENSE).

## Credits

- **Morgott** ([github.com/uberMorgott](https://github.com/uberMorgott)) — reverse engineering, patch tooling, build.
- **WindrosePlus** authors ([HumanGenome](https://github.com/HumanGenome) et al.) — prior-art Lua patterns and the initial R5 class map that seeded the research.
