# Audit TODO — Retro Graphics Converter

Audit sessions of 2026-10-10/11 (two passes). Build is clean (Debug, zero warnings). Nothing in
the project was changed; this file is the only output.

Status legend: **[confirmed]** = reproduced with a test harness built from the project's
decoder sources · **[code]** = found by reading the code, not yet reproduced ·
**[likely]** = depends on format knowledge I could not check against a real sample file.

---

## 1. Crashes and hangs

**All fixed on 2026-10-11 (uncommitted).** Verified: app builds with no warnings; the crafted
crash inputs now return cleanly; 8,000 fresh fuzz cases and a 3,072-variant IFF plane sweep run
without a crash; the 3,368 real disk images give identical results before and after. Not
verified by running: the drag-and-drop lock and the movie-export abort (both need the UI), and the
ADF / Atari ST / MSX directory-cycle guards (only the ProDOS one was exercised with a crafted image).

- [x] **[confirmed] Atari ST disk reader divides by zero.**
  `AtariSTDiskReader.swift:202` — `totalSectors / (sectorsPerTrack * max(1, sides))` traps when the
  boot sector has `sectorsPerTrack == 0`. Reached for any ~360K/400K/720K/800K/1.44M image whose
  bytes 11–13 look like a BPB. Fix: guard `sectorsPerTrack > 0` (the `tracks` value is unused anyway).
- [x] **[confirmed] DreamGrafix LZW crashes on a double clear code.**
  `LZWDecompressor.swift:127` — a stream starting with codes 256, 256, 258 leaves `prevCode == 256`,
  whose dictionary entry is empty, so `prevSequence[0]` is out of range. Fix: treat a non-literal
  code after a clear as invalid (return nil) and guard `!prevSequence.isEmpty`.
- [x] **[confirmed] IFF decoder crashes or hangs on bad plane counts.** `AmigaIFFDecoder.swift`
  - HAM flag with fewer than 2 planes and no CMAP → `finalPalette[0]` out of range (line 452).
  - `numPlanes` ≥ 64 → `1 << numPlanes` is 0 → `finalPalette[-1]` (line 360).
  - `numPlanes` 30–62 → tries to build a palette with billions of entries (hang, multi-GB memory).
  - HAM with more than 8 planes → `UInt8(...)` overflow trap (lines 491–513).
  Fix: after parsing BMHD, accept only planes 1…8 (plus 24/25/32), and for HAM only 5…8.
- [x] **[code] Dropping several files at once races on a shared array.**
  `ContentView.swift:1175-1190` — `filesToProcess.append` is called from concurrent
  `loadFileRepresentation` callbacks. Can crash or lose files. Fix: serialise appends (serial queue or lock).
- [x] **[code] Latent force-unwrap in dead code.** `ContentView.swift:1331` —
  `UTType(filenameExtension:)!` returns nil for extensions containing a space or slash (confirmed),
  but `exportSingleImage` is only called from `exportSelectedImages`, which has no callers. Not
  reachable today; fix or delete together with the dead code in section 6.
- [x] **[code] Recursive directory walkers have no cycle/depth guard** → stack overflow on a corrupt
  image whose subdirectory points back to itself: ProDOS (`DiskImageReader.swift:1498`), ADF
  (`:2105`), Atari ST FAT12 (`AtariSTDiskReader.swift:341`), MSX FAT12 (`MSXDiskReader.swift:306`).
- [x] **[code] Movie export can hang forever.** `ContentView.swift:731, 753` —
  `while !writerInput.isReadyForMoreMediaData { sleep }` never exits if the asset writer has failed.
  Check `assetWriter.status == .writing` in the loop.
- [x] **[code] VIC-20 image creation keeps a pointer to a temporary array.**
  `VIC20Decoder.swift:422-443` — `CGContext(data: &mutablePixels, …)` then `makeImage()` after the
  pointer's lifetime has ended. Undefined behaviour in optimised builds. Use
  `ImageHelpers.createCGImage` like every other decoder.

## 2. Wrong results (file-type routing in `SHRDecoder.decode`)

All of these were reproduced.

