## AutoDirEnqueue Prev Next (VLC Lua Interface)

Automatically adds the previous and next track from the same directory to the VLC playlist as soon as a file starts playing. Supports wrap‑around (with ≥3 files, cycling at the beginning/end).

### Features
- Automatically adds neighbors of the currently playing file
- Wrap‑around when there are at least 3 files
- Cross‑platform (Windows, Linux, macOS)
- No GUI interaction required (loads as an interface at VLC startup)

### Requirements
- VLC 3.0.x (tested with 3.0.21)

### Installation

#### Method 1: Automatic Installation

**Windows (PowerShell):**
*Press `Windows + R` → type `powershell` → Enter, then run:*
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser; iwr -useb https://raw.githubusercontent.com/eltoro0815/vlc-auto-dir-enqueue-prev-next/main/scripts/install.ps1 | iex
```

#### Method 2: Manual Installation

1. Copy `auto_dir_enqueue.lua` to your user interface folder (create the folder if needed):
   - Windows: `%APPDATA%\vlc\lua\intf\`
   - Linux: `~/.local/share/vlc/lua/intf/` (alternatively `~/.config/vlc/lua/intf/`)
   - macOS: `~/Library/Application Support/org.videolan.vlc/lua/intf/`

2. Enable the interface (choose one):
   - Option A: persistently via VLC config `vlcrc` (user file)
     - Windows: `%APPDATA%\vlc\vlcrc`
     - Linux: `~/.config/vlc/vlcrc`
     - macOS: `~/Library/Preferences/org.videolan.vlc/vlcrc`
     - Set/add the following lines:
       ```
       extraintf=luaintf
       lua-intf=auto_dir_enqueue
       ```
   - Option B: for testing via command line/shortcut
     - Start parameters: `--intf luaintf --lua-intf auto_dir_enqueue`

### Usage
- Simply open a media file (e.g., double‑click). The interface automatically adds:
  - Previous track: alphanumerically previous file (at index 1 and ≥3 files: last file)
  - Next track: alphanumerically next file (at last index and ≥3 files: first file)
  - With exactly 2 files, only the other file is added

### Logging (optional, for support)
- Enable in `vlcrc` (adjust paths):
  ```
  file-logging=1
  log-verbose=2
  logfile=<path to log file>
  ```
- After startup you will find diagnostic lines prefixed with `auto_dir_enqueue:`

### Troubleshooting
- Interface does not auto‑load:
  - Ensure `extraintf=luaintf` and `lua-intf=auto_dir_enqueue` are set in `vlcrc`
  - Try starting VLC with `--no-one-instance --intf luaintf --lua-intf auto_dir_enqueue`
- Playlist remains at 1 item:
  - Ensure there are other media files with supported extensions in the same folder
  - Check the log (lines with `auto_dir_enqueue:`), especially path/URI conversion and directory listing
- Wrap‑around does not apply:
  - Wrap‑around is only enabled with at least 3 files

### Disable/Uninstall
- Remove or comment out `extraintf`/`lua-intf` in `vlcrc`
- Delete `auto_dir_enqueue.lua` from the interface folder

### Credits
- Idea for robust file selection/playlist manipulation inspired by a VLC Lua extension (neighbor logic, move trick for “previous track”) https://github.com/djomlastic/vlc-prev-next
