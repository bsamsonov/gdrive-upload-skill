-- no_bookmarks.lua
-- Убирает идентификаторы заголовков → не создаются закладки (w:bookmarkStart) в DOCX
function Header(el)
  el.identifier = ""
  el.classes = {}
  el.attributes = {}
  return el
end
