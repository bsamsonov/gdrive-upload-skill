#!/usr/bin/env bash
# ============================================================
# upload_to_drive.sh
# Uploads a folder of MD files to Google Drive:
#   - converts .md → .docx (via pandoc) → Google Doc
#   - copies original .md files into a md_originals/ subfolder
#
# Usage:
#   ./upload_to_drive.sh <local_folder> <gdrive_path>
#
# Examples:
#   ./upload_to_drive.sh ai_learning_book/ gdrive:AI_Projects/ai_learning_book
#   ./upload_to_drive.sh agents2/          gdrive:AI_Projects/agents2
#   ./upload_to_drive.sh .                 gdrive:AI_Projects/root
# ============================================================

set -euo pipefail

# ---- Parameters -----------------------------------------------
LOCAL_DIR="${1:-.}"
GDRIVE_PATH="${2:-gdrive:AI_Projects}"

# Paths to helper files located next to this script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REFERENCE_DOC="$SCRIPT_DIR/pandoc_reference.docx"
LUA_FILTER="$SCRIPT_DIR/no_bookmarks.lua"

# ---- Dependency check -----------------------------------------
if ! command -v pandoc &>/dev/null; then
  echo "ERROR: pandoc is not installed. Install it with: sudo apt install pandoc"
  exit 1
fi
if ! command -v rclone &>/dev/null; then
  echo "ERROR: rclone is not installed."
  exit 1
fi

# ---- Normalise LOCAL_DIR (strip trailing slash) ---------------
LOCAL_DIR="${LOCAL_DIR%/}"

# ---- Temp directory for docx files ----------------------------
TMPDIR=$(mktemp -d)
# Temp dir is removed only on success (see end of script)

echo "================================================"
echo "  Source:         $LOCAL_DIR"
  echo "  Google Drive:   $GDRIVE_PATH"
  echo "  Temp folder:    $TMPDIR"
  [[ -f "$REFERENCE_DOC" ]] && echo "  Reference doc:  $REFERENCE_DOC" || echo "  Reference doc:  (not found, using pandoc default)"
echo "================================================"

# ---- Step 1: Convert MD → DOCX -------------------------------
echo ""
echo "[1/3] Converting .md → .docx (pandoc)..."

CONVERTED=0
FAILED=0

# Use process substitution instead of pipe so counters work in the same shell
while IFS= read -r mdfile; do

  # Compute relative path — preserves subfolder structure
  relpath="${mdfile#$LOCAL_DIR/}"
  relpath="${relpath#./}"
  docxfile="$TMPDIR/${relpath%.md}.docx"
  docxdir="$(dirname "$docxfile")"
  mkdir -p "$docxdir"

  # Build pandoc argument list
  pandoc_args=("--from=gfm" "--to=docx" "--standalone")
  [[ -f "$REFERENCE_DOC" ]] && pandoc_args+=("--reference-doc=$REFERENCE_DOC")
  [[ -f "$LUA_FILTER" ]]    && pandoc_args+=("--lua-filter=$LUA_FILTER")

  if pandoc "$mdfile" "${pandoc_args[@]}" -o "$docxfile" 2>/dev/null; then
    echo "  ✓ $relpath"
    CONVERTED=$((CONVERTED + 1))
  else
    echo "  ✗ ERROR: $relpath"
    FAILED=$((FAILED + 1))
  fi

done < <(find "$LOCAL_DIR" -name "*.md" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" \
  -not -path "*/venv/*" \
  | sort)

echo ""
echo "  Converted: $CONVERTED file(s)"
echo "  Errors:    $FAILED file(s)"

if [[ $CONVERTED -eq 0 ]]; then
  echo "ERROR: No files were converted — aborting."
  rm -rf "$TMPDIR"
  exit 1
fi

echo ""
echo "[2/3] Uploading Google Docs (DOCX → Google Drive)..."
echo "      Path: $GDRIVE_PATH/"

# Upload docx files — Google Drive automatically converts them to Google Docs
rclone copy "$TMPDIR/" "$GDRIVE_PATH/" \
  --drive-import-formats docx \
  --include "*.docx" \
  --progress \
  --transfers 4 && STEP2_RC=0 || STEP2_RC=$?

echo ""
echo "[3/3] Uploading original .md files → md_originals/..."
echo "      Path: $GDRIVE_PATH/md_originals/"

# Upload original .md files as-is (no conversion)
rclone copy "$LOCAL_DIR" "$GDRIVE_PATH/md_originals/" \
  --filter "- .git/**" \
  --filter "- node_modules/**" \
  --filter "- .venv/**" \
  --filter "- venv/**" \
  --filter "+ *.md" \
  --filter "- *" \
  --progress \
  --transfers 4 && STEP3_RC=0 || STEP3_RC=$?

echo ""
if [[ $STEP2_RC -eq 0 && $STEP3_RC -eq 0 ]]; then
  echo "================================================"
  echo "  DONE — temp files removed"
  echo "  Converted: $CONVERTED .md → Google Doc"
  echo "  Pandoc errors: $FAILED"
  echo "  Google Docs:   $GDRIVE_PATH/"
  echo "  Originals .md: $GDRIVE_PATH/md_originals/"
  echo "================================================"
  rm -rf "$TMPDIR"
else
  echo "================================================"
  echo "  ERROR during upload (rclone returned an error)"
  echo "  Temp files preserved: $TMPDIR"
  echo "  You can retry the upload manually:"
  echo "    rclone copy $TMPDIR/ $GDRIVE_PATH/ --drive-import-formats docx"
  echo "================================================"
  exit 1
fi
