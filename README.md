![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Language](https://img.shields.io/badge/language-Swift%20%7C%20C-orange)

I was in search of a tool for MacOS that could batch convert Apple IIgs SHR graphics into png format but could not find anything.
In the end I decided to code one myself in Swift. It started with SHR uncompressed graphic files to png format.
Then i added HGR and DHGR conversion and output formats like png, jpg, tiff, gif and heic.
Was bored and added then more graphic formats...

Just drag and drop your disk images in the app and extract your pics from there. You also can export any file from within the app to your Mac.

<img width="1608" height="1004" alt="Screenshot 2026-01-23 at 21 27 44" src="https://github.com/user-attachments/assets/f9526914-2f72-41f8-bd90-cebcfd1576f4" />

📂 Supported Formats (13 Platforms)
Retro Platforms

🍎 Apple II/IIGS: SHR (Standard/3200/3200 Packed/816Paint/DreamGrafix), HGR, DHGR, PNT, PIC<br>
🖥️ Amiga: IFF/ILBM (8-bit indexed, 24-bit RGB)<br>
🕹️ Atari ST: Degas (PI1/PI2/PI3)<br>
💾 Commodore 64: Koala Painter, HIRES, Art Studio, D64/D71/D81 disk images<br>
🎮 ZX Spectrum: SCR (6912 bytes)<br>
💻 Amstrad CPC: Mode 0 (16 colors), Mode 1 (4 colors)<br>
📺 MSX/MSX2: Screen 1, 2, 5, 8 (SC1/SC2/SC5/SC8 files, BSAVE format)<br>
📻 BBC Micro: MODE 0-5 (2/4/16 colors, 10KB/20KB files)<br>
🖳 TRS-80/CoCo: Model I/III block graphics, CoCo PMODE 3/4, CoCo 3 (16 colors)<br>
🖨️ PC/DOS: PCX (1/2/4/8/24-bit with RLE compression)<br>
🪟 Windows: BMP (1/4/8/24-bit)<br>
🖼️ Classic Mac: MacPaint (1-bit with PackBits compression)<br>

Modern Formats

📸 PNG: Portable Network Graphics<br>
🎞️ JPEG/JPG: Joint Photographic Experts Group<br>
🎬 GIF: Graphics Interchange Format<br>
📄 TIFF: Tagged Image File Format<br>
📱 HEIC/HEIF: High Efficiency Image Format<br>

✨ Features
File Management

📥 Drag & Drop: Drop files anywhere - main area or browser panel<br>
📁 Folder Support: Recursively scan folders for image files<br>
🔄 Batch Processing: Process hundreds of files at once<br>
🗑️ Clear All: Quick clear button to reset workspace<br>
📂 Recent Folders: Quick access to previously opened folders from File menu<br>

Image Tools

🔄 Rotate: Rotate images 90° left or right<br>
↔️ Flip: Mirror images horizontally or vertically<br>
🔲 Invert: Swap colors (great for MacPaint/1-bit images)<br>
✂️ Crop: Select and crop any region of an image<br>
📋 Copy: Copy current image to clipboard for pasting into other apps<br>
👁️ Before/After: Toggle between original and modified view<br>
↩️ Undo: Revert up to 10 transformations (Cmd+Z)<br>
📊 Batch Transform: Apply rotate/flip/invert to all selected images at once<br>

Palette Editing

🎨 Live Color Editing: Click any palette color to modify it in real-time<br>
🖼️ Supported Formats: SHR, 3200-color, C64, Amiga IFF, Atari ST, ZX Spectrum, MSX, BBC Micro, TRS-80/CoCo, MacPaint, and more<br>
📍 Scanline Palettes: For 3200-color images<br>
🔄 Reset: One-click reset to restore original palette<br>

Export & Conversion

💾 Export Formats: PNG, JPEG, TIFF, GIF, HEIC<br>
📈 Upscaling: 1x (original), 2x, 4x, 8x with nearest-neighbor (pixel-perfect)<br>
📦 Batch Export: Export all images to chosen format<br>
✏️ Custom Naming: Export with patterns like {name}_{n} or converted_{n}<br>
🎨 Format Preservation: Maintains authentic retro look with proper color palettes<br>

Screensaver Export

📺 Create macOS Screensavers: Export your retro graphics as a folder for macOS photo screensavers<br>
🖥️ Auto-Setup: Automatically opens System Settings to configure your screensaver<br>
📏 Scale Options: 2x, 4x, or 8x scaling for crisp pixels on modern displays<br>
📂 Organized Storage: Images saved to ~/Pictures/Retro Screensavers/<br>

Movie Export

🎬 Video Slideshow: Create MP4 or MOV videos from your images<br>
⏱️ Timing Control: Set display duration per image (1-10 seconds)<br>
🔀 Transitions: Crossfade, Fade to Black, Slides, Wipes, Zooms, or Random<br>
📺 Resolution: Export in 720p, 1080p, or 4K<br>
🎥 Codecs: H.264 (universal compatibility) or H.265/HEVC (better quality, smaller files)<br>
📏 Pixel-Perfect: Nearest-neighbor scaling preserves the authentic retro look<br>

User Interface

🔍 Adjustable Thumbnails: Slider to resize preview thumbnails (50-150px)<br>
ℹ️ Image Info: Click info button to see dimensions, file size, color count, format details<br>
📊 Status Bar: Track imported, selected, removed, and exported file counts<br>
🎛️ Modern Toolbar: Hero-style buttons with icons and labels<br>

Smart Detection

🧠 Intelligent Format Recognition: Magic bytes, file size, and extension analysis<br>
🔬 Multi-Method Detection: Priority system prevents false positives<br>
⚙️ Edge Case Handling: Supports variant file sizes (e.g., C64 Koala 10003-10010 bytes)<br>
🎯 Conflict Resolution: DHGR vs CPC, MacPaint vs SHR detection logic<br>

Technical Highlights

🎨 Accurate Color Palettes: C64, Apple II, EGA, CGA, ZX Spectrum, MSX TMS9918, BBC Micro, CoCo palettes<br>
🗜️ Decompression Support: RLE (PCX), PackBits (MacPaint), PackBytes (PNT/SHR), LZW (DreamGrafix), IFF compression<br>
🔄 Format-Specific Decoding: Planar, chunky, interleaved, tile-based bitmap handling<br>
📊 Resolution Accuracy: Proper aspect ratios and pixel layouts<br>

🚀 Use Cases

🕰️ Retro Gaming: Convert game graphics from classic platforms<br>
🎨 Digital Preservation: Archive vintage computer art<br>
🔄 Format Migration: Batch convert old formats to modern standards<br>
📚 Collection Management: Browse and organize retro graphics libraries<br>
🖼️ Comparison: View retro and modern images side-by-side<br>
💿 Archive Processing: Extract and convert graphics from disk images (.2mg, .po, .do, .dsk, .hdv, .d64, .d71, .d81)<br>
📺 Screensavers: Turn your retro art collection into a beautiful macOS screensaver<br>
🎬 Video Slideshows: Create movies from your graphics with transitions for sharing or presentations<br>


<img width="1492" height="831" alt="Bildschirmfoto 2025-12-10 um 14 49 07" src="https://github.com/user-attachments/assets/db620b3a-73e4-4c0c-988c-9c659bcfb75a" />


Amiga images
<img width="1149" height="746" alt="Bildschirmfoto 2025-12-09 um 14 45 48" src="https://github.com/user-attachments/assets/74ba32a7-689f-4859-be10-9a6abfdd7b81" />

Atari ST images, PI1,PI2,PI3
<img width="1064" height="771" alt="Bildschirmfoto 2025-12-09 um 15 31 55" src="https://github.com/user-attachments/assets/eeea4e1a-efdc-47ea-ab3a-7233741aecf8" />

C64 Koala and Art Studio
<img width="1074" height="755" alt="Bildschirmfoto 2025-12-09 um 17 38 31" src="https://github.com/user-attachments/assets/4a3591b1-aff6-4f2a-932d-1850b9062f5e" />

ZX Spectrum SCR
<img width="1074" height="755" alt="Bildschirmfoto 2025-12-09 um 19 11 49" src="https://github.com/user-attachments/assets/36dd5c9c-d223-43d6-a9e7-51ef7b4bd926" />

PCX
<img width="1074" height="755" alt="Bildschirmfoto 2025-12-09 um 21 17 13" src="https://github.com/user-attachments/assets/35aa1129-a246-45bf-badd-381230f928cb" />

Macpaint
<img width="1127" height="740" alt="Bildschirmfoto 2025-12-09 um 22 25 20" src="https://github.com/user-attachments/assets/69af6b59-32d2-4724-bc26-ccdb18519062" />

BMP
<img width="1127" height="740" alt="Bildschirmfoto 2025-12-09 um 22 31 06" src="https://github.com/user-attachments/assets/9a3c7574-deb0-4614-91da-09f402d2824c" />


IMPORTANT INSTALLATION NOTE (Apple Gatekeeper)

Since this app is not distributed through the official Apple App Store and may not have been Notarized by a paid Apple Developer Account, macOS might display a security warning upon the first launch.

You may see a message stating: "The app cannot be opened because it is from an unverified developer."

How to bypass this warning (one-time process):

Close the warning window.
Go to the app in Finder (e.g., in your Applications Folder).
Hold the Control key and click on the app icon (or use the Right-Click menu).
Select Open from the context menu.
In the subsequent dialog box, confirm that you want to open the app by clicking Open again.
The application will now launch and will be trusted by macOS for all future starts.
If this does not work then
1. Open Terminal
You can find it in:
Applications → Utilities → Terminal
2. Run the following command (in case you installed it in the Applications directory):<br>
```xattr -cr /Applications/Retro-Graphics-Converter.app```


[![Downloads](https://img.shields.io/github/downloads/portwally/Retro-Graphics-converter/total?style=flat&color=0d6efd)](https://github.com/portwally/Retro-Graphics-converter/releases)
[![Stars](https://img.shields.io/github/stars/portwally/Retro-Graphics-converter?style=flat&color=f1c40f)](https://github.com/portwally/Retro-Graphics-converter/stargazers)
[![Forks](https://img.shields.io/github/forks/portwally/Retro-Graphics-converter?style=flat&color=2ecc71)](https://github.com/portwally/Retro-Graphics-converter/network/members)

