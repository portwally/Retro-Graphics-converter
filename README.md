I was in search of a tool for MacOS that could batch convert Apple IIgs SHR graphics into png format but could not find anything.
In the end I decided to code one myself in Swift. It started with SHR uncompressed graphic files to png format.
Newly added are now HGR and DHGR conversion and output formats like png, jpg, tiff, gif and heic.
Was bored and added then more graphic formats...

📂 Supported Formats (10 Platforms)
Retro Platforms

🍎 Apple II/IIGS: SHR (Standard/3200), HGR, DHGR<br>
🖥️ Amiga: IFF/ILBM (8-bit indexed, 24-bit RGB)<br>
🕹️ Atari ST: Degas (PI1/PI2/PI3)<br>
💾 Commodore 64: Koala Painter, HIRES, Art Studio<br>
🎮 ZX Spectrum: SCR (6912 bytes)<br>
💻 Amstrad CPC: Mode 0 (16 colors), Mode 1 (4 colors)<br>
🖨️ PC/DOS: PCX (1/2/4/8/24-bit with RLE compression)<br>
🪟 Windows: BMP (1/4/8/24-bit)<br>
🖼️ Classic Mac: MacPaint (1-bit with PackBits compression)<br>

Modern Formats

📸 PNG: Portable Network Graphics<br>
🎞️ JPEG/JPG: Joint Photographic Experts Group<br>
🎬 GIF: Graphics Interchange Format<br>
📄 TIFF: Tagged Image File Format<br>
📱 HEIC/HEIF: High Efficiency Image Format<br>
🌐 WebP: Google's web format<br>

✨ Features
File Management

📥 Drag & Drop: Drop files anywhere - main area or browser panel<br>
📁 Folder Support: Recursively scan folders for image files<br>
🔄 Batch Processing: Process hundreds of files at once<br>
🗑️ Clear All: Quick clear button to reset workspace<br>

Export & Conversion

💾 Export Formats: PNG, JPEG, TIFF, GIF, HEIC<br>
📈 Upscaling: 1x (original), 2x, 4x, 8x with nearest-neighbor (pixel-perfect)<br>
📦 Batch Export: Export all images to chosen format<br>
✏️ Custom Naming: Export with patterns like {name}_{n} or converted_{n}<br>
🎨 Format Preservation: Maintains authentic retro look with proper color palettes<br>

Smart Detection

🧠 Intelligent Format Recognition: Magic bytes, file size, and extension analysis<br>
🔬 Multi-Method Detection: Priority system prevents false positives<br>
⚙️ Edge Case Handling: Supports variant file sizes (e.g., C64 Koala 10003-10010 bytes)<br>
🎯 Conflict Resolution: DHGR vs CPC, MacPaint vs SHR detection logic<br>

Technical Highlights

🎨 Accurate Color Palettes: C64, Apple II, EGA, CGA, ZX Spectrum palettes<br>
🗜️ Decompression Support: RLE (PCX), PackBits (MacPaint), IFF compression<br>
🔄 Format-Specific Decoding: Planar, chunky, interleaved bitmap handling<br>
📊 Resolution Accuracy: Proper aspect ratios and pixel layouts<br>

🚀 Use Cases

🕰️ Retro Gaming: Convert game graphics from classic platforms<br>
🎨 Digital Preservation: Archive vintage computer art<br>
🔄 Format Migration: Batch convert old formats to modern standards<br>
📚 Collection Management: Browse and organize retro graphics libraries<br>
🖼️ Comparison: View retro and modern images side-by-side<br>
💿 Archive Processing: Extract and convert graphics from disk images<br>


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


