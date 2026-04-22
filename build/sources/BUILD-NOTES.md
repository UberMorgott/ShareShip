# Patched `DA_InteractionOption_ShipManagement` — spec

Authoritative description of the patch applied to the retail cooked DataAsset that gates opening the ship-management UI (Q on the helm). These two files are the output of step 3 in [`../README.md`](../README.md) and the input to the IoStore repack.

## Summary

- **Source asset:** `/Game/Gameplay/Interaction/Options/DA_InteractionOption_ShipManagement` (cooked `.uasset` + `.uexp`, extracted from retail Windrose IoStore paks).
- **Change:** redirect one `FObjectImport` entry from `R5Requirement_CanOpenShipManagement` to `R5IsTargetAliveRequirement`.
- **Diff size:** exactly 2 bytes in the `.uasset`. The `.uexp` is verbatim.
- **Why `R5IsTargetAliveRequirement`?** It's already imported by this same DataAsset (it's the `IsTargetAliveRequirement` slot of the interaction's `PrimaryRequirement` composition), so the engine has nothing new to resolve at load time. An earlier attempt (v1) targeted `R5Requirement_InstigatorIsPlayerControlled` instead; that class is imported by only one cooked asset in the whole game, and loading it into this new context made the listen-server hang during startup.

## Byte-level diff

| Offset (hex) | Field                                      | Before | After |
|-------------:|--------------------------------------------|-------:|------:|
| `0x7E6`      | `FObjectImport[16].ClassName.FName.index`  | 5      | 4     |
| `0x7F2`      | `FObjectImport[16].ObjectName.FName.index` | 29     | 28    |

Name-table resolution (indices into the `.uasset`'s FName table):

- name[4]  = `R5IsTargetAliveRequirement`
- name[5]  = `R5Requirement_CanOpenShipManagement`
- name[28] = `Default__R5IsTargetAliveRequirement`
- name[29] = `Default__R5Requirement_CanOpenShipManagement`

After the patch, `FObjectImport[16]` resolves to `/Script/R5.R5IsTargetAliveRequirement` (class) with CDO `Default__R5IsTargetAliveRequirement` instead of the owner-check pair.

## `FObjectImport[16]` record layout

File offset `0x7DE`, record stride **32 bytes** (this cooked format omits the optional `PackageName` / `bImportOptional` fields):

| Field | Offset into record | Value (before → after) |
|-------|-------------------:|------------------------|
| `ClassPackage` FName  | +0  | `(15, 0)` = `/Script/R5` (unchanged) |
| `ClassName`    FName  | +8  | `(5, 0)` → `(4, 0)` |
| `OuterIndex`          | +16 | `-12` = `imports[11]` = `/Script/R5` (unchanged) |
| `ObjectName`   FName  | +20 | `(29, 0)` → `(28, 0)` |
| trailing u32          | +28 | `0` (unchanged) |

The `Imports` array has 20 entries total, spanning `[ImportOffset=0x5DE, ExportOffset=0x85E)` — exactly 640 bytes, confirming the 32-byte stride.

## What is NOT modified

- **Names table** — byte-identical to source.
- **Summary header offsets** — `TotalHeaderSize`, `ExportOffset`, `ImportOffset`, `DependsOffset`, `AssetRegistryDataOffset`, etc.
- **Export table**, **DependsMap**, **AssetRegistryData**, **PreloadDependencies**.
- **`.uexp`** — copied verbatim (142 bytes).

Output `.uasset` size: 2736 bytes, same as source.

## Runtime effect on the interaction's `PrimaryRequirement` composition

Before the patch, four requirements gated the management UI:

1. `R5IsTargetAliveRequirement`
2. `R5Requirement_CanOpenShipManagement`   *(the owner check)*
3. `R5Requirement_CommonComposition`
4. `R5Requirement_CommonTagBased` (`Boarding.Loser`, `Boarding.SteeringProhibited`)

After the patch:

1. `R5IsTargetAliveRequirement`
2. `R5IsTargetAliveRequirement`   *(duplicate — formerly the owner check)*
3. `R5Requirement_CommonComposition`
4. `R5Requirement_CommonTagBased`

The duplicate `IsTargetAlive` check is redundant but harmless: it returns true whenever the targeted actor (the helm) is alive, which is always the case when the interaction prompt is eligible to fire. The owner gate is bypassed while the dead-target / boarding-state gates are preserved.

## Verifying the patch

### Byte diff

```bash
cmp -l <retail>/DA_InteractionOption_ShipManagement.uasset \
       DA_InteractionOption_ShipManagement.uasset
# Expected (1-based decimal offsets):
#   2023   5   4
#   2035  35  34
# I.e. 0x7E6: 5 -> 4, and 0x7F2: octal 35=29 -> octal 34=28.
```

### Names-table dump identical

```bash
diff \
  <(dump_uasset_names.exe -in <retail>/DA_InteractionOption_ShipManagement.uasset) \
  <(dump_uasset_names.exe -in DA_InteractionOption_ShipManagement.uasset)
# Expected: only the "path" line differs.
```

### `retoc` Legacy → Zen round-trip (structural validator)

```bash
mkdir -p /tmp/validate/R5/Content/Gameplay/Interaction/Options
cp DA_InteractionOption_ShipManagement.{uasset,uexp} \
   /tmp/validate/R5/Content/Gameplay/Interaction/Options/
retoc.exe to-zen --version UE5_6 /tmp/validate /tmp/validate_out.utoc
# Expected: silent success, producing .utoc + .ucas + .pak.
```

### Pak listing

```bash
repak.exe list ShareShip_P.pak
# Expected exactly:
#   R5/Content/Gameplay/Interaction/Options/DA_InteractionOption_ShipManagement.uasset
#   R5/Content/Gameplay/Interaction/Options/DA_InteractionOption_ShipManagement.uexp
```

## `.uexp` risk analysis

The `.uexp` blob references objects through `FPackageIndex` (unchanged by this patch) and *potentially* through `(FName.idx, FName.number)` pairs. A scan (`uexp_scan.go` in the toolkit) found a single speculative `idx=5, num=2` hit at `.uexp` offset `0x68`; at `num=2` it cannot be a real FName reference to `R5Requirement_CanOpenShipManagement`, which only ever appears with `num=0`. `retoc to-zen` round-trips the patched pair cleanly, confirming the `.uexp` still parses against the mutated import table.

## Files in this folder

| File | Size | Notes |
|------|-----:|-------|
| `DA_InteractionOption_ShipManagement.uasset` | 2736 B | 2 bytes differ from retail (offsets `0x7E6`, `0x7F2`). |
| `DA_InteractionOption_ShipManagement.uexp`   |  142 B | Verbatim copy of retail. |

## Known limits

- The patcher tool looks up the four target name strings by content. It refuses to patch any `.uasset` that doesn't contain all four.
- `FObjectImport` stride is assumed to be 32 bytes. If a future target asset uses the cooked layout with `PackageName` / `bImportOptional` fields (stride ≠ 32), the tool aborts with an explicit mismatch error.
