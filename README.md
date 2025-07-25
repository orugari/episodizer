# episodizer
A PowerShell script to automatically rename your TV show episode files using titles fetched from [TheTVDB](https://thetvdb.com). It can also organize episodes into season folders.

---

## Features

- Automatically renames episode files using TheTVDB data.
- Detects episodes with formats like: `S01E01`, `S01E001`, `1x01`, `S01 E01`, etc.
- Cleans filenames:  
  `My.Show.Name.S01E01.HDTV.x264.mkv` → `S01E01 - Episode Title.mkv`
- Supports multiple languages (defaults to selected language or falls back to English).
- Creates season folders and organizes episodes accordingly.

---

## ⚙Requirements

- PowerShell **5.1+** (Windows compatible)
- A valid **TheTVDB v4 API Key**

---

## How It Works

When provided with a base folder like `C:\Videos\` or `\\NAS\Series\`, the script:

1. Uses the folder name as the TV show name  
   (`\\NAS\Series\Zorro` → searches for `Zorro` on TheTVDB)
2. Scans for files with episode patterns (e.g. `S01E01`)
3. Retrieves episode names from TheTVDB using your preferred language
4. Renames files to a clean format
5. Organizes episodes into season folders (optional)

---

## Quick Start

1. Open `TVDB_Renamer.ps1` and set your default configuration:
   - API Key
   - Base folder path
   - Language (`fra`, `eng`, `deu`, etc.)
2. Run the script:

```powershell
.\TVDB_Renamer.ps1
or
.\TVDB_Renamer.ps1 -apiKey "api_key" -basePath "\\NAS\MesSeries" -lang "eng" -seasonStyle "Season" -flat

