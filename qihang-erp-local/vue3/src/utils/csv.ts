// Preserve commas, quotes and newlines; neutralize spreadsheet formula prefixes.
export function csvCell(value: unknown): string {
  let text = value == null ? '' : String(value)
  if (/^[\s\uFEFF]*[=+@-]/.test(text)) text = "'" + text
  return '"' + text.replace(/"/g, '""') + '"'
}

export function buildCsv(headers: string[], rows: unknown[][]): string {
  return '\uFEFF' + [headers, ...rows].map(row => row.map(csvCell).join(',')).join('\r\n') + '\r\n'
}

export function downloadCsv(filename: string, headers: string[], rows: unknown[][]): void {
  const url = URL.createObjectURL(new Blob([buildCsv(headers, rows)], { type: 'text/csv;charset=utf-8;' }))
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 1000)
}