**All fixed on 2026-10-11 (uncommitted).** Extension matches are now hints that fall through when
the platform decoder rejects the file; extensions come from a shared `ImageHelpers.fileExtension`.
Verified with crafted files for every item below, 8,000 fuzz cases, and the 3,368 real disks:
- 52 real HGR files on DOS 3.3 disks that were previously rejected are now recognised.
- 173 IIgs PaintWorks animation files (`$C2`) now show their first frame correctly (new rule;
  two checked by eye). Before, they were decoded as "SHR 3200" with wrong colours.
- About 250 false "images" on real disks are gone (MOD music files as SHR 3200, binaries as
  MacPaint / Paintworks / PCX).
- Choices made that you may want to revisit: SHR 3200 by size is limited to 38400–38656 bytes;
  extension-less MacPaint needs a version word of 0–3; 3072-byte CoCo files are decoded as PMODE 1
  (new decoder, not checked against a real file); CoCo catalog entries are decoded by
  `TRS80Decoder` directly on import.
- Still open: `.pic`/`.bin` files of 24000–33000 bytes are still claimed by the CoCo 3 decoder
  first (so a IIgs `FOO.PIC` of 32768 bytes opens as CoCo 3) — unchanged from before.

- [x] **[confirmed] Atari ST `.PI3` files decode as CoCo 3 garbage.** `pi3` is in `trs80Extensions`
  (line 36), which is checked before the Degas list (line 42). A 32034-byte hi-res Degas file comes
  back as "TRS-80 CoCo 3 (320x200)".
- [x] **[confirmed] NEOchrome `.NEO` files decode as CoCo 3 garbage.** There is no `neo` route in
  `SHRDecoder`; the 32128-byte file falls into the 24000–33000 CoCo 3 fallback (line 345). This also
  affects NEO files imported from an `.st` disk catalog, because `importCatalogEntries` re-decodes
  through `SHRDecoder`.
- [x] **[confirmed] Any `.bin` file that is not a TRS-80 size returns Unknown.** An 8192-byte HGR
  file named `PIC.BIN` fails, while `PIC.HGR` works. Extension routes for `bin`/`pic`/`pix`/`max`
  should fall through to magic/size detection when the TRS-80 decoder returns nil.
- [x] **[confirmed] A filename with no dot is treated as its own extension.**
  `filename.split(separator: ".").last` returns the whole name, so an extension-less file called
  `PIC`, `BIN`, `MAX`, `BBC` … is routed by name. 8192-byte `PIC` → Unknown. Use
  `(name as NSString).pathExtension`. Same pattern in TRS80/MSX/BBC/Atari8bit/Plus4 decoders.
- [x] **[confirmed] Atari 8-bit `.PIC` (7680 bytes) → Unknown** — `pic` is claimed by the TRS-80
  list first. Also breaks import of `.PIC` files from ATR catalogs.
- [x] **[confirmed] Atari `.GR10` with embedded palette (7689 bytes) → Unknown** — `gr10` is
  missing from `atari8bitExtensions` (line 48).
- [x] **[confirmed] Atari `.GR5` → Unknown** — `gr5` is in the MSX list (line 24) and shadows the Atari entry.
- [x] **[confirmed] CoCo `.PIC` of 3072 bytes → Unknown** — `TRS80Decoder.decode` sends it to
  `decodePMode3`, which requires 6144 bytes.
- [x] **[confirmed] CoCo 3 640x200 images import from a disk as 320x200.** Catalog entries with a
  non-zero `fileType` are decoded under the name `X.CM3#020000`, so the extension no longer matches
  and the 32000-byte size rule goes straight to `decodeCoCo3_320`, skipping mode detection.
- [x] **[confirmed] Any unknown file ≥ 38400 bytes is "decoded" as SHR 3200.**
  `decodeAppleIIBySize` has `case 38400...` (line 329). A random 50000-byte `.dat` file comes back as
  a 320x200 image. It also makes the MacPaint fallback unreachable above 38400 bytes. Should be `== 38400`.
- [x] **[confirmed] Files that start with 32 zero-ish bytes are "decoded" as Paintworks.**
  `isPaintworksFormat` only checks 16 nibbles. A 5000-byte text-like file returned a 320x396 image.
- [x] **[confirmed] Any file ≥ 128 bytes starting with 0x0A is treated as PCX**, with no fallback.
  An HGR image whose first byte is 0x0A returned a "1x1 PCX, 16129-bit". Validate version/encoding
  bytes and fall through on failure.

