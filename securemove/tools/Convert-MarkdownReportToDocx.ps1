param(
  [string]$MarkdownPath = (Join-Path $PSScriptRoot '..\docs\SecureMove_Project_Report.md'),
  [string]$OutputDocx = (Join-Path $PSScriptRoot '..\docs\SecureMove_Project_Report.docx')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Escape-Xml([string]$Text) {
  if ($null -eq $Text) { return '' }
  return [System.Security.SecurityElement]::Escape($Text)
}

function New-Run([string]$Text, [bool]$Bold = $false, [int]$Size = 24) {
  $escaped = Escape-Xml $Text
  $boldXml = if ($Bold) { '<w:b/>' } else { '' }
  return "<w:r><w:rPr>$boldXml<w:sz w:val=`"$Size`"/><w:szCs w:val=`"$Size`"/></w:rPr><w:t xml:space=`"preserve`">$escaped</w:t></w:r>"
}

function New-Paragraph([string]$Text, [string]$Style = '', [bool]$Bold = $false, [string]$Align = '', [int]$Size = 24) {
  $styleXml = if ($Style) { "<w:pStyle w:val=`"$Style`"/>" } else { '' }
  $alignXml = if ($Align) { "<w:jc w:val=`"$Align`"/>" } else { '' }
  $pPr = if ($styleXml -or $alignXml) { "<w:pPr>$styleXml$alignXml</w:pPr>" } else { '' }
  return "<w:p>$pPr$(New-Run $Text $Bold $Size)</w:p>"
}

function New-Table([array]$Rows) {
  $tbl = New-Object System.Text.StringBuilder
  [void]$tbl.Append('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:left w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:right w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/></w:tblBorders></w:tblPr>')
  for ($r = 0; $r -lt $Rows.Count; $r++) {
    [void]$tbl.Append('<w:tr>')
    foreach ($cell in $Rows[$r]) {
      $isHeader = $r -eq 0
      $shade = if ($isHeader) { '<w:shd w:fill="EAF0F8"/>' } else { '' }
      [void]$tbl.Append("<w:tc><w:tcPr><w:tcW w:w=`"2400`" w:type=`"dxa`"/>$shade</w:tcPr>")
      [void]$tbl.Append((New-Paragraph $cell '' $isHeader '' 21))
      [void]$tbl.Append('</w:tc>')
    }
    [void]$tbl.Append('</w:tr>')
  }
  [void]$tbl.Append('</w:tbl>')
  return $tbl.ToString()
}

function Split-TableRow([string]$Line) {
  $trimmed = $Line.Trim()
  if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
  if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
  return @($trimmed -split '\|' | ForEach-Object { $_.Trim() })
}

function Is-TableSeparator([string]$Line) {
  return $Line.Trim() -match '^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$'
}

function Add-ZipEntry($Archive, [string]$Name, [string]$Content) {
  $entry = $Archive.CreateEntry($Name)
  $stream = $entry.Open()
  $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
  $writer.Write($Content)
  $writer.Dispose()
  $stream.Dispose()
}

if (-not (Test-Path -LiteralPath $MarkdownPath)) {
  throw "Markdown file not found: $MarkdownPath"
}

$lines = Get-Content -LiteralPath $MarkdownPath
$body = New-Object System.Text.StringBuilder
$i = 0

while ($i -lt $lines.Count) {
  $line = $lines[$i]
  $trim = $line.Trim()

  if ($trim.Length -eq 0) {
    [void]$body.Append('<w:p/>')
    $i++
    continue
  }

  if ($trim.StartsWith('|') -and ($i + 1) -lt $lines.Count -and (Is-TableSeparator $lines[$i + 1])) {
    $rows = New-Object System.Collections.Generic.List[object]
    $rows.Add((Split-TableRow $trim))
    $i += 2
    while ($i -lt $lines.Count -and $lines[$i].Trim().StartsWith('|')) {
      $rows.Add((Split-TableRow $lines[$i]))
      $i++
    }
    [void]$body.Append((New-Table $rows.ToArray()))
    continue
  }

  if ($trim -match '^(#{1,6})\s+(.+)$') {
    $level = $Matches[1].Length
    $text = $Matches[2].Trim()
    if ($level -eq 1) {
      [void]$body.Append((New-Paragraph $text 'Heading1' $true 'center' 32))
    } elseif ($level -eq 2) {
      [void]$body.Append((New-Paragraph $text 'Heading2' $true '' 28))
    } else {
      [void]$body.Append((New-Paragraph $text 'Heading3' $true '' 25))
    }
    $i++
    continue
  }

  if ($trim -match '^-\s+(.+)$') {
    [void]$body.Append((New-Paragraph ("- " + $Matches[1].Trim()) '' $false '' 23))
    $i++
    continue
  }

  if ($trim -match '^\d+\.\s+(.+)$') {
    [void]$body.Append((New-Paragraph $trim '' $false '' 23))
    $i++
    continue
  }

  $paragraph = $trim
  $i++
  while ($i -lt $lines.Count -and $lines[$i].Trim().Length -gt 0 -and -not $lines[$i].Trim().StartsWith('#') -and -not $lines[$i].Trim().StartsWith('|') -and -not ($lines[$i].Trim() -match '^-\s+')) {
    $paragraph += ' ' + $lines[$i].Trim()
    $i++
  }
  [void]$body.Append((New-Paragraph $paragraph '' $false '' 23))
}

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    $($body.ToString())
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="360" w:after="240"/><w:outlineLvl w:val="0"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="32"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="240" w:after="160"/><w:outlineLvl w:val="1"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="200" w:after="120"/><w:outlineLvl w:val="2"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="25"/></w:rPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:color="auto"/><w:left w:val="single" w:sz="4" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:color="auto"/><w:right w:val="single" w:sz="4" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:color="auto"/></w:tblBorders></w:tblPr>
  </w:style>
</w:styles>
'@

$contentTypesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>
'@

$relsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@

$documentRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
'@

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDocx)
$outputDir = [System.IO.Path]::GetDirectoryName($resolvedOutput)
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$fileStream = [System.IO.File]::Open($resolvedOutput, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite)
try {
  $archive = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Add-ZipEntry $archive '[Content_Types].xml' $contentTypesXml
    Add-ZipEntry $archive '_rels/.rels' $relsXml
    Add-ZipEntry $archive 'word/document.xml' $documentXml
    Add-ZipEntry $archive 'word/styles.xml' $stylesXml
    Add-ZipEntry $archive 'word/_rels/document.xml.rels' $documentRelsXml
  } finally {
    $archive.Dispose()
  }
} finally {
  $fileStream.Dispose()
}

Write-Host "Created $resolvedOutput"
