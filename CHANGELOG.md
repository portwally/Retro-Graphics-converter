# Changelog

## Version 3.95 - 2026-01-21

### New Features

- **3200-Color Compressed Format (.3201)**: Added support for compressed 3200-color SHR images with the `.3201` extension. These files use PackBytes compression and store 200 unique 16-color palettes (one per scanline). Files are displayed as "SHR 3200 Packed" in the browser.

- **DreamGrafix Format Support**: Added support for DreamGrafix images (PNT/$8005 packed, PIC/$8003 unpacked). DreamGrafix files use 12-bit LZW compression and support both 256-color and 3200-color modes. Files are identified by the "DreamWorld" signature in the 17-byte footer.

### Bug Fixes

- **Fixed .3201 images displaying with garbled horizontal lines**: The palette colors in .3201 files are stored in reverse order (color 0 in file = color 15 in use). Fixed the palette parsing to reverse the color order correctly.

- **Fixed SHR files with 32767 bytes not being recognized**: Some SHR files are 1 byte short of the standard 32768 bytes. Changed size detection to accept 32767-32768 bytes instead of requiring exactly 32768.

- **Fixed ELISE.PNT and similar PNT files decoding as garbled**: The decompression method order was wrong - raw data check ran before compression methods. Reordered to try PackBytes/PackBits compression first, with raw data as the fallback.

- **Fixed ProDOS sparse files displaying as black images**: Files that use ProDOS sparse file format (block 0 = hole filled with zeros) were not being read correctly. The disk reader was stopping at the first zero block instead of filling it with zeros. Fixed both sapling (storageType 2) and tree (storageType 3) file handling to properly support sparse files.

### Files Modified

- `SHRConverter/Decoders/SHRDecoder.swift` - Added decode3201Format function, DreamGrafix auxtype detection, fixed 32767-byte SHR detection
- `SHRConverter/Decoders/DreamGrafixDecoder.swift` - New file: DreamGrafix decoder with 12-bit LZW decompression, 256-color and 3200-color rendering
- `SHRConverter/Decoders/DiskImageReader.swift` - Added .3201 extension detection, fixed sparse file support for sapling and tree files
- `SHRConverter/Decoders/PackedSHRDecoder.swift` - Fixed decompression method order in decodePNT0000
- `SHRConverter/Models/ImageTypes.swift` - Added "SHR 3200 Packed" and "DreamGrafix" display name handling

## Version 3.76 - 2026-01-18

### New Features

- **816/Paint Format Detection**: Added automatic detection and display of 816/Paint format files. Files created with Baudville's 816/Paint software are now properly identified and labeled as "SHR (816/Paint)" in both the image browser thumbnails and the file information area.

- **Raw Image Scanning for Non-Standard Disks**: Added support for bootable slideshow disks and other non-standard disk formats that store images directly without a file system. The app now scans for raw HGR and DHGR images when no DOS 3.3 or ProDOS file system is detected. This enables viewing images from disks like demo slideshows that bypass traditional file systems.

### Bug Fixes

#### ProDOS PNT File Import

- **Fixed PNT files not decoding properly**: PNT files ($C0) from ProDOS disk images were being displayed as garbage instead of proper images. The issue was caused by multiple problems in the import chain:

  1. **Missing auxType in catalog reader**: The `readProDOSDirectoryForCatalog` function was not reading the `auxType` field from ProDOS directory entries, which is required to identify PNT sub-formats (e.g., $0001 for PackBytes compressed).

  2. **Wrong file type passed to decoder**: When storing catalog entries, the original ProDOS file type ($C0 for PNT) was being replaced with a display type ($08 for FOT), preventing the decoder from recognizing the format.

  3. **Missing type suffix in filename**: The import function was passing bare filenames to the decoder instead of filenames with ProDOS type suffixes (e.g., `FILENAME#c00001`). The decoder uses these suffixes to identify file formats.

  4. **Stored type not updated on import**: The image type stored during catalog reading was being used instead of the freshly decoded type, which meant format-specific detection (like 816/Paint signatures) wasn't reflected in the UI.

#### Technical Details

- Added `nameWithTypeInfo` computed property to `DiskCatalogEntry` that constructs filenames with ProDOS type suffixes
- Modified `readProDOSDirectoryForCatalog` to read and preserve the auxType from directory entries
- Updated `importCatalogEntries` to use the type returned from `SHRDecoder.decode()` for accurate format detection
- Added `is816PaintFormat()` function to detect the "816/Paint" signature at offset 32224 in unpacked SHR data

#### Technical Details (Raw Image Scanning)

