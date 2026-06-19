# First-Principles Reconstruction: harmony-md-reader

> Applied Elon Musk's first-principles thinking.

## Core Problem

HarmonyOS phones have no built-in Markdown/HTML file renderer.

## Key Finding

The phone already has a browser engine. ArkUI Web component renders HTML natively. The entire custom 4,000+ line pipeline solves what the platform already solves.

## Dead Code

7 unused components, 8 unused renderers, duplicate types (2 ASTNode, 2 TocEntry, 2 FileInfo, 2 SearchMatch).

## Musk's Razor

Rebuild: 450 lines. EntryAbility (50) + HomePage (30) + ReaderPage (100) + web-template.html (200) + module.json5 (70). Ship marked.js + highlight.js + KaTeX + Mermaid.js in one WebView. Delete everything else.
