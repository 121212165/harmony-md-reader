export function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`
  if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)}KB`
  return `${(bytes / 1048576).toFixed(1)}MB`
}

export function escapeForJs(content: string): string {
  return content
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
}

export function getFileExtension(name: string): string {
  const dot = name.lastIndexOf('.')
  return dot >= 0 ? name.substring(dot).toLowerCase() : ''
}

export function isMarkdownFile(name: string): boolean {
  const ext = getFileExtension(name)
  return ext === '.md' || ext === '.markdown'
}

export function isHtmlFile(name: string): boolean {
  const ext = getFileExtension(name)
  return ext === '.html' || ext === '.htm'
}