## 3. Wrong results (decoders)

**Fixed on 2026-10-11 (uncommitted):** the seven ticked items. Each was checked with a crafted
file (pixel values compared), plus 8,000 fuzz cases. The IFF row reader was merged from four
copies into one; 1,201 generated IFF files decode identically before and after except the 267
with a mask plane. Palette re-render for IFF now calls the real decoder, so it can no longer
drift from it. Not checked against real files: mask-plane IFF, EHB, and MSX Screen 7 (no samples
on this Mac). The four **[likely]** items are untouched — they need sample files first.

- [x] **[confirmed] Top-down BMPs fail to load.** `PCImageDecoder.swift:15-16` assembles height as
  an unsigned value, so `height < 0` is never true and the size check rejects the file.
- [x] **[confirmed] 32-bit (and 16-bit) BMPs load as an all-black image** — the pixel switch at
  line 46 only handles 1/4/8/24 bpp. Simplest fix: add `bmp` to the modern formats and let ImageIO decode it.
- [x] **[confirmed] IFF images lose their palette when the CMAP is shorter than 2^planes.**
  `AmigaIFFDecoder.swift:291` replaces the whole palette with grayscale. This breaks every
  Extra-Half-Brite image (32-colour CMAP, 6 planes) — the EHB flag is parsed but the half-bright
  colours are never generated. Pad the palette instead, and build entries 32–63 for EHB.
- [x] **[code] IFF images with a mask plane (masking == 1) are garbled** — the extra plane per row is not skipped.
- [ ] **[likely] C64 Advanced Art Studio (10018 bytes) uses the Koala layout.**
  `C64Decoder.decodeArtStudio` reads colour RAM at 9002 and background at 10002; the format has
  border/background at 9002/9003 and colour RAM at 9018. Needs a real `.ocp` file to confirm.
- [ ] **[likely] TR-DOS file offsets are doubled.** `TRDOSDiskReader.swift:156` uses 32 sectors per
  logical track; TR-DOS directory entries store a logical track with 16 sectors each. Needs a real `.trd`.
- [ ] **[likely] CoCo RS-DOS granule mapping is off by one track past the directory.**
  `CoCoDiskReader.swift:322` maps granules 34+ to track `n/2`; genuine RS-DOS skips track 17
  (`n/2 + 1`). The current mapping only matches BitPast-made disks.
- [ ] **[likely] BBC `.dsd` images are read as if linear.** `BBCMicroDiskReader.extractFile` ignores
  side interleaving and never reads side 2's catalog.
- [x] **[code] BBC `getDiskInfo` swaps the boot-option and sector-count bit fields** (lines 536–538;
  `canRead` has them right). Values are currently unused.
- [x] **[code] MSX Screen 7 is rendered with the Screen 5 decoder** (512-wide data shown as 256).
- [x] **[code] MacPaint treats flag byte 128 as a 129-byte run** instead of a no-op (`RetroDecoder.swift:278`).

## 4. Disk images

**Fixed on 2026-10-11 (commit on branch `audit-fixes`).** Results on the 3,368 real Apple II
disk images, before -> after:
- Shown as "CoCo RS-DOS": 373 -> 0. (345 now open as DOS 3.3 / ProDOS; the other 28 are disks
  no reader understands and now say so instead of showing garbage.)
- No catalog at all: 229 -> 201. The 51 DiskCopy 4.2 images and 5 others now open.
- Files listed: 132,177 -> 141,669. Images found: 17,940 -> 18,312.
- 166 subdirectories on DOS-ordered ProDOS disks are now listed (they were skipped).
- About a third of DOS 3.3 filenames contain a space and were being cut short; now complete.
- No crashes on 7,500 mutated disk images (DOS 3.3, both ProDOS orders, D64, DiskCopy 4.2).

Things that changed which you may notice:
- DOS 3.3 catalogs now start at the sector named in the VTOC instead of always sector 15. Six
  disks list fewer files as a result (Newsroom clip-art disks 2 -> 0, Print Shop Companion
  57 -> 43); these were entries real DOS 3.3 would not show.
- DOS-ordered ProDOS disks now go through the normal ProDOS reader after reordering sectors.
  Eleven disks list 1-8 fewer files (entries the normal reader skips, e.g. empty or forked
  files); none lost an image. The older special-case reader is kept as a fallback and is still
  preferred when it finds more pictures.
