# Reconstruction Plan

## Core Problem
HarmonyOS phones have no built-in Markdown/HTML file renderer.

## Key Finding
The phone already has a browser engine. ArkUI Web component renders HTML natively. The entire custom 5,000+ line pipeline solves what the platform already solves.

## Musk's Razor
Rebuild with 5 files (~450 LOC). EntryAbility + HomePage + ReaderPage + web-template.html + module.json5. Ship marked.js + highlight.js + KaTeX + Mermaid.js in one WebView. Delete everything else.

## Files to DELETE (30 files, ~4,800 LOC)

### Parsers (4 files, 1,599 LOC)
- `ets/parser/ASTNode.ets` (206) - duplicate types, dead AST
- `ets/parser/HtmlParser.ets` (643) - browser does this
- `ets/parser/MarkdownParser.ets` (594) - marked.js does this
- `ets/parser/TocExtractor.ets` (156) - not needed

### Components (7 files, 809 LOC)
- `ets/components/InfoPanel.ets` (245) - unused
- `ets/components/LinkPreview.ets` (71) - unused
- `ets/components/NavBar.ets` (121) - unused
- `ets/components/SearchBar.ets` (110) - unused
- `ets/components/SourceToast.ets` (47) - unused
- `ets/components/TocDrawer.ets` (146) - unused
- `ets/components/ViewToggle.ets` (67) - unused

### Renderers (8 files, 1,484 LOC)
- `ets/components/renderers/CodeBlock.ets` (114) - unused
- `ets/components/renderers/HtmlRenderer.ets` (78) - unused
- `ets/components/renderers/MarkdownRenderer.ets` (581) - unused
- `ets/components/renderers/MathBlock.ets` (97) - unused
- `ets/components/renderers/MermaidBlock.ets` (127) - unused
- `ets/components/renderers/SourceView.ets` (349) - unused
- `ets/components/renderers/TableBlock.ets` (79) - unused
- `ets/components/renderers/TaskList.ets` (64) - unused

### Services (3 files, 1,564 LOC)
- `ets/service/DocSearch.ets` (413) - unused
- `ets/service/FileService.ets` (218) - unused
- `ets/service/Highlighter.ets` (933) - unused

### ViewModels (2 files, 301 LOC)
- `ets/viewmodel/FileViewModel.ets` (96) - unused
- `ets/viewmodel/ReaderViewModel.ets` (205) - unused

### Common (2 files, 191 LOC)
- `ets/common/Types.ets` (49) - duplicate types
- `ets/common/DocSearch.ets` (142) - unused

### Rawfile (3 files, 1,301 LOC)
- `resources/rawfile/katex-render.html` (419) - replaced by CDN KaTeX
- `resources/rawfile/mermaid-render.html` (575) - replaced by CDN Mermaid
- `resources/rawfile/highlight-theme.css` (307) - replaced by highlight.js theme

## Files to KEEP UNCHANGED (5 files)
- `build-profile.json5` (27)
- `oh-package.json5` (12)
- `entry/oh-package.json5` (9)
- `entry/build-profile.json5` (not read, keep as-is)
- `resources/base/element/color.json` (8)
- `resources/base/element/string.json` (8)
- `resources/base/profile/main_pages.json` (6)

## Files to MODIFY (3 files)
- `ets/entryability/EntryAbility.ets` - simplify to ~50 LOC
- `ets/pages/HomePage.ets` - simplify to ~30 LOC
- `ets/pages/ReaderPage.ets` - rewrite as WebView wrapper ~100 LOC

## Files to CREATE (1 file)
- `resources/rawfile/web-template.html` (~200 LOC) - single HTML with marked.js + highlight.js + KaTeX + Mermaid via CDN

## Final Structure
```
entry/src/main/
  ets/
    entryability/EntryAbility.ets  (~50 LOC)
    pages/HomePage.ets             (~30 LOC)
    pages/ReaderPage.ets           (~100 LOC)
  resources/
    base/element/color.json        (8 LOC)
    base/element/string.json       (8 LOC)
    base/profile/main_pages.json   (6 LOC)
    rawfile/web-template.html      (~200 LOC)
  module.json5                     (83 LOC)
```

## Expected Result
~450 LOC total (down from ~5,000+). Same features via browser engine.
