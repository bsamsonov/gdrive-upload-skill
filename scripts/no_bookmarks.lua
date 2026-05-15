-- no_bookmarks.lua
-- Removes heading identifiers → prevents bookmark anchors (w:bookmarkStart) in DOCX
function Header(el)
  el.identifier = ""
  el.classes = {}
  el.attributes = {}
  return el
end
