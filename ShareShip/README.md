# ShareShip — Mod Folder

This folder is the drop-in mod. Place it so that the pak triple lives under the game's `~mods` directory.

## What's inside

```
ShareShip/
    ShareShip_P.pak     # IoStore pak header (347 B)
    ShareShip_P.ucas    # container data (2434 B)
    ShareShip_P.utoc    # container TOC (673 B)
    mod.json            # legacy UE4SS manifest, unused by the pak loader (kept for archival)
    Scripts/main.lua    # legacy UE4SS scaffold, unused by the pak loader (kept for archival)
    enabled.txt         # legacy UE4SS flag, unused by the pak loader (kept for archival)
```

Only the three `ShareShip_P.*` files are required at runtime. The rest is historical from an earlier UE4SS-Lua attempt that was abandoned because Windrose's anti-cheat blocks client-side UE4SS.

## Install

1. Locate your Windrose install directory.
   - Client (Steam): `<Steam>\steamapps\common\Windrose\`
   - Dedicated server: `<server install>\`
2. Create (or open) this directory:
   ```
   <install>\R5\Content\Paks\~mods\ShareShip\
   ```
3. Copy all three `ShareShip_P.*` files into it. Final layout:
   ```
   <install>\R5\Content\Paks\~mods\ShareShip\ShareShip_P.pak
   <install>\R5\Content\Paks\~mods\ShareShip\ShareShip_P.ucas
   <install>\R5\Content\Paks\~mods\ShareShip\ShareShip_P.utoc
   ```
4. Launch the game / server. On first mount the log (`R5\Saved\Logs\R5.log`) will contain:
   ```
   LogPakFile: Mounting pak file ... ShareShip_P.pak
   ```
   and/or
   ```
   LogIoStore: Mounted IoStore container "ShareShip_P.utoc"
   ```

## Multiplayer

The permission check is server-authoritative. For the mod to change behaviour for all players, the **dedicated server** must have this folder installed. Clients that also install it will additionally see the Q interaction prompt render on non-owned ships locally; clients without it can still use the management UI once opened (the server advertises the option).

## Uninstall

Delete the entire `ShareShip/` folder from `~mods`. The mod adds no persistent state, does not change save schema, and leaves no residue.