- D71, D81 and 40-track D64 are implemented, but only tested with synthetic disks built by the
  test harness (file bytes read back intact, including from side 2 of a D71) - no real images.
- CoCo disks must now be at least 161,280 bytes (the smallest real RS-DOS size).

Still open in this section:
- 201 real images still return no catalog (mostly 140K `.dsk` files that are copy-protected or
  use Pascal/CP/M/Apple III formats; not examined one by one).
- (resolved: the legacy `readDiskImage` path, including `readCPCDSK`, has been removed.)

- [x] **[confirmed] 11% of real Apple II disks open as "CoCo RS-DOS" with garbage contents.**
  Of 3,368 Apple II disk images on this Mac, 373 (344 `.dsk`, 20 `.po`, 9 `.do`) were claimed by
  `CoCoDiskReader.canRead`, which runs before the Apple readers in `readDiskCatalog` and accepts
  any 140–380 KB file whose 68 bytes at offset 78592 are ≤ 0x8F. Calling the Apple readers directly
  on those 373 gives a valid catalog for 346 of them (260 DOS 3.3, 61 ProDOS in DOS order,
  25 ProDOS). Examples: `Tanks.dsk`, `Kaboom/graphics.dsk`, `Foxxivision demo.dsk`.
  Fix: try 2IMG/D64/ProDOS/DOS 3.3 before CoCo, BBC and TR-DOS, and tighten the CoCo check
  (size must be a known RS-DOS size; directory entries must have printable names and types 0–3).
- [ ] **[partly fixed] 229 of 3,368 real images return no catalog at all**, and the user only sees
  "Could not read disk image". Breakdown: 135 × 143360-byte `.dsk` (likely copy-protected, Pascal,
  CP/M or Apple III disks), 51 × DiskCopy 4.2 images saved as `.dsk` (838484 / 819284 bytes —
  84-byte header not handled), 8 × `.2mg` (non-ProDOS contents), 3 × 32 MB `.hdv`, and about 20
  truncated `.po` files (143352–143359 bytes). DiskCopy 4.2 support would recover the largest
  identifiable group.
- [x] **[confirmed] 19 real disks open as an empty "DOS 3.3" catalog** — see the
  `readDOS33CatalogFull` item below.
- [x] **[code] Subdirectories are skipped on DOS-ordered ProDOS disks** (`DiskImageReader.swift:3003`,
  "Skip subdirectories for now"). Files inside folders on a `.dsk` ProDOS image never appear.
- [x] **[code] `convertDOSOrderToProDOSOrder` uses the wrong sector table** (line 2884). It only
  runs as a last fallback, so it currently never produces a valid disk. The table named
  `prodosToDOSSectorReversed` is the standard mapping; the one named "standard" is not.
- [x] **[code] `readDOS33CatalogFull` returns an empty catalog instead of nil**, which stops the
  ProDOS-in-DOS-order fallbacks from running.
- [x] **[code] DOS 3.3 filenames are cut at the first space** (lines 510, 1663) — `MY PICTURE` becomes `MY`.
- [x] **[code] Sparse blocks are skipped rather than zero-filled** in the DOS-order ProDOS extractors
  (lines 3228, 3336), shifting the rest of the file.
- [x] **[code] ProDOS BIN "header" detection is too loose** (line 1527) — an image starting
  `00 20 01 00` loses its first 4 bytes. Require `length == count - 4`.
- [x] (code removed) **[code] `readCPCDSK` (non-catalog path) does not trim files by record count**, so `.SCR` files
  with an AMSDOS header come out 17408 bytes and are not recognised. The catalog path does trim.
- [x] **[code] CPC `.SCR` entries are flagged `isImage` even when decoding fails** (line 2407);
  importing them then silently yields nothing.
- [x] **[code] D71 and D81 are advertised but not implemented.** `readD64` only accepts 174848 /
  175531 bytes. README lines 20, 51, 52, 140 and HelpView lines 124, 551, 552 list `.d71`/`.d81`
  as supported; 40-track D64s are rejected too. Either add readers or remove the claims.
