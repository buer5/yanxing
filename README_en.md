# yanxing

[中文](README.md) | **English**

A lightweight, dependency-free Windows terminal TUI for English typing and dictation practice:

-   Responsive two-pane / single-pane workspace (practice card + clickable queue at `>= 80` cols; compact single pane below `80` cols);
-   Typing and Dictation modes (dictation hides spelling, shows Chinese-only prev/next previews, and records mistakes only when misspelled);
-   CJK-exact column width calculation with line-level incremental diff rendering;
-   SGR mouse support for top bar, bottom bar, overlays, and word queue;
-   14 built-in offline word & sentence decks, local `.txt` import, and OpenAI-compatible AI deck generation.

It ships as a single pure PowerShell script with zero external child processes, using Windows `SAPI.SpVoice` for speech and built-in `winsqlite3.dll` for local SQLite persistence.

## Files

```
yanxing/
├── yanxing.ps1       main TUI application & source (pure PowerShell, zero dependencies)
├── install.ps1       installer / uninstaller (copies files and registers User PATH)
├── dicts/            14 built-in offline word & sentence JSON decks
├── README.md         Chinese documentation
├── README_en.md      English documentation
└── LICENSE           MIT License
```

## Quick start

### One-line install (auto-registers User `PATH`)

```powershell
irm https://raw.githubusercontent.com/buer5/yanxing/main/install.ps1 | iex
```

Then run `yanxing` from any terminal.

### Local install or direct run

```powershell
git clone https://github.com/buer5/yanxing.git
cd yanxing

# Install to %USERPROFILE%\.yanxing\bin and register User PATH
.\install.ps1

# Or run directly from source
.\yanxing.ps1
```

## License

MIT; see [LICENSE](LICENSE).
