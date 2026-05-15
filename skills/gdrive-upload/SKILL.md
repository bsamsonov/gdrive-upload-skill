---
description: |
  Загружает папку с документами на Google Drive.
  Конвертирует .md → Google Docs (через pandoc+rclone) и сохраняет оригиналы в md_originals/.
  Использовать когда пользователь говорит "залей на гугл", "загрузи документы на Drive",
  "upload to google drive", "залить на диск", "синхронизировать с гугл",
  "загрузи текущий проект", "upload current folder", "загрузи папку".
applyTo: "**"
---

# Skill: Upload Documents to Google Drive

## Назначение

Загружает любую папку с `.md` файлами на Google Drive в двух форматах:
1. **Google Docs** (с форматированием) — заголовки, таблицы, код — через `pandoc` → `.docx` → Google Drive conversion
2. **Оригиналы `.md`** — в подпапку `md_originals/` для последующего просмотра

## Расположение скриптов

```
/home/bvs/projects/ai/google_uploads/
├── upload_to_drive.sh      ← основной скрипт (pandoc + rclone, качественная конвертация)
├── upload_investigation.sh ← упрощённый скрипт (только rclone, без pandoc)
├── pandoc_reference.docx   ← стиль документа (используется автоматически)
└── no_bookmarks.lua        ← lua-фильтр pandoc (используется автоматически)
```

## Использование

Скрипт можно запускать из **любой папки** — передай путь к нужной директории первым аргументом:

```bash
# Загрузить текущую папку (проект, в котором работаешь)
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh . gdrive:MyFolder/project_name

# Загрузить конкретную папку
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh /path/to/folder gdrive:MyFolder/folder_name

# Загрузить относительный путь
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh ../other_project gdrive:MyFolder/other_project
```

**Примеры с реальными путями:**
```bash
# Загрузить папку ~/projects/docs/
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh ~/projects/docs gdrive:AI_Projects/docs

# Загрузить текущий рабочий проект
/home/bvs/projects/ai/google_uploads/upload_to_drive.sh "$PWD" gdrive:AI_Projects/$(basename "$PWD")

# Загрузить несколько папок в цикле
for dir in /home/bvs/projects/ai/agents2 /home/bvs/projects/ai/ai_learning_book; do
  /home/bvs/projects/ai/google_uploads/upload_to_drive.sh "$dir" "gdrive:AI_Projects/$(basename "$dir")"
done
```

## Что делает скрипт

1. **Конвертация**: каждый `.md` → `.docx` через `pandoc --from=gfm`
   - Использует `/home/bvs/projects/ai/google_uploads/pandoc_reference.docx` (автоматически)
   - Использует `/home/bvs/projects/ai/google_uploads/no_bookmarks.lua` (автоматически)
   - **Сохраняет структуру папок**: `subdir/file.md` → `subdir/file` на Drive
2. **Загрузка Google Docs**: `rclone copy --drive-import-formats docx` → Google Drive конвертирует `.docx` в Google Doc
3. **Загрузка оригиналов**: `.md` файлы в `<gdrive_путь>/md_originals/` с сохранением структуры
4. **Cleanup**: временная папка удаляется только при успехе; при ошибке — сохраняется для ручного повтора

## Упрощённый скрипт (без pandoc)

`upload_investigation.sh` — более простой вариант, не требует pandoc, конвертирует MD напрямую через rclone:

```bash
# Загрузить папку в gdrive:Investigations/<имя_папки>
/home/bvs/projects/ai/google_uploads/upload_investigation.sh /path/to/folder

# Загрузить текущую папку
/home/bvs/projects/ai/google_uploads/upload_investigation.sh .
```

Использовать когда: быстрая загрузка, pandoc не нужен, папка пойдёт в `gdrive:Investigations/`.

## Примечание про ASCII-диаграммы

Code blocks с ASCII-art (box-drawing символы ┌─┐│└┘) конвертируются в Courier New 9pt.
Google Docs не поддерживает `wordWrap=off` из DOCX, поэтому при очень длинных строках
(>90 символов) возможен перенос. Строки до 70 символов отображаются корректно.

## Зависимости

- `pandoc` — конвертация MD → DOCX: `sudo apt install pandoc`
- `rclone` — загрузка на Google Drive (remote `gdrive:` уже настроен)

## Структура на Google Drive

```
gdrive:<целевая_папка>/
└── <project_folder>/
    ├── file_name           ← Google Doc (отформатированный)
    ├── subdir/file_name    ← Google Doc (структура папок сохраняется)
    └── md_originals/
        ├── file_name.md
        └── subdir/file_name.md
```

## Инструкции для агента

Когда пользователь просит загрузить документы на Google Drive:

1. Определи КАКУЮ папку загружать:
   - Если не указана — использовать текущую папку проекта (`$PWD` или папку из workspace)
   - Если указана явно — использовать указанный путь
2. Предложи gdrive-путь по умолчанию: `gdrive:AI_Projects/<имя_папки>`
   - Имя папки = `basename` от пути источника
3. Запусти основной скрипт:
   ```bash
   /home/bvs/projects/ai/google_uploads/upload_to_drive.sh <папка> gdrive:AI_Projects/<имя_папки>
   ```
4. После успеха сообщи где лежат файлы на Drive