- [x] **[code] Catalog "Export Files" fails silently.** `DiskCatalogBrowserView.swift:111-136` — a
  name containing `/` (ST/MSX subfolder paths, C64 names) makes `write` throw; the empty `catch {}`
  aborts all remaining files with no message. Same-named files in different folders overwrite each other.

## 5. UI and export

**All fixed on 2026-10-11 (branch `audit-fixes`).** The app builds without warnings and launches
with a single window. Checked by test: filter categories, colour-depth labels, and upscaling of
indexed / 16-bit images. **Not exercised by hand:** everything that needs clicking through the UI
(batch export naming, the disk-browser queue, grouped undo, selection pruning on filter change).
How each was fixed:
- Filters use a `platformCategory` on the image type instead of matching display strings; six
  platforms were added to the menu.
- `saveImage` takes the scale as a parameter and reads no view state; the background write to
  `selectedExportFormat` is gone.
- Batch export never overwrites: a name already used in this export or present in the folder
  gets " 2", " 3" ... appended. (Screensaver export still overwrites by design - same slot, same name.)
- Scale / rotate / flip fall back to plain 8-bit RGBA when the image's own pixel format cannot be drawn into.
- Several disk images loaded together open one after another (up to 20 queued; more are
  skipped with a status message).
- Items imported from a disk catalog remember the type-tagged name they were decoded with.
- Undo: a batch transform is one step; failed transforms add nothing; the menu item is "Undo".
- Changing the filter drops hidden images from the selection.
- The app is now a single-window app (`Window` instead of `WindowGroup`), so there is no
  File > New Window any more.
- Missing original data gives one alert per export, not one per image.

- [x] **[code] "Atari ST" filter never matches.** `ContentView.swift:85` looks for `"DEGAS"`, the
  display name is `"Degas (…)"`; NEOchrome is not included either.
- [x] **[code] "Modern" filter misses `.jpg`, `.tif`, `.heif`** — the type name is the upper-cased
  extension (`JPG`), the filter looks for `JPEG`/`TIFF`/`HEIC` (line 90).
- [x] **[code] No filter entries for MSX, BBC, TRS-80, Atari 8-bit, Plus/4, VIC-20.**
- [x] **[code] `@State` is written from a background thread** — `self.selectedExportFormat = format`
  at `ContentView.swift:480`; it is also never restored, so a batch export silently changes the
  format used by later exports. `imageItems` is read off the main thread at lines 1144 and 1383.
- [x] **[code] Exports overwrite without warning.** Two images with the same base name (common for
  disk files) overwrite each other, as do existing files in the target folder.
- [x] **[code] Upscale, rotate, flip and movie scaling silently do nothing for some images.**
  `scaleCGImage`/`rotateImage`/`flipImage` reuse the source `bitmapInfo`; indexed, grayscale or
  16-bit PNG/GIF sources make `CGContext` creation fail. Export then writes 1x, and movies drop the image.
- [x] **[code] Only the last disk image opens when several are loaded at once** — each one
  overwrites `currentCatalog` (lines 1230, 1298).
- [x] **[code] "Original" toggle / palette reset can re-decode differently for catalog items** —
  the fallback at lines 59 and 435 uses the plain filename, not the `#c0xxxx` type-tagged name used on import.
- [x] **[code] Undo issues:** failed transforms still push an undo entry (line 1798); a batch
  transform of more than 10 images can only be partly undone; `clearAllImages` leaves the undo stack
  and menu state; the menu item always says "Undo Crop".
- [x] **[code] Selection survives filter changes**, so Delete/Export can act on images hidden by the filter.
- [x] **[code] Multiple windows share one `AppState`** — ⌘Z and "Open Recent" fire in every window.
- [x] **[code] One modal alert per image** when batch-exporting "Original" without original data (line 1399).
- [x] **[code] Cosmetic type info:** Koala reports "1-bit (2 colors)", every TRS-80/CoCo type
  reports "1-bit (2 colors)", DHGR reports 560x192 for a 280x192 image (`ImageTypes.swift`).

## 5b. Palette editing and the Original/Modified toggle

**Fixed on 2026-10-11 (branch `audit-fixes`).** Measured on every image in the 3,368 real disks
(18,031 images that have a palette): re-rendering with the unmodified palette is pixel-identical
to the decoder for all of them, and a simulated edit of every colour changes the picture for all
of them. 12,000 decodes hashed before and after confirm no decoder output changed.

