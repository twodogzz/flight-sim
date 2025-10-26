# NewSkyFix‑A2A‑Aerostar PowerShell Script

**Version:** 1.1  
**Author:** Wayne  
**Date:** 2025‑10‑20  

---

## 📖 Overview
The `NewSkyFix-A2A-Aerostar.ps1` script automates toggling between the original **Base** configuration of the A2A Aerostar 600 aircraft and a user‑defined **alternate state** (e.g., `NewSky`) for compatibility with external tools such as [newsky.app](https://wiki.newsky.app/).

It ensures both the **aircraft preset folder structure** and the **layout.json file** remain consistent, and it integrates with **MSFSLayoutGenerator.exe** to rebuild the layout file so the aircraft is always recognized in Microsoft Flight Simulator (MSFS).

---

## 🚀 Quick‑Start Guide

### Purpose
- **Base** = Original developer configuration.  
- **AltState** = Your custom state (e.g., `NewSky`, `VAConfig`).  
- The script switches between these states and keeps MSFS happy by rebuilding `layout.json`.

### First‑Time Setup
1. Place `NewSkyFix-A2A-Aerostar.ps1` in a folder of your choice.  
2. Run it in PowerShell:
   ```powershell
   .\NewSkyFix-A2A-Aerostar.ps1
   ```
3. On first run, you’ll be prompted for:
	- Where to store logs/config (defaults to the script’s folder)
	- Your MSFS Community folder path
	- Path to MSFSLayoutGenerator.exe
	- Name of your alternate state (e.g., NewSky)

### Normal Use
1. Run the script.
2. Choose Y/N for dry‑run mode.
	- Y = preview only
	- N = make changes
3. The script shows:
	- Current folder state
	- Current layout.json state
4. Options vary depending on state:
If in Base:
	1 - Switch to previous <AltState>
	2 - Enter new state (and replace AltState in config)
	3 - Stay on Base (Cancel)
If in AltState:
	1 - Enter a new state (and replace AltState in config)
	2 - Switch to Base
	3 - Stay on current <AltState> (Cancel)

5. The script updates the folder name, modifies layout.json, and runs MSFSLayoutGenerator.exe.
Logs- All actions are logged in:
<ScriptFolder>\NewSkyFix-A2A-AerostarLog.txt

- Each run is timestamped and includes icons for clarity.

### Troubleshooting- Aircraft missing in MSFS → Ensure MSFSLayoutGenerator.exe ran successfully.
- Config wrong → Delete NewSkyFix-Config.json and rerun the script.
- Emoji in logs show as ?? → Open logs in Notepad or VS Code (UTF‑8 support).

---

### 🛠 Developer Reference
Features
- Config‑driven design (NewSkyFix-Config.json)
- Dry‑run mode
- State mismatch detection and resolution
- Persistent logging with timestamps
- Automatic rebuild of layout.json
- Self‑healing config (auto‑updates missing keys)
- Interactive ability to change AltState at runtime

### Configuration
Config file: NewSkyFix-Config.json

{
  "ScriptFolder": "C:\\Users\\wayne\\OneDrive\\Documents\\Powershell scripts",
  "CommunityFolder": "D:\\FS\\Community",
  "LayoutGenerator": "C:\\Users\\wayne\\Desktop\\MSFSLayoutGenerator.exe",
  "AltState": "NewSky"
}

### Folder Structure
The alternate state replaces the original Base folder when toggled:
D:\FS\Community\
└── a2a-aircraft-aerostar600\
    ├── layout.json
    ├── layout.json.bak   (created by script as backup)
    └── SimObjects\
        └── Airplanes\
            └── aerostar600\
                └── presets\
                    └── a2a\
                        ┌── Base\        ← Original developer configuration
                        │     (exists when in Base state)
                        │
                        └── <AltState>\  ← User-defined alternate (e.g. NewSky)
                              (replaces Base when toggled)
### Workflow
1. Load or create config (prompt for missing keys).
2. Detect current folder and JSON state.
3. Offer mismatch resolution or toggle.
4. Update folder + JSON.
5. Backup layout.json.
6. Run MSFSLayoutGenerator.exe.
7. Log all actions.

### Example Log Output
2025-10-20 06:45:11  === Script started ===
2025-10-20 06:45:11  Dry-run mode: False
2025-10-20 06:45:11  📂 Folder state: Base
2025-10-20 06:45:11  📄 layout.json state: Base
2025-10-20 06:45:20  🔧 Changing AltState from NewSky → VAConfig
2025-10-20 06:45:21  🗂 Backup created at D:\FS\Community\a2a-aircraft-aerostar600\layout.json.bak
2025-10-20 06:45:21  ✅ layout.json updated successfully.
2025-10-20 06:45:21  ⚙️ Running MSFSLayoutGenerator.exe on layout.json
2025-10-20 06:45:22  ✅ layout.json rebuilt by MSFSLayoutGenerator
2025-10-20 06:45:22  📌 Final state: VAConfig
2025-10-20 06:45:22  === Script finished ===

### Error Handling- Missing folders → exit with log
- Missing layout.json → exit
- Missing generator → skip rebuild
- Invalid input → cancel safely

### Maintenance & Extensibility
- Adding new config keys → script prompts and updates config
- Extend to multiple aircraft by adding identifiers
- Future: add menu option for config updates

### References
- MSFS Layout Generator Tool https://flightsim.to/file/93859/msfs-layout-generator
- NewSky Virtual Airline Platform https://wiki.newsky.app/
