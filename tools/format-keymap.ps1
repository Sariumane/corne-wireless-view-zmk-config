param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$TOKEN_WIDTH = 12
$INDENT_LINE = "   "
$INDENT_CLOSE = "                        "

$txt = Get-Content -Raw -Encoding UTF8 $Path

function Format-OneLineBindings($body) {
  $b = $body -replace "[`r`n`t]", " "
  $b = $b -replace "\s+", " "
  $b = $b -replace ">\s*,\s*<", " "
  $b = $b -replace "\s*,\s*", " "
  return $b.Trim()
}

function Pad($s) {
  $w = [Math]::Max($TOKEN_WIDTH, $s.Length)
  return $s.PadRight($w)
}


function Format-KeymapBindings($body) {
  $b = $body -replace "[`r`n`t]", " "
  $b = $b -replace "\s+", " "
  $b = $b.Trim()

  $tokens = @()
  foreach ($p in ($b -split "\s+(?=&)")) {
    $t = $p.Trim()
    if ($t -ne "") { $tokens += $t }
  }

  if ($tokens.Count -lt 1) { return $body }

  # Build rows: 12, 12, 12, remainder
  $rows = @()
  $idx = 0
  foreach ($n in @(12,12,12)) {
    if ($idx -ge $tokens.Count) { break }
    $take = [Math]::Min($n, $tokens.Count - $idx)
    $rows += ,($tokens[$idx..($idx+$take-1)])
    $idx += $take
  }
  if ($idx -lt $tokens.Count) {
    $rows += ,($tokens[$idx..($tokens.Count-1)])
  }

  # Compute max width per column across ALL rows (so KP_MULTIPLY doesn't break alignment)
  $maxCols = ($rows | Measure-Object -Property Length -Maximum).Maximum
  $colWidths = @(0) * $maxCols

  for ($c = 0; $c -lt $maxCols; $c++) {
    $w = 0
    foreach ($r in $rows) {
      if ($c -lt $r.Length) {
        $w = [Math]::Max($w, $r[$c].Length)
      }
    }
    # add 1 space padding between columns
    $colWidths[$c] = $w
  }

  $lines = @()
  foreach ($r in $rows) {
    $parts = @()
    for ($c = 0; $c -lt $r.Length; $c++) {
      $parts += $r[$c].PadRight($colWidths[$c] + 1)
    }
    $lines += ($parts -join "").TrimEnd()
  }

  $out = "`n"
  foreach ($l in $lines) {
    $out += "$INDENT_LINE$l`n"
  }
  $out += $INDENT_CLOSE
  return $out
}



$txt = [regex]::Replace(
  $txt,
  '(?s)\bbindings\s*=\s*<\s*(.*?)\s*>\s*;',
  {
    param($m)
    $inner = $m.Groups[1].Value
    $isBehavior = ($inner -match ">\s*,\s*<") -or ($inner.Length -lt 120)
    if ($isBehavior) {
      $norm = Format-OneLineBindings $inner
      return "bindings = <$norm>;"
    } else {
      $norm = Format-KeymapBindings $inner
      return "bindings = <$norm>;"
    }
  }
)

Set-Content -Encoding UTF8 -NoNewline -Path $Path -Value $txt