- [x] **[confirmed] Apple Preferred Format could not be palette-edited** (found in this pass; the
  most common IIgs format - 2,908 real images). The re-render treated the packed APF file as a raw
  screen: for most files the edit did nothing, for files over 32,000 bytes it drew garbage (242 real
  files). APF 3200 also showed the wrong palette (MAIN block instead of the per-line MULTIPAL, and
  read 2 bytes off). Now drawn by the real APF decoder with the edited colours.
- [x] **[confirmed] 816/Paint and 256-colour DreamGrafix were re-rendered from compressed bytes.**
  Now unpacked first.
- [x] **[confirmed] Palette edits did nothing for 30 image types, but the app reported success.**
  Types without a dedicated renderer are now recoloured from a clean copy of the picture (old
  colour -> new colour). This also survives rotate/flip/crop. If a colour is not present in the
  picture the status bar says so, and an edit that cannot be applied is no longer recorded.
- [x] **[confirmed] ZX Spectrum colours shifted when re-rendered** - extractor and decoder now share one table.
- [x] **[confirmed] Amstrad CPC showed an invented palette** (none of its colours occurred in the
  picture). It now shows the inks the decoder used for that file.
- [x] **[confirmed] MSX Screen 1/2/5/7 and MacPaint re-rendering used separate copies of the
  layout logic** that disagreed with the decoder. They now call the decoder with the edited
  colours. MSX Screen 8 (direct RGB, no palette) is shown as a fixed palette.
- [x] True-colour PCX (more than 8 bits per pixel) no longer offers a palette.
- [x] Headerless `.3201`: not an issue in practice - no palette is extracted for those files, so
  the mismatching re-render path is never reached.
- [ ] **Limits of the recolouring fallback:** two palette entries with the same colour are
  changed together; Plus/4 pictures only partly match their displayed palette (79-97% of pixels on
  generated files), so some edits there affect fewer pixels than expected.
- [ ] **PCX (2/3/4/6/8-bpp) and palettised BMP** still have their own re-render code, which
  differed from the decoder on 20-80% of *generated* files (random headers). There are no real PCX
  or BMP files on this Mac to tell whether real files are affected. Same fix would apply: draw
  through the decoder with a palette override.
- [ ] **DreamGrafix re-render is always 320x200**, ignoring the footer's width/height. All 32 real
  DreamGrafix files are 320x200, so this only shows on malformed files.
- [ ] Not exercised by hand: the palette editor UI itself (clicking a swatch, the reset button).
  The handlers were tested through the same renderer and recolour functions they call.

## 5c. More UI items (second pass)

**All fixed on 2026-10-11 (branch `audit-fixes`).** Builds without warnings and launches. These
are interactive changes and were **not clicked through**: closing the adjustments popover, the
Original toggle on a recoloured image, and the movie sheet on a small screen.
- Closing the adjustments popover (any way) clears the preview and resets the sliders.
- The preview / Original image is computed once and cached until the image, the toggle or the
  slider values change, instead of on every view update.
- For recoloured image types the Original view now undoes palette edits from the clean copy
  rather than re-decoding by filename.
- The screensaver name is reduced to one safe folder name ("/" and ":" replaced, leading dots
  removed, empty -> "Retro Graphics"). The sheet's path preview text still shows the raw input.
- The movie sheet is as tall as the screen allows (max 850 points); its options scroll and the
  buttons stay visible.

- [x] **[code] Brightness/contrast preview sticks after the popover is dismissed.**
  `previewAdjustments` is only cleared by Apply or Reset (`ContentView.swift:1924-1968`). Clicking
  outside the popover leaves the preview on screen, applies it to whichever image is selected next,
  and it is not part of what gets exported. Clear it when `showAdjustments` becomes false.
- [x] **[code] Adjustment preview and Original view are recomputed inside `body`.** `displayImage`
  (`ContentView.swift:48`) runs a full per-pixel pass or a full re-decode on every view update.
- [x] **[code] Screensaver name is used as a path component unchecked**
  (`ContentView.swift:536-539`) — a name containing `/` or `..` writes outside
  `~/Pictures/Retro Screensavers`.
