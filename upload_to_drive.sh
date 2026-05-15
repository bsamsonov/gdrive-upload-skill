#!/usr/bin/env bash
# ============================================================
# upload_to_drive.sh
# Загружает папку с MD-файлами на Google Drive:
#   - конвертирует .md → .docx (через pandoc) → Google Doc
#   - копирует оригиналы .md в подпапку md_originals/
#
# Использование:
#   ./upload_to_drive.sh <локальная_папка> <gdrive_путь>
#
# Примеры:
#   ./upload_to_drive.sh ai_learning_book/ gdrive:AI_Projects/ai_learning_book
#   ./upload_to_drive.sh agents2/          gdrive:AI_Projects/agents2
#   ./upload_to_drive.sh .                 gdrive:AI_Projects/root
# ============================================================

set -euo pipefail

# ---- Параметры ------------------------------------------------
LOCAL_DIR="${1:-.}"
GDRIVE_PATH="${2:-gdrive:AI_Projects}"

# Пути к доп. файлам рядом со скриптом
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REFERENCE_DOC="$SCRIPT_DIR/pandoc_reference.docx"
LUA_FILTER="$SCRIPT_DIR/no_bookmarks.lua"

# ---- Проверка зависимостей ------------------------------------
if ! command -v pandoc &>/dev/null; then
  echo "ERROR: pandoc не установлен. Установите: sudo apt install pandoc"
  exit 1
fi
if ! command -v rclone &>/dev/null; then
  echo "ERROR: rclone не установлен."
  exit 1
fi

# ---- Нормализуем LOCAL_DIR (убираем trailing slash) ----------
LOCAL_DIR="${LOCAL_DIR%/}"

# ---- Временная директория для docx ---------------------------
TMPDIR=$(mktemp -d)
# Удаляем tempdir только при успешном завершении (см. конец скрипта)

echo "================================================"
echo "  Источник:       $LOCAL_DIR"
echo "  Google Drive:   $GDRIVE_PATH"
echo "  Временная папка: $TMPDIR"
[[ -f "$REFERENCE_DOC" ]] && echo "  Reference doc:  $REFERENCE_DOC" || echo "  Reference doc:  (не найден, используется pandoc default)"
echo "================================================"

# ---- Шаг 1: Конвертация MD → DOCX ---------------------------
echo ""
echo "[1/3] Конвертация .md → .docx (pandoc)..."

CONVERTED=0
FAILED=0

# Используем process substitution вместо pipe, чтобы счётчики работали в том же shell
while IFS= read -r mdfile; do

  # Вычислить относительный путь — сохраняем структуру подпапок
  relpath="${mdfile#$LOCAL_DIR/}"
  relpath="${relpath#./}"
  docxfile="$TMPDIR/${relpath%.md}.docx"
  docxdir="$(dirname "$docxfile")"
  mkdir -p "$docxdir"

  # Собираем аргументы pandoc
  pandoc_args=("--from=gfm" "--to=docx" "--standalone")
  [[ -f "$REFERENCE_DOC" ]] && pandoc_args+=("--reference-doc=$REFERENCE_DOC")
  [[ -f "$LUA_FILTER" ]]    && pandoc_args+=("--lua-filter=$LUA_FILTER")

  if pandoc "$mdfile" "${pandoc_args[@]}" -o "$docxfile" 2>/dev/null; then
    echo "  ✓ $relpath"
    CONVERTED=$((CONVERTED + 1))
  else
    echo "  ✗ ОШИБКА: $relpath"
    FAILED=$((FAILED + 1))
  fi

done < <(find "$LOCAL_DIR" -name "*.md" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" \
  -not -path "*/venv/*" \
  | sort)

echo ""
echo "  Сконвертировано: $CONVERTED файл(ов)"
echo "  Ошибок:          $FAILED файл(ов)"

if [[ $CONVERTED -eq 0 ]]; then
  echo "ERROR: Нет сконвертированных файлов — прерываем."
  rm -rf "$TMPDIR"
  exit 1
fi

echo ""
echo "[2/3] Загрузка Google Docs (DOCX → Google Drive)..."
echo "      Путь: $GDRIVE_PATH/"

# Загрузить docx-файлы — Google Drive автоматически конвертирует в Google Docs
rclone copy "$TMPDIR/" "$GDRIVE_PATH/" \
  --drive-import-formats docx \
  --include "*.docx" \
  --progress \
  --transfers 4 && STEP2_RC=0 || STEP2_RC=$?

echo ""
echo "[3/3] Загрузка оригиналов .md → md_originals/..."
echo "      Путь: $GDRIVE_PATH/md_originals/"

# Загрузить оригинальные .md файлы (без конвертации, как есть)
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
  echo "  ГОТОВО — временные файлы удалены"
  echo "  Сконвертировано: $CONVERTED .md → Google Doc"
  echo "  Ошибок pandoc:   $FAILED"
  echo "  Google Docs:    $GDRIVE_PATH/"
  echo "  Оригиналы .md:  $GDRIVE_PATH/md_originals/"
  echo "================================================"
  rm -rf "$TMPDIR"
else
  echo "================================================"
  echo "  ОШИБКА при загрузке (rclone вернул ошибку)"
  echo "  Временные файлы сохранены: $TMPDIR"
  echo "  Можно повторить загрузку вручную:"
  echo "    rclone copy $TMPDIR/ $GDRIVE_PATH/ --drive-import-formats docx"
  echo "================================================"
  exit 1
fi
