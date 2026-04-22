# Building ShareShip from source

This document describes how to reproduce the `ShareShip_P.{pak,ucas,utoc}` triple from retail Windrose assets. The pre-built output lives in [`../ShareShip/`](../ShareShip/) and the patched intermediate sources are in [`sources/`](sources/). See [`sources/BUILD-NOTES.md`](sources/BUILD-NOTES.md) for the byte-level specification of the patch.

## Prerequisites

| Tool | Why | Where to get it |
|------|-----|-----------------|
| `retoc.exe` | Converts between legacy `.uasset`/`.uexp` format and UE5 IoStore (`.utoc`/`.ucas`/`.pak`). | [trumank/retoc](https://github.com/trumank/retoc) — download the Windows release. |
| Go 1.22+ | Builds the `.uasset` patch utilities. | [go.dev/dl](https://go.dev/dl/). |
| `patch_uasset_redirect.exe` | Swaps two FName indices inside the `FObjectImport` table (the core of the patch). | Clone [uberMorgott/Windrose-Modding-Toolkit](https://github.com/uberMorgott/Windrose-Modding-Toolkit), then `go build -C environment/tools/scripts/patch_uasset_fname -o ../patch_uasset_redirect.exe redirect.go`. |
| A Windrose install | Source of the retail `DA_InteractionOption_ShipManagement.uasset`. | Steam AppID `3041230`. |

## Build steps

### 1. Extract the retail DataAsset

`retoc.exe` can dump a single asset out of the IoStore paks by glob:

```powershell
retoc.exe to-legacy `
  --filter "DA_InteractionOption_ShipManagement" `
  --version UE5_6 `
  "<Windrose install>\R5\Content\Paks" `
  "<scratch>\extracted"
```

You should end up with:

```
<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uasset
<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uexp
```

The `.uasset` is 2736 bytes, the `.uexp` is 142 bytes.

### 2. Apply the FName redirect

```powershell
patch_uasset_redirect.exe `
  -in  "<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uasset" `
  -out "<scratch>\patched\DA_InteractionOption_ShipManagement.uasset" `
  -v
```

The tool locates the `FObjectImport` entry whose `ClassName` is `R5Requirement_CanOpenShipManagement` and rewrites two `FName.index` fields to point at `R5IsTargetAliveRequirement` / `Default__R5IsTargetAliveRequirement` instead. It refuses to patch any asset that doesn't contain all four target name strings. Exactly two bytes change: offsets `0x7E6` and `0x7F2`.

### 3. Copy the `.uexp` verbatim

The `.uexp` blob is not modified — copy it beside the patched `.uasset`:

```powershell
Copy-Item `
  "<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uexp" `
  "<scratch>\patched\"
```

### 4. Stage into the UE content tree

`retoc to-zen` preserves the directory layout under the input root, so the patched files must sit at the correct engine-relative path before packaging:

```powershell
mkdir "<scratch>\staging\R5\Content\Gameplay\Interaction\Options"
Copy-Item "<scratch>\patched\DA_InteractionOption_ShipManagement.uasset" `
  "<scratch>\staging\R5\Content\Gameplay\Interaction\Options\"
Copy-Item "<scratch>\patched\DA_InteractionOption_ShipManagement.uexp" `
  "<scratch>\staging\R5\Content\Gameplay\Interaction\Options\"
```

### 5. Pack the IoStore triple

```powershell
retoc.exe to-zen --version UE5_6 `
  "<scratch>\staging" `
  "<scratch>\out\ShareShip_P.utoc"
```

Output: three files in `<scratch>\out\`:

- `ShareShip_P.utoc` (~501 B)
- `ShareShip_P.ucas` (~1643 B)
- `ShareShip_P.pak`  (~347 B — IoStore-pak stub, not a legacy content pak)

Drop all three into the [`ShareShip/`](../ShareShip/) folder (or directly into `<Windrose install>\R5\Content\Paks\~mods\ShareShip\`) to use the freshly-built mod.

## Verification

**Byte diff against retail.** The patch must change exactly two bytes:

```bash
cmp -l <retail-uasset> <patched-uasset>
# Expected:
#   2023   5   4    (offset 0x7E6: ClassName FName index  5 -> 4)
#   2035  35  34    (offset 0x7F2: ObjectName FName index 29 -> 28, octal)
```

**Runtime mount check.** On game start, `R5\Saved\Logs\R5.log` should contain one of:

```
LogPakFile: Mounting pak file ... ShareShip_P.pak
LogIoStore: Mounted IoStore container "ShareShip_P.utoc"
```

**Functional check.** Join a server with the mod loaded as a non-owner, walk up to another player's ship helm, and press the interaction key. The ship-management Q prompt should appear and the management UI should open.

## Rebuilding from the provided sources

If you just want to repack the included patched sources (skipping extraction + patch), start at step 4 using [`sources/DA_InteractionOption_ShipManagement.{uasset,uexp}`](sources/) as the input.