- [x] **[code] Movie export sheet is a fixed 550x850 points** (`MovieExportSheet.swift`), taller
  than the usable screen on 13-inch MacBooks; the buttons can end up off-screen.

## 6. Notes on the earlier AUDIT-REPORT.md (April)

- Item 2.1 ("add `[weak self]` everywhere") does not apply: `ContentView` is a struct.
- Items 1.2/1.5 (T/S-list bounds) are not bugs: the max offset is +255 inside a checked 256-byte sector.
- Item 1.1 (zero-size image divide) is not reachable from any decoder I read.

## 6b. Dead code (compiled, never called)

**Removed on 2026-10-11 (branch `audit-fixes`)** - about 1,650 lines. Verified after removal:
clean build without warnings, app launches, the 3,368 real disks give identical results,
12,000 decode hashes identical, 5,000 fuzz cases clean.

- [x] `ImageCropView.swift` (deleted, and removed from the Xcode project).
- [x] `ContentView`: the eleven unused export / rotate / flip / blend functions and three unused state variables.
- [x] The legacy `DiskImageReader.readDiskImage` path: 15 `read...` functions, `readCPCDirectory`,
  two unused interleave helpers and the `DiskImageFile` type. Checked first on the real disks: it
  never returned anything for a disk the catalog reader could not read. A disk that cannot be
  read now shows "Could not read disk image: <name>" in both the Open and the drag-and-drop path.
- [x] Decoders: `TRS80Decoder.decodePMode4Artifact` and its colour table, `Atari8bitDecoder.decodeGR7`,
  `PackedSHRDecoder.decompressPackBytes` / `decompressPackBytesSafe`, `ImageHelpers.convertRawPalettes`,
  TR-DOS `parseDiskInfo` / `DiskInfo`, and unused constants and geometry properties.
- [x] Views: `ZoomControlsView`, `CropToolsView`, `PaletteColorCell`, `AdjustmentsButton`,
  `HistogramButton`, unused state in `ScreensaverExportSheet`, `AppState.showHelpSection`.
- [ ] Left in place on purpose - small unused properties that describe parsed data and cost
  nothing: `isLocked`, `isReadOnly`, `fileTypeDescription`, `diskTypeDescription` on the disk
  readers; `swiftUIColor`, `totalColors`, `totalUniqueColors`, `withUpdatedColor` on the palette model.
- [ ] `AppleIIImageType.colorDepth` is never displayed anywhere. (The label corrections made to
  it in section 5 therefore have no visible effect; either show it in the info bar or remove it.)

## 6c. Remaining views and models (third reading pass, 2026-10-11)

Read: `PaletteView`, `ToolbarView`, `InfoBarView`, `HelpView`, `ProDOSFileTypes`,
`StatusBarView`, `ImageThumbnailView`. Fixed on branch `audit-fixes`; builds without warnings,
launches, real-disk results and palette re-render results unchanged. **None of the UI changes
below were clicked through.**

- [x] **[code] Disk browser Type column was wrong for every disk that is not ProDOS.** The row
  showed a ProDOS interpretation of the type number: on DOS 3.3 disks binary files appeared as
  "TXT" and Applesoft programs as "PCD" (Pascal code); C64 PRG files as "PCD"; every file on
  Atari, MSX, CPC, BBC, CoCo, Amiga and TR-DOS disks as "NON". The readable type each reader
  already computed (`fileTypeString`) was never displayed. Entries now carry their file system.
  Checked on real disks: DOS 3.3 shows BAS / BIN, C64 shows PRG, ProDOS unchanged.
- [x] **[code] "Export Files" picked extensions with mixed-up type numbers** (ProDOS text files
  got `.bin`). Now per file system; C64 files get `.prg` / `.seq`.
- [x] **[code] Palette shown for the wrong scan line.** Mouse tracking clamped the line number to
  the number of palettes, so for ordinary SHR pictures (16 palettes, 200 lines) only lines 0-15
  could ever be reported. Now clamped to the image height.
- [x] **[code] Palette editor Reset re-rendered once per colour** - 3,200 full re-renders for a
  3200-colour picture - and left the image flagged as modified. Paste did 16. Both now replace the
  palettes in one step; restoring the file's own colours clears the modified flag.
- [x] **[code] Palette editor opened on the wrong palette** for multi-palette pictures (it used
  the line number as a palette index).
