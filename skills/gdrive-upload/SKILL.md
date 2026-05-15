---
description: |
  Uploads a folder of documents to Google Drive.
  Converts .md → Google Docs (via pandoc+rclone) and preserves originals in md_originals/.
  Use when the user says "upload to google drive", "push docs to drive",
  "sync with google", "upload current project", "upload current folder", "upload folder".
applyTo: "**"
---

# Skill: Upload Documents to Google Drive

## Purpose

Uploads any folder containing `.md` files to Google Drive in two formats:
1. **Google Docs** (formatted) — headings, tables, code — via `pandoc` → `.docx` → Google Drive conversion
2. **Original `.md` files** — stored in a `md_originals/` subfolder for reference

## Script location

```
/home/bvs/projects/ai/google_uploads/
├── upload_to_drive.sh      ← main script (pandoc + rclone, high-quality conversion)
├── pandoc_reference.docx   ← document style template (used automatically)
└── no_bookmarks.lua        ← pandoc lua filter (used automatically)
```

## Usage

The script can be run from **any directory** — pass the source path as the first argument:

```bash
# Upload current folder (the project you are working in)
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh . gdrive:MyFolder/project_name

# Upload a specific folder
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh /path/to/folder gdrive:MyFolder/folder_name

# Upload using a relative path
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh ../other_project gdrive:MyFolder/other_project
```

**Practical examples:**
```bash
# Upload ~/projects/docs/
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh ~/projects/docs gdrive:AI_Projects/docs

# Upload the current working project
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh "$PWD" gdrive:AI_Projects/$(basename "$PWD")

# Upload multiple folders in a loop
for dir in /home/bvs/projects/ai/agents2 /home/bvs/projects/ai/ai_learning_book; do
  /home/bvs/projects/ai/google_uploads/upload_to_drive.sh "$dir" "gdrive:AI_Projects/$(basename "$dir")"
done
```

## What the script does

1. **Conversion**: each `.md` → `.docx` via `pandoc --from=gfm`
   - Uses `/home/bvs/projects/ai/google_uploads/pandoc_reference.docx` (automatically)
   - Uses `/home/bvs/projects/ai/google_uploads/no_bookmarks.lua` (automatically)
   - **Preserves folder structure**: `subdir/file.md` → `subdir/file` on Drive
2. **Google Docs upload**: `rclone copy --drive-import-formats docx` → Google Drive converts `.docx` to Google Doc
3. **Originals upload**: `.md` files go to `<gdrive_path>/md_originals/` with structure preserved
4. **Cleanup**: temp folder is deleted only on success; on error it is kept for manual retry

## Note on ASCII diagrams

Code blocks with ASCII-art (box-drawing characters ┌─┐│└┘) are rendered in Courier New 9pt.
Google Docs does not support `wordWrap=off` from DOCX, so very long lines (>90 chars) may wrap.
Lines up to 70 characters display correctly.

## Dependencies

- `pandoc` — MD → DOCX conversion: `sudo apt install pandoc`
- `rclone` — upload to Google Drive (remote `gdrive:` must be configured)

## Google Drive structure

```
gdrive:<target_folder>/
└── <project_folder>/
    ├── file_name           ← Google Doc (formatted)
    ├── subdir/file_name    ← Google Doc (folder structure preserved)
    └── md_originals/
        ├── file_name.md
        └── subdir/file_name.md
```

## Agent instructions

When the user asks to upload documents to Google Drive:

1. Determine WHICH folder to upload:
   - If not specified — use the current project folder (`$PWD` or the workspace folder)
   - If specified explicitly — use the given path
2. Suggest a default gdrive path: `gdrive:AI_Projects/<folder_name>`
   - Folder name = `basename` of the source path
3. Run the main script:
   ```bash
   /home/bvs/projects/ai/google_uploads/upload_to_drive.sh <folder> gdrive:AI_Projects/<folder_name>
   ```
4. After success, report where the files are on Drive
