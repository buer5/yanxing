# yanxing

**English** | [中文](README_ch.md)

A lightweight, dependency-free Windows terminal TUI for English typing and dictation practice:

-   Responsive two-pane / single-pane workspace (practice card + clickable queue at `>= 80` columns; compact single pane below `80` columns);
-   Typing and Dictation modes (dictation hides English spelling, shows translation-only prev/next previews, and records mistakes only when misspelled);
-   CJK-exact column width calculation with line-level incremental diff rendering;
-   SGR mouse support for the top bar, bottom bar, overlays, and word queue;
-   14 built-in offline word & sentence decks, local `.txt` import, and OpenAI-compatible AI deck generation.

It ships as a single pure PowerShell script with zero external child processes, using Windows `SAPI.SpVoice` for speech and built-in `winsqlite3.dll` for local SQLite persistence.

## Files

```
yanxing/
├── yanxing.ps1       main TUI application and source (pure PowerShell, zero dependencies)
├── install.ps1       installer / uninstaller (copies files and registers User PATH)
├── dicts/            14 built-in offline word & sentence JSON decks
├── README.md         English documentation
├── README_ch.md      Chinese documentation
└── LICENSE           MIT License
```

## Quick start

### One-line install (recommended, auto-registers User `PATH`)

Run in PowerShell:

```powershell
irm https://raw.githubusercontent.com/buer5/yanxing/main/install.ps1 | iex
```

Once installed, run `yanxing` from any terminal. To uninstall:

```powershell
irm https://raw.githubusercontent.com/buer5/yanxing/main/install.ps1 -OutFile $env:TEMP\yx-uninst.ps1; & $env:TEMP\yx-uninst.ps1 -Uninstall
```

### Local install or direct run

```powershell
git clone https://github.com/buer5/yanxing.git
cd yanxing

# Install to %USERPROFILE%\.yanxing\bin and register User PATH
.\install.ps1

# Or run directly from source without installing
.\yanxing.ps1
```

### Common CLI options

```powershell
yanxing -List                  # List all built-in word and sentence decks
yanxing -b ket2021 -g 1        # Start with a specific deck and group
yanxing -b nce2 -d             # Practice New Concept English 2 sentences in dictation mode
yanxing -f .\notes.txt         # Import a local text file (plain English or "term|meaning" per line)
yanxing -m                     # Start muted
```

## Layout and rendering

-   **`>= 80` columns (wide)**: left practice card (progress bar, target word/sentence, phonetic, meaning, prev/next preview) + right group queue (click any item to jump).
-   **`< 80` columns (narrow / split pane)**: hides the right queue and wraps the top/bottom bars automatically so nothing is clipped.
-   **Incremental line diff**: pads every row to exact terminal width and rewrites only changed lines via `PrevLines`, avoiding full-screen flicker.
-   **Local storage**: persists progress, mistakes, and AI settings in `%USERPROFILE%\.yanxing\yanxing.db` (`user_setting` table) via `winsqlite3.dll`.

## Shortcuts

| Key | Mouse action | Description |
| --- | --- | --- |
| `F1` / `Ctrl+B` | Click `[F1 ...]` in top bar | Switch word / sentence deck |
| `F2` / `Ctrl+G` | Click `[F2 ...]` in top bar | Switch group |
| `F3` / `Ctrl+M` | Click `[F3 ...]` in top bar | Toggle Typing / Dictation mode |
| `F4` / `Ctrl+V` | Click `[F4 ...]` in top bar | Toggle speech output |
| `F5` | Click `[F5 ...]` in top bar | Open mistake book |
| `F6` | Click `[F6 ...]` in bottom bar | Shuffle current group |
| `Ctrl+L` | Click `[Ctrl+L ...]` in bottom bar | Import local `.txt` file |
| `Ctrl+A` | Click `[Ctrl+A ...]` in bottom bar | Generate deck with AI |
| `Enter` | Click `[Enter ...]` in bottom bar | Replay speech |
| `Tab` | Click `[Tab ...]` in bottom bar | Peek / hide spelling |
| `PgUp` / `PgDn` | Click `[PgUp ...]` / `[PgDn ...]` in bottom bar | Previous / next item |
| `Esc` / `Ctrl+C` | Click `[Esc ...]` in bottom bar | Close overlay or exit |

## Built-in decks

| ID | Type | Description |
| --- | --- | --- |
| `xiaoxue6` | Word | Primary School English (PEP) |
| `zhongkao` | Word | Junior High / Zhongkao Core |
| `ket2021` | Word | Cambridge KET (2021) |
| `pet2024` | Word | Cambridge PET (2024) |
| `gaokao3500` | Word | Gaokao 3500 Vocabulary |
| `cet4` | Word | College English Test Band 4 (CET-4) |
| `cet6` | Word | College English Test Band 6 (CET-6) |
| `ielts` | Word | IELTS Vocabulary |
| `nce1` – `nce4` | Sentence | New Concept English Books 1–4 |
| `ielts900` | Sentence | IELTS Speaking 900 Sentences |
| `s4000` | Sentence | 4000 Core Example Sentences |

## License

MIT; see [LICENSE](LICENSE).
