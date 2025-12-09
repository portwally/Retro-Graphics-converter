I was in search of a tool for MacOS that could batch convert Apple IIgs SHR graphics into png format but could not find anything.
In the end I decided to code one myself in Swift. It started with SHR uncompressed graphic files to png format.
Newly added are now HGR and DHGR conversion and output formats like png, jpg, tiff, gif and heic.
Was bored and added then more graphic formats...

🎨 Supported formats:
<ul>
<li>Apple II: SHR (Standard + 3200 Colour), HGR, DHGR</li>
<li>Amiga: IFF/ILBM (Indexed Colour + 24-bit RGB with LSB-first)</li>
<li>Atari ST: Degas PI1/PI2/PI3 (Low/Medium/High Res)</li>
<li>C64: Koala Painter, Art Studio</li>
<li>ZX Spectrum: SCR</li>  
<li>Amstrad CPC: Mode 0 (160x200) + Mode 1 (320x200)</li>  
<li>PCX: 1/2/4/8/24-bit mit RLE (inkl. CGA 2-bit!)</li>
<li>BMP: (1/4/8/24-bit)</li>li>
<li>MacPaint: (1-bit)</li>
</ul>
Features:

📁 Image browser with thumbnails<br>
🗂️ Folder support (drag & drop + open)<br>
💾 Batch export (PNG, JPEG, TIFF, GIF, HEIC)<br>
⚡ Recursive scanning of subfolders<br>
🎯 Export single image or all images<br>
🔍 Upscaling 2x/4x/8x <br>
🎨 5 Export formats<br>

NEW version 2 now with image browser

<img width="1012" height="740" alt="Bildschirmfoto 2025-12-09 um 11 37 11" src="https://github.com/user-attachments/assets/e13ae4d8-4699-440c-9d6a-d15364f033c8" />
<img width="1012" height="740" alt="Bildschirmfoto 2025-12-09 um 11 36 48" src="https://github.com/user-attachments/assets/7b858688-7503-4b00-96da-e598fc0af28a" />

Can now read Amiga images
<img width="1149" height="746" alt="Bildschirmfoto 2025-12-09 um 14 45 48" src="https://github.com/user-attachments/assets/74ba32a7-689f-4859-be10-9a6abfdd7b81" />

Can now read Atari ST images, PI1,PI2,PI3
<img width="1064" height="771" alt="Bildschirmfoto 2025-12-09 um 15 31 55" src="https://github.com/user-attachments/assets/eeea4e1a-efdc-47ea-ab3a-7233741aecf8" />

C64 Koala and Art Studio support
<img width="1074" height="755" alt="Bildschirmfoto 2025-12-09 um 17 38 31" src="https://github.com/user-attachments/assets/4a3591b1-aff6-4f2a-932d-1850b9062f5e" />

ZX Spectrum SCR support
<img width="1074" height="755" alt="Bildschirmfoto 2025-12-09 um 19 11 49" src="https://github.com/user-attachments/assets/36dd5c9c-d223-43d6-a9e7-51ef7b4bd926" />

PCX Support
<img width="1074" height="755" alt="Bildschirmfoto 2025-12-09 um 21 17 13" src="https://github.com/user-attachments/assets/35aa1129-a246-45bf-badd-381230f928cb" />

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