- Added `scanForRawImages()` function to detect and extract HGR images from non-standard disks
- Added `scanForRawImagesCatalog()` function to provide catalog entries for raw image disks
- Added `isValidHGRImage()` and `isValidDHGRImage()` heuristic functions that detect valid images based on:
  - Reasonable zero byte count (typical of graphics with black areas)
  - Byte diversity (valid images have varied pixel data)
  - Data patterns that distinguish images from code or empty sectors
- Modified `readDiskImage()` and `readDiskCatalogWithOrderDetection()` to fall back to raw scanning when no file system is found

#### ProDOS Disk Image Import with Non-Standard Sector Interleave

- **Fixed file extraction from DOS-ordered ProDOS disks with reversed sector interleave**: Some ProDOS disk images (like hgrbyte_v3.dsk) use a non-standard reversed sector interleave mapping that differs from the standard ProDOS interleave. Files were being extracted as garbled data because the wrong sector order was used.

  **Technical Details:**
  - Standard ProDOS interleave: `[0, 13, 11, 9, 7, 5, 3, 1, 14, 12, 10, 8, 6, 4, 2, 15]`
  - Reversed interleave (for some disks): `[0, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 15]`

  The disk reader now tries multiple interleave methods in order:
  1. Reversed interleave (for non-standard disks)
  2. Standard ProDOS interleave
  3. Direct block addressing
  4. Contiguous file storage fallback

- Added `readProDOSBlockFromDOSOrderDiskReversedInterleave()` function
- Added `readProDOSBlockWithInterleave()` helper to support multiple interleave tables
- Added `extractProDOSFileWithInterleaveMethod()` to extract files using a specific interleave
- Modified `extractProDOSFileFromDOSOrderDisk()` to try multiple extraction methods

#### Added Support for .do and .po Disk Image Extensions

- **Added `.do` and `.po` file extension support**: DOS-ordered (`.do`) and ProDOS-ordered (`.po`) disk image files are now properly recognized as disk images and open in the disk browser instead of being decoded as picture files.

  **Changes:**
  - Added `do_disk` and `po` UTType definitions in UTTypeExtensions.swift
  - Updated `allowedContentTypes` in the file open panel to include `.do` and `.po`
  - Updated `onDrop` handlers to accept `.do` and `.po` files
  - Added `.do` to the disk image extension checks in `processFiles()` and file loading logic

#### PNT/PIC Files Showing Wrong Colors from ProDOS Disk Images

- **Fixed 816/Paint and other PNT files showing grayscale instead of colors**: When importing PNT ($C0) or PIC ($C1) files from ProDOS disk images (especially `.po` ProDOS-ordered images), the files were being decoded without proper palette data, resulting in grayscale images instead of color.

  **Root Cause:**
  The `readProDOSDirectoryForCatalog` function was not reading the `auxType` field from directory entries, and was not passing the ProDOS type info (file type + auxType) to the decoder. The decoder uses filename suffixes like `#c00001` to identify PNT sub-formats:
  - `#c00000` = Paintworks format
  - `#c00001` = PackBytes compressed (used by 816/Paint)
  - `#c00002` = Apple Preferred Format (APF)

  Without this type info, the decoder fell back to size-based detection, which doesn't work for packed files.

  **Fix:**
  - Read `auxType` from ProDOS directory entry offset +31 (2 bytes)
  - Construct filename with type suffix (e.g., `FILENAME#c00001`) when calling decoder
  - Preserve original `fileType` instead of replacing with display type
  - Pass proper auxType for PNT/PIC files when storing catalog entries

#### DOS 3.3 Disks Misidentified as ProDOS

- **Fixed DOS 3.3 disk images being incorrectly identified as ProDOS**: Some DOS 3.3 disks contain machine code that coincidentally looks like a ProDOS volume header (byte value 0xFD at the right offset), causing the disk to be misidentified as ProDOS with only 2 files visible and a garbled volume name.

  **Fix:**
  - Added validation that ProDOS volume names contain only valid characters (A-Z, 0-9, period)
  - Added sanity check on file count field to reject unreasonable values
  - Applied same validation to both `readProDOSCatalogFull` and `readProDOSCatalogFromDOSOrderSequential`

### Files Modified

- `SHRConverter/Decoders/DiskImageReader.swift` - ProDOS catalog reading, type preservation, raw image scanning, and multi-method sector interleave support
- `SHRConverter/Decoders/PackedSHRDecoder.swift` - 816/Paint signature detection
- `SHRConverter/Models/DiskCatalog.swift` - Added `nameWithTypeInfo` property
- `SHRConverter/Views/ContentView.swift` - Use decoded type for accurate format display, added `.do` and `.po` disk image support
- `SHRConverter/Utilities/UTTypeExtensions.swift` - Added `do_disk` and `po` UTType definitions
