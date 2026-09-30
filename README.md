# gdrive-upload-skill

A [Claude Code](https://claude.com/claude-code) skill (and standalone Bash script) that uploads a folder of Markdown documents to Google Drive as **native, formatted Google Docs** — while keeping the original `.md` files alongside.

```
./scripts/upload_to_drive.sh ~/projects/docs gdrive:AI_Projects/docs
```

## Why

Google Drive shows `.md` files as plain text. This tool converts each Markdown file via `pandoc` → `.docx` and lets Google Drive import it as a Google Doc, so headings, tables, lists and code blocks render properly and are readable/shareable from any device. The original Markdown is uploaded too, so nothing is lost.

## Features

- Recursive: finds every `*.md` in the folder and **preserves the subfolder structure** on Drive
- Formatted output using a bundled reference style (`pandoc_reference.docx`)
- Clean documents: a Lua filter strips heading bookmarks that otherwise clutter Google Docs
- Originals stored in `md_originals/` next to the converted docs
- Skips `.git/`, `node_modules/`, `.venv/`, `venv/`
- Safe on failure: the temp folder with converted `.docx` files is kept so you can retry manually

## Requirements

- `bash`, Linux or macOS
- [`pandoc`](https://pandoc.org/installing.html) — e.g. `sudo apt install pandoc`
- [`rclone`](https://rclone.org/install/) with a configured Google Drive remote (examples use a remote named `gdrive`; see [rclone Drive setup](https://rclone.org/drive/))

## Installation

### As a Claude Code skill

```bash
git clone https://github.com/bsamsonov/gdrive-upload-skill ~/.claude/skills/gdrive-upload
chmod +x ~/.claude/skills/gdrive-upload/scripts/upload_to_drive.sh
```

Claude Code will pick up `SKILL.md` automatically. Then just ask, e.g.:

> upload this folder to google drive

The agent determines the source folder (current project by default), proposes a target such as `gdrive:AI_Projects/<folder_name>`, runs the script and reports where the files landed.

### As a standalone script

Clone anywhere and run `scripts/upload_to_drive.sh`. Helper files are resolved relative to the script, so it works from any directory.

## Usage

```bash
upload_to_drive.sh <local_folder> <rclone_remote:path>
```

| Argument | Default | Description |
|---|---|---|
| `local_folder` | `.` | Folder to scan for `.md` files |
| `rclone_remote:path` | `gdrive:AI_Projects` | Target folder on Google Drive |

Examples:

```bash
# Current project
./scripts/upload_to_drive.sh "$PWD" "gdrive:AI_Projects/$(basename "$PWD")"

# Several folders
for dir in ~/notes ~/projects/book; do
  ./scripts/upload_to_drive.sh "$dir" "gdrive:AI_Projects/$(basename "$dir")"
done
```

## Result on Google Drive

```
gdrive:<target_folder>/
├── file_name            ← Google Doc (formatted)
├── subdir/file_name     ← Google Doc (structure preserved)
└── md_originals/
    ├── file_name.md
    └── subdir/file_name.md
```

## How it works

1. **Convert** — each `.md` → `.docx` with `pandoc --from=gfm`, using `pandoc_reference.docx` and `no_bookmarks.lua` (if present)
2. **Upload docs** — `rclone copy --drive-import-formats docx`, so Drive converts them to Google Docs
3. **Upload originals** — `.md` files copied as-is into `md_originals/`
4. **Cleanup** — the temp folder is removed only if both uploads succeed

## Repository layout

```
.
├── SKILL.md                     ← skill definition for Claude Code
└── scripts/
    ├── upload_to_drive.sh       ← main script
    ├── pandoc_reference.docx    ← document style template
    └── no_bookmarks.lua         ← pandoc Lua filter
```

## Known limitations

- Code blocks use Courier New 9pt. Google Docs ignores DOCX "no wrap", so lines longer than ~90 characters (e.g. wide ASCII diagrams) will wrap; up to ~70 characters display cleanly.
- Only `.md` files are processed; images and other assets referenced from Markdown are not uploaded.

## License

[MIT](LICENSE)