- [x] **[code] Thumbnails were stretched to 4:3** whatever the picture's shape (MacPaint, rotated images).
- [x] **[code] Export and Crop buttons were enabled with nothing loaded**; the zoom readout said
  "100%" in fit mode (now "Fit").
- [x] **[doc] Help described features the app does not have.** Corrected: of eleven listed
  keyboard shortcuts only Cmd+Z exists; also Cmd/Shift-click selection, scroll-wheel zoom,
  double-click import, BMP export and a checkerboard background. Export formats and scales now
  match the export sheet.
- [x] **Keyboard shortcuts implemented (2026-10-11), NOT yet tried in the running app.**
  Menu commands: File > Import (Cmd+O), File > Export (Cmd+E), Image > Select All Images (Cmd+A),
  Image > Remove Selected Images (Cmd+Delete), View > Zoom In / Zoom Out / Fit to Window
  (Cmd +, Cmd -, Cmd 0). Plain keys in the main window: arrow keys (previous / next image),
  Home, End, Delete. The browser scrolls to keep the current image visible. Help lists them again.
  - [ ] **Needs a manual check** - I could not drive the app to test these. In particular:
    1. Cmd+A with nothing focused selects all images, and inside a text field (disk browser
       search, screensaver name) still selects the text. This relies on Edit > Select All taking
       the key only while a text field is active.
    2. Arrow keys / Home / End / Delete respond right after launch and after closing a sheet
       (the main view takes keyboard focus; click a thumbnail if they do not respond).
    3. Delete in a text field inside a sheet deletes text, not images (commands are ignored
       while any sheet is open).
    4. Cmd + works on your keyboard layout.
- [ ] The info bar shows the format's nominal size (e.g. 160x200 for Plus/4 multicolor that is
  drawn 320x200, and unchanged after a crop or rotate); the details popover shows the real size.
- Not a bug after testing: I expected `PaletteColor(nsColor:)` to crash on wide-gamut colours and
  to drift by one on round trips. A test showed neither happens (macOS clamps on conversion). The
  clamp-and-round I added there is harmless hardening only.

## 7. Audit work still to do

- [x] Run the disk readers over the real disk images on this Mac — 3,368 images, no crashes or
  hangs; results folded into section 4.
- [x] Fuzz the disk readers — 7,650 mutated copies of six real images (ProDOS `.po`/`.2mg`/`.hdv`,
  DOS 3.3, ProDOS-in-DOS-order, D64): no crashes or hangs. The Atari ST, MSX, ATR, BBC, CoCo,
  TR-DOS, ADF and CPC readers were **not** fuzzed or run on real disks — there are no sample
  images of those formats on this Mac.
- [x] Remaining views read: Adjustments, Histogram, DiskCatalogBrowser, ExportSheet, and the
  logic parts of ScreensaverExportSheet and MovieExportSheet.
- [x] README/HelpView claims checked (D71/D81 finding in section 4; Degas Elite `.PC1`–`.PC3`
  are not claimed in the README, but the ST catalog flags them as images that then fail to import).
- [ ] Find sample files to settle the four **[likely]** items (`.ocp`, `.trd`, genuine RS-DOS `.dsk`, `.dsd`).
- [x] All source files have now been read (section 6c), except that `PaletteExtractor.swift` and
  `PaletteRenderer.swift` were checked by measurement (decode vs re-render on 18,000 real images)
  rather than line by line.
- [ ] Work out why 135 plain 143360-byte `.dsk` files and three 32 MB `.hdv` files return no
  catalog (expected for protected/non-DOS disks, but not verified per file).
- [ ] Decide whether to add a test target; the harness cases from these sessions would make a good start.

## How the confirmed items were reproduced

A command-line harness was compiled from `Decoders/*.swift`, `Utilities/*.swift` and
`Models/*.swift` plus a small driver, then run with hand-built inputs for each case and
a random-input fuzzer (about 18,000 cases across image decode, palette extraction and
palette re-render). The only fuzz crashes were the IFF plane-count cases in section 1.
The second pass added a run over 3,368 real disk images, 7,650 mutated disk images, and a
decode-versus-re-render pixel comparison over 12,000 generated files.
The harness lives in the session scratch folder and is not part of the repo; it would
need to be rebuilt to re-run.
