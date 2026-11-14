param(
  [Alias('b')][string]$Book = '',
  [Alias('g')][int]$Group = 0,
  [Alias('s')][int]$Size = 20,
  [Alias('d')][switch]$Dictation,
  [Alias('m')][switch]$Mute,
  [Alias('f')][string]$File = '',
  [Alias('l')][switch]$List,
  [Alias('h')][switch]$Help
)

$ErrorActionPreference = 'Stop'
$DictsDir = Join-Path $PSScriptRoot 'dicts'
$LegacyStateFile = Join-Path $env:USERPROFILE '.yanxing-state.json'
$DbPath = Join-Path $env:USERPROFILE '.yanxing\yanxing.db'

$Catalog = @(
  @{ id = 'xiaoxue6';   name = '小学英语 (PEP)';     file = 'xiaoxue6.json';        type = 'word' },
  @{ id = 'zhongkao';   name = '初中 / 中考核心';    file = 'zhongkao.json';        type = 'word' },
  @{ id = 'ket2021';    name = '剑桥 KET (2021)';    file = 'ket2021.json';         type = 'word' },
  @{ id = 'pet2024';    name = '剑桥 PET (2024)';    file = 'pet2024.json';         type = 'word' },
  @{ id = 'gaokao3500'; name = '高考 3500 词';       file = 'gaokao3500.json';      type = 'word' },
  @{ id = 'cet4';       name = '大学四级 CET-4';     file = 'cet4.json';            type = 'word' },
  @{ id = 'cet6';       name = '大学六级 CET-6';     file = 'cet6.json';            type = 'word' },
  @{ id = 'ielts';      name = '雅思 IELTS';         file = 'ielts.json';           type = 'word' },
  @{ id = 'nce1';       name = '新概念 1 句子库';    file = 'nce1-sentences.json';  type = 'sentence-name' },
  @{ id = 'nce2';       name = '新概念 2 句子库';    file = 'nce2-sentences.json';  type = 'sentence-name' },
  @{ id = 'nce3';       name = '新概念 3 句子库';    file = 'nce3-sentences.json';  type = 'sentence-name' },
  @{ id = 'nce4';       name = '新概念 4 句子库';    file = 'nce4-sentences.json';  type = 'sentence-name' },
  @{ id = 'ielts900';   name = '雅思口语 900 句';    file = 'ielts-oral-900.json';  type = 'sentence-name' },
  @{ id = 's4000';      name = '4000 核心例句库';    file = 'sentences4000.json';   type = 'sentence-trans' }
)

if ($Help) {
  Write-Host "`n言行打字听写 TUI（双栏工作区 · CJK 精确增量渲染 · 按键/鼠标交互）`n" -ForegroundColor Cyan
  Write-Host "用法：yanxing [-b <id>] [-g <n>] [-s <n>] [-d] [-m] [-f <path>] [-l]"
  Write-Host "快捷键（支持鼠标直接点击）："
  Write-Host "  F1 / Ctrl+B  切换词库    |  F2 / Ctrl+G  切换分组"
  Write-Host "  F3 / Ctrl+M  跟打/听写   |  F4 / Ctrl+V  语音开关"
  Write-Host "  F5           错题本练习  |  F6           乱序当前组"
  Write-Host "  Ctrl+L       导入文本    |  Ctrl+A       AI 生成词库"
  Write-Host "  Enter        重听发音    |  Tab          显隐拼写"
  Write-Host "  PgUp/PgDn    上/下一词   |  Esc / Ctrl+C 退出`n"
  return
}

if ($List) {
  Write-Host "`n可用内置词库 / 句库：" -ForegroundColor Cyan
  foreach ($item in $Catalog) {
    $tag = if ($item.type -eq 'word') { '单词' } else { '句子' }
    Write-Host ("  {0,-12} [{1}] {2}" -f $item.id, $tag, $item.name)
  }
  Write-Host ""
  return
}

# ── 终端编码与 ANSI 序列 ──
try {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
} catch {}
$E = [char]27
$C_RESET  = "$E[0m"
$C_BOLD   = "$E[1m"
$C_DIM    = "$E[2m"
$C_UNDER  = "$E[4m"
$C_RED    = "$E[31m"
$C_GREEN  = "$E[32m"
$C_YELLOW = "$E[33m"
$C_CYAN   = "$E[36m"
$C_WHITE  = "$E[37m"
$C_BORDER = "$E[38;5;240m"
$C_BG_BAR = "$E[48;5;236m"
$C_BG_SEL = "$E[48;5;24m"

# ── CJK 精确显示宽度原语（解决中文占 2 列导致的换行与错位） ──
function Get-CharWidth([char]$ch) {
  $code = [int]$ch
  if ($code -ge 0x1100 -and (
      $code -le 0x115F -or
      ($code -ge 0x2E80 -and $code -le 0xA4CF -and $code -ne 0x303F) -or
      ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
      ($code -ge 0xF900 -and $code -le 0xFAFF) -or
      ($code -ge 0xFE10 -and $code -le 0xFE19) -or
      ($code -ge 0xFE30 -and $code -le 0xFE6F) -or
      ($code -ge 0xFF00 -and $code -le 0xFF60) -or
      ($code -ge 0xFFE0 -and $code -le 0xFFE6)
  )) { return 2 }
  return 1
}

function Get-DisplayWidth([string]$s) {
  if ([string]::IsNullOrEmpty($s)) { return 0 }
  $plain = $s -replace "\x1b\[[0-9;]*m", ""
  $w = 0
  foreach ($ch in $plain.ToCharArray()) { $w += (Get-CharWidth $ch) }
  return $w
}

function Fit-Plain([string]$s, [int]$maxCols) {
  if ($maxCols -le 0) { return '' }
  $sb = [System.Text.StringBuilder]::new()
  $w = 0
  foreach ($ch in $s.ToCharArray()) {
    $cw = Get-CharWidth $ch
    if ($w + $cw -gt $maxCols) { break }
    [void]$sb.Append($ch)
    $w += $cw
  }
  if ($w -lt $maxCols) { [void]$sb.Append(' ' * ($maxCols - $w)) }
  return $sb.ToString()
}

function Wrap-Plain([string]$s, [int]$maxCols) {
  $res = [System.Collections.Generic.List[string]]::new()
  if ([string]::IsNullOrEmpty($s) -or $maxCols -lt 4) { $res.Add(''); return ,$res }
  $cur = [System.Text.StringBuilder]::new()
  $w = 0
  foreach ($ch in $s.ToCharArray()) {
    $cw = Get-CharWidth $ch
    if ($w + $cw -gt $maxCols) {
      $res.Add($cur.ToString())
      $cur = [System.Text.StringBuilder]::new()
      $w = 0
    }
    [void]$cur.Append($ch)
    $w += $cw
  }
  if ($cur.Length -gt 0) { $res.Add($cur.ToString()) }
  return ,$res
}

# ── 进程内语音 ──
$Voice = $null
try { $Voice = New-Object -ComObject SAPI.SpVoice } catch { $Voice = $null }
$SoundOn = -not $Mute

function Speak-Text([string]$text) {
  if (-not $SoundOn -or $null -eq $Voice -or [string]::IsNullOrWhiteSpace($text)) { return }
  try { $null = $Voice.Speak($text, 3) } catch {}
}

# ── 统一 SQLite 数据库（与言行 App 共用 yanxing-user-1.db，进程内调用 winsqlite3.dll） ──
$script:SqliteReady = $false
try {
  if (-not ('WinSqlite' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WinSqlite {
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_open_v2(byte[] filename, out IntPtr db, int flags, IntPtr zVfs);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int nByte, out IntPtr stmt, out IntPtr tail);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_step(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_column_text(IntPtr stmt, int iCol);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_bind_text(IntPtr stmt, int idx, byte[] val, int nByte, IntPtr destructor);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_bind_int64(IntPtr stmt, int idx, long val);

    public static string PtrToUtf8(IntPtr p) {
        if (p == IntPtr.Zero) return "";
        int len = 0;
        while (Marshal.ReadByte(p, len) != 0) len++;
        byte[] buf = new byte[len];
        Marshal.Copy(p, buf, 0, len);
        return Encoding.UTF8.GetString(buf);
    }
}
"@
  }
  $dbDir = Split-Path $DbPath -Parent
  if (-not (Test-Path $dbDir)) { $null = New-Item -ItemType Directory -Path $dbDir -Force }
  $script:SqliteReady = $true
} catch { $script:SqliteReady = $false }

function Invoke-DbQuery([string]$sql, [object[]]$params = @()) {
  $rows = [System.Collections.Generic.List[object[]]]::new()
  if (-not $script:SqliteReady) { return ,$rows }
  $db = [IntPtr]::Zero
  if ([WinSqlite]::sqlite3_open_v2([System.Text.Encoding]::UTF8.GetBytes($DbPath + "`0"), [ref]$db, 6, [IntPtr]::Zero) -ne 0) { return ,$rows }
  try {
    foreach ($pSql in @('PRAGMA busy_timeout=3000;', $sql)) {
      $stmt = [IntPtr]::Zero; $tail = [IntPtr]::Zero
      if ([WinSqlite]::sqlite3_prepare_v2($db, [System.Text.Encoding]::UTF8.GetBytes($pSql + "`0"), -1, [ref]$stmt, [ref]$tail) -eq 0) {
        try {
          if ($pSql -eq $sql) {
            for ($i = 0; $i -lt $params.Count; $i++) {
              $pv = $params[$i]
              if ($pv -is [long] -or $pv -is [int]) {
                [void][WinSqlite]::sqlite3_bind_int64($stmt, $i + 1, [long]$pv)
              } else {
                $b = [System.Text.Encoding]::UTF8.GetBytes([string]$pv)
                [void][WinSqlite]::sqlite3_bind_text($stmt, $i + 1, $b, $b.Length, [IntPtr]::new(-1))
              }
            }
          }
          while ([WinSqlite]::sqlite3_step($stmt) -eq 100) {
            if ($pSql -eq $sql) {
              $cols = @()
              for ($c = 0; $c -lt 4; $c++) {
                $p = [WinSqlite]::sqlite3_column_text($stmt, $c)
                if ($p -eq [IntPtr]::Zero -and $c -gt 0) { break }
                $cols += [WinSqlite]::PtrToUtf8($p)
              }
              $rows.Add($cols)
            }
          }
        } finally { [void][WinSqlite]::sqlite3_finalize($stmt) }
      }
    }
  } finally { [void][WinSqlite]::sqlite3_close($db) }
  return ,$rows
}

if ($script:SqliteReady) {
  $null = Invoke-DbQuery "CREATE TABLE IF NOT EXISTS user_setting (setting_key TEXT PRIMARY KEY, value TEXT NOT NULL, edit_time INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 0);"
}

$Persisted = @{
  book     = 'ket2021'
  group    = 1
  mistakes = @()
  aiUrl    = 'http://localhost:11434/v1'
  aiKey    = ''
  aiModel  = 'qwen2.5:7b'
}

$dbStateRows = Invoke-DbQuery "SELECT value FROM user_setting WHERE setting_key = ?;" @('cli.typing.state')
$rawStateJson = if ($dbStateRows.Count -gt 0 -and $dbStateRows[0].Count -gt 0) { $dbStateRows[0][0] } elseif (Test-Path $LegacyStateFile) { Get-Content $LegacyStateFile -Raw -Encoding UTF8 } else { '' }
if ($rawStateJson) {
  try {
    $loaded = $rawStateJson | ConvertFrom-Json
    if ($loaded.book)    { $Persisted.book = [string]$loaded.book }
    if ($loaded.group)   { $Persisted.group = [int]$loaded.group }
    if ($loaded.aiUrl)   { $Persisted.aiUrl = [string]$loaded.aiUrl }
    if ($loaded.aiKey)   { $Persisted.aiKey = [string]$loaded.aiKey }
    if ($loaded.aiModel) { $Persisted.aiModel = [string]$loaded.aiModel }
    if ($loaded.mistakes) {
      $Persisted.mistakes = @($loaded.mistakes | ForEach-Object {
        @{ target = [string]$_.target; phonetic = [string]$_.phonetic; meaning = [string]$_.meaning }
      })
    }
  } catch {}
}

function Save-State {
  try {
    $obj = @{
      book     = $State.DeckId
      group    = $State.Group
      aiUrl    = $Persisted.aiUrl
      aiKey    = $Persisted.aiKey
      aiModel  = $Persisted.aiModel
      mistakes = $Persisted.mistakes
    }
    $json = $obj | ConvertTo-Json -Depth 4 -Compress
    $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $null = Invoke-DbQuery "INSERT INTO user_setting (setting_key, value, edit_time, dirty) VALUES (?, ?, ?, 0) ON CONFLICT(setting_key) DO UPDATE SET value=excluded.value, edit_time=excluded.edit_time;" @('cli.typing.state', $json, $nowMs)
  } catch {}
}

# ── 词库加载 ──
$DeckCache = @{}
function Load-DeckEntries($meta) {
  if ($meta.type -eq 'wordbook') {
    $list = [System.Collections.Generic.List[object]]::new()
    $rows = Invoke-DbQuery "SELECT d.term, COALESCE(d.us_phonetic, d.uk_phonetic, ''), COALESCE(d.ec, '') FROM user_word uw JOIN dict d ON uw.dict_id = d.dict_id WHERE uw.is_deleted = 0 ORDER BY uw.join_time DESC LIMIT 500;"
    foreach ($r in $rows) {
      if ($r[0]) {
        $ph = if ($r[1]) { "/$($r[1].Trim('/'))/" } else { '' }
        $list.Add(@{ target = $r[0]; phonetic = $ph; meaning = '来自言行 App 生词本' })
      }
    }
    return ,$list
  }
  if ($DeckCache.ContainsKey($meta.id)) { return ,$DeckCache[$meta.id] }
  $path = Join-Path $DictsDir $meta.file
  if (-not (Test-Path $path)) { throw "找不到词库文件：$path" }
  $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
  $list = [System.Collections.Generic.List[object]]::new()
  foreach ($item in $raw) {
    $name = [string]$item.name
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    $name = $name.Trim()
    $phone = if ($item.usphone) { [string]$item.usphone } elseif ($item.ukphone) { [string]$item.ukphone } else { '' }
    $phone = $phone.Trim()
    $phonetic = if ($phone) { if ($phone.StartsWith('/')) { $phone } else { "/$phone/" } } else { '' }
    $transText = if ($item.trans) { ($item.trans | Where-Object { $_ }) -join '；' } else { '' }

    if ($meta.type -eq 'sentence-name') {
      $lesson = if ($item.lesson) { "[$($item.lesson)]" } else { '' }
      $list.Add(@{ target = $name; phonetic = $lesson; meaning = $(if ($transText) { $transText } else { '双语句子' }) })
    } elseif ($meta.type -eq 'sentence-trans') {
      if ($transText) { $list.Add(@{ target = $transText; phonetic = $phonetic; meaning = "关键词：$name" }) }
    } else {
      $list.Add(@{ target = $name; phonetic = $phonetic; meaning = $(if ($transText) { $transText } else { '暂无释义' }) })
    }
  }
  $DeckCache[$meta.id] = $list
  return ,$list
}

function Parse-TextToEntries([string]$content) {
  $lines = $content -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
  $list = [System.Collections.Generic.List[object]]::new()
  if ($lines | Where-Object { $_ -match '\||\t' } | Select-Object -First 1) {
    foreach ($l in $lines) {
      $parts = $l -split '\||\t'
      if ($parts[0].Trim()) {
        $list.Add(@{
          target   = $parts[0].Trim()
          phonetic = if ($parts.Count -gt 2) { $parts[2].Trim() } else { '' }
          meaning  = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '自定义词条' }
        })
      }
    }
    return ,$list
  }
  $flat = ($content -replace "`r?`n+", ' ')
  $sentences = [regex]::Split($flat, '(?<=[.!?])\s+') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 1 }
  $i = 1
  foreach ($s in $sentences) {
    $list.Add(@{ target = $s; phonetic = ''; meaning = "自定义句子 #$i" })
    $i++
  }
  return ,$list
}

function Invoke-AiDeck([string]$topic) {
  $base = $Persisted.aiUrl.TrimEnd('/')
  $endpoint = if ($base.EndsWith('/chat/completions')) { $base } else { "$base/chat/completions" }
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($Persisted.aiKey) { $headers['Authorization'] = "Bearer $($Persisted.aiKey)" }
  $body = @{
    model = $Persisted.aiModel
    temperature = 0.4
    messages = @(
      @{ role = 'system'; content = '只输出 JSON 数组，不要 markdown 代码块。' },
      @{ role = 'user'; content = "围绕「$topic」生成 12 个英语学习词条或例句，JSON 格式：[{""target"":""英文"",""phonetic"":""/音标/"",""meaning"":""中文释义""}]" }
    )
  } | ConvertTo-Json -Depth 5
  $res = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 30
  $txt = [string]$res.choices[0].message.content
  $s = $txt.IndexOf('['); $e = $txt.LastIndexOf(']')
  if ($s -lt 0 -or $e -le $s) { throw 'AI 未返回有效 JSON 数组' }
  $arr = $txt.Substring($s, $e - $s + 1) | ConvertFrom-Json
  $list = [System.Collections.Generic.List[object]]::new()
  foreach ($x in $arr) {
    if ($x.target) {
      $list.Add(@{ target = [string]$x.target; phonetic = [string]$x.phonetic; meaning = [string]$x.meaning })
    }
  }
  return ,$list
}

# ── 应用状态 ──
if ($Size -lt 1) { $Size = 20 }
$initBook = if ($Book) { $Book } else { $Persisted.book }
$initGroup = if ($Group -gt 0) { $Group } else { $Persisted.group }

$State = [ordered]@{
  Title       = ''
  DeckId      = $initBook
  Entries     = $null
  Group       = $initGroup
  TotalGroups = 1
  Items       = @()
  DoneSet     = @{}
  Index       = 0
  Typed       = ''
  HasError    = $false
  WordWrong   = $false
  Peek        = $false
  Dictation   = [bool]$Dictation
  CorrectKeys = 0
  TotalKeys   = 0
  Streak      = 0
  MaxStreak   = 0
  StartTime   = $null
  Finished    = $false
  StatusMsg   = '就绪 · 直接输入即可开始'
  Overlay     = 'none'   # 'none' | 'list' | 'input-file' | 'input-ai'
  ListKind    = ''       # 'deck' | 'group'
  ListTitle   = ''
  ListHint    = ''
  ListItems   = @()
  PromptBuf   = ''
  CursorIdx   = 0
  ScrollTop   = 0
}

function Set-Group([int]$groupNum) {
  $total = [Math]::Max(1, [int][Math]::Ceiling($State.Entries.Count / $Size))
  $safe = [Math]::Max(1, [Math]::Min($total, $groupNum))
  $s = ($safe - 1) * $Size
  $e = [Math]::Min($State.Entries.Count - 1, $s + $Size - 1)
  $State.TotalGroups = $total
  $State.Group = $safe
  $State.Items = if ($s -le $e) { @($State.Entries[$s..$e]) } else { @() }
  $State.DoneSet = @{}
  $State.Index = 0
  $State.Typed = ''
  $State.HasError = $false
  $State.WordWrong = $false
  $State.Peek = $false
  $State.CorrectKeys = 0
  $State.TotalKeys = 0
  $State.Streak = 0
  $State.StartTime = $null
  $State.Finished = $false
  if ($State.DeckId -ne 'mistakes' -and $State.DeckId -ne 'custom' -and $State.DeckId -ne 'ai') {
    Save-State
  }
}

function Select-DeckAndGroup([string]$deckId, [int]$groupNum) {
  $meta = $Catalog | Where-Object { $_.id -ieq $deckId } | Select-Object -First 1
  if (-not $meta) { $meta = $Catalog[2] }
  $entries = Load-DeckEntries $meta
  $State.DeckId = $meta.id
  $State.Title = $meta.name
  $State.Entries = $entries
  Set-Group $groupNum
  $State.StatusMsg = "已切换词库：$($meta.name)（共 $($entries.Count) 条）"
}

function Add-Mistake($item) {
  $exists = $Persisted.mistakes | Where-Object { $_.target -eq $item.target } | Select-Object -First 1
  if (-not $exists) {
    $Persisted.mistakes = @($Persisted.mistakes) + @(@{
      target = $item.target; phonetic = $item.phonetic; meaning = $item.meaning
    })
    Save-State
  }
}

if ($File) {
  $State.Entries = Parse-TextToEntries (Get-Content (Resolve-Path $File) -Raw -Encoding UTF8)
  $State.Title = Split-Path $File -Leaf
  $State.DeckId = 'custom'
  Set-Group ([Math]::Max(1, $initGroup))
} else {
  Select-DeckAndGroup $initBook $initGroup
}

# ── 增量行缓冲渲染器（全行定宽覆写，CJK 精确对齐，零残留） ──
$PrevLines = [System.Collections.Generic.Dictionary[int, string]]::new()
$LastWidth = 0
$LastHeight = 0
$Hitboxes = [System.Collections.Generic.List[object]]::new()

function Build-TargetLines($item, [int]$innerW, [bool]$show) {
  $target = $item.target
  $res = [System.Collections.Generic.List[string]]::new()
  $sb = [System.Text.StringBuilder]::new()
  $col = 0
  for ($i = 0; $i -lt $target.Length; $i++) {
    $ch = $target[$i]
    $cw = Get-CharWidth $ch
    if ($col + $cw -gt $innerW) {
      $pad = ' ' * ($innerW - $col)
      $res.Add($sb.ToString() + $pad)
      $sb = [System.Text.StringBuilder]::new()
      $col = 0
    }
    if ($i -lt $State.Typed.Length) {
      [void]$sb.Append("$C_GREEN$ch$C_RESET")
    } elseif ($i -eq $State.Typed.Length) {
      $disp = if ($ch -eq ' ') { ' ' } elseif ($show) { $ch } else { '_' }
      $c = if ($State.HasError) { "$C_RED$C_UNDER" } else { "$C_BOLD$C_UNDER" }
      [void]$sb.Append("$c$disp$C_RESET")
    } else {
      $disp = if ($ch -eq ' ') { ' ' } elseif ($show) { $ch } else { '_' }
      [void]$sb.Append("$C_DIM$disp$C_RESET")
    }
    $col += $cw
  }
  $pad = ' ' * ($innerW - $col)
  $res.Add($sb.ToString() + $pad)
  return ,$res
}

function Render-Frame {
  $w = [Math]::Max(24, [Console]::WindowWidth)
  $h = [Math]::Max(10, [Console]::WindowHeight)
  if ($w -ne $script:LastWidth -or $h -ne $script:LastHeight) {
    $script:PrevLines.Clear()
    $script:LastWidth = $w
    $script:LastHeight = $h
  }

  $lines = [string[]]::new($h)
  $script:Hitboxes.Clear()

  $acc = if ($State.TotalKeys -eq 0) { 100 } else { [Math]::Round(($State.CorrectKeys / $State.TotalKeys) * 100) }
  $elapsedMin = if ($State.StartTime) { [Math]::Max(((Get-Date) - $State.StartTime).TotalMinutes, 0.05) } else { 0.05 }
  $wpm = if ($State.StartTime) { [Math]::Round(($State.CorrectKeys / 5.0) / $elapsedMin) } else { 0 }

  # ── 顶栏（自动换行，小窗口也不截断按钮） ──
  $modeText  = if ($State.Dictation) { '听写' } else { '跟打' }
  $soundText = if ($script:SoundOn) { '开' } else { '关' }
  $mCount    = $Persisted.mistakes.Count
  $deckLabel = if ($w -lt 70 -and (Get-DisplayWidth $State.Title) -gt 10) {
    (Fit-Plain $State.Title 8).TrimEnd() + '..'
  } else { $State.Title }
  $topItems = @(
    @{ text = ' 言行 ';                                      color = "$C_BOLD$C_CYAN"; action = '' },
    @{ text = "[F1 词库:$deckLabel]";                        color = $C_YELLOW;        action = 'open-deck' },
    @{ text = "[F2 组:$($State.Group)/$($State.TotalGroups)]"; color = $C_CYAN;        action = 'open-group' },
    @{ text = "[F3 $modeText]";                              color = $C_GREEN;         action = 'toggle-mode' },
    @{ text = "[F4 音:$soundText]";                          color = $C_WHITE;         action = 'toggle-sound' },
    @{ text = "[F5 错:$mCount]";                             color = $C_RED;           action = 'open-mistakes' }
  )
  $topRows = [System.Collections.Generic.List[string]]::new()
  $topPendingHbs = [System.Collections.Generic.List[object]]::new()
  $topSb = [System.Text.StringBuilder]::new($C_BG_BAR)
  $tx = 0
  foreach ($ti in $topItems) {
    $tw = Get-DisplayWidth $ti.text
    $needSpace = if ($tx -gt 0) { 1 } else { 0 }
    if ($tx -gt 0 -and ($tx + $needSpace + $tw -gt $w)) {
      $topRows.Add($topSb.ToString() + (' ' * [Math]::Max(0, $w - $tx)) + $C_RESET)
      $topSb = [System.Text.StringBuilder]::new("$C_BG_BAR ")
      $tx = 1
      $needSpace = 0
    }
    if ($needSpace -gt 0) { [void]$topSb.Append(' '); $tx++ }
    if ($tx + $tw -gt $w) {
      $clipped = Fit-Plain $ti.text ($w - $tx)
      [void]$topSb.Append("$($ti.color)$clipped$C_RESET$C_BG_BAR")
      if ($ti.action) { $topPendingHbs.Add(@{ row = $topRows.Count; x1 = $tx + 1; x2 = $w; action = $ti.action }) }
      $tx = $w
    } else {
      [void]$topSb.Append("$($ti.color)$($ti.text)$C_RESET$C_BG_BAR")
      if ($ti.action) { $topPendingHbs.Add(@{ row = $topRows.Count; x1 = $tx + 1; x2 = $tx + $tw; action = $ti.action }) }
      $tx += $tw
    }
  }
  $topRows.Add($topSb.ToString() + (' ' * [Math]::Max(0, $w - $tx)) + $C_RESET)
  for ($tr = 0; $tr -lt $topRows.Count -and $tr -lt $h; $tr++) { $lines[$tr] = $topRows[$tr] }
  foreach ($hb in $topPendingHbs) {
    $script:Hitboxes.Add(@{ y = 1 + $hb.row; x1 = $hb.x1; x2 = $hb.x2; action = $hb.action })
  }

  # ── 底部快捷键与鼠标栏（自动换行，小窗口也不截断按钮） ──
  $btns = @(
    @{ text = '[Enter 朗读]';  action = 'speak' },
    @{ text = '[Tab 提示]';    action = 'peek' },
    @{ text = '[PgUp 上词]';   action = 'prev-word' },
    @{ text = '[PgDn 下词]';   action = 'next-word' },
    @{ text = '[F6 乱序]';     action = 'shuffle' },
    @{ text = '[Ctrl+L 导入]'; action = 'open-file' },
    @{ text = '[Ctrl+A AI]';   action = 'open-ai' },
    @{ text = '[Esc 退出]';    action = 'exit' }
  )
  $botRows = [System.Collections.Generic.List[string]]::new()
  $botPendingHbs = [System.Collections.Generic.List[object]]::new()
  $botSb = [System.Text.StringBuilder]::new("$C_BG_BAR ")
  $bx = 1
  foreach ($b in $btns) {
    $bw = Get-DisplayWidth $b.text
    $needSpace = if ($bx -gt 1) { 2 } else { 0 }
    if ($bx -gt 1 -and ($bx + $needSpace + $bw -gt $w)) {
      $botRows.Add($botSb.ToString() + (' ' * [Math]::Max(0, $w - $bx)) + $C_RESET)
      $botSb = [System.Text.StringBuilder]::new("$C_BG_BAR ")
      $bx = 1
      $needSpace = 0
    }
    if ($needSpace -gt 0) { [void]$botSb.Append("$C_DIM  "); $bx += 2 }
    if ($bx + $bw -le $w) {
      [void]$botSb.Append("$C_WHITE$($b.text)$C_RESET$C_BG_BAR")
      $botPendingHbs.Add(@{ row = $botRows.Count; x1 = $bx + 1; x2 = $bx + $bw; action = $b.action })
      $bx += $bw
    }
  }
  $botRows.Add($botSb.ToString() + (' ' * [Math]::Max(0, $w - $bx)) + $C_RESET)
  $botStartIdx = [Math]::Max($topRows.Count + 1, $h - $botRows.Count)
  for ($br = 0; $br -lt $botRows.Count -and ($botStartIdx + $br) -lt $h; $br++) {
    $lines[$botStartIdx + $br] = $botRows[$br]
  }
  foreach ($hb in $botPendingHbs) {
    $script:Hitboxes.Add(@{ y = $botStartIdx + 1 + $hb.row; x1 = $hb.x1; x2 = $hb.x2; action = $hb.action })
  }

  # ── 响应式主体尺寸 ──
  $hasSide = ($w -ge 80)
  $sideW = if ($hasSide) { [Math]::Max(26, [Math]::Min(36, [int]($w * 0.30))) } else { 0 }
  $mainW = if ($hasSide) { $w - $sideW - 1 } else { $w }
  $mainInner = [Math]::Max(10, $mainW - 4)
  $sideInner = [Math]::Max(10, $sideW - 4)
  $bodyStartIdx = $topRows.Count
  $statusIdx = $botStartIdx - 1
  $bodyRows = [Math]::Max(3, $statusIdx - $bodyStartIdx)

  # 预构建左栏内容（固定 $bodyRows 行）
  $leftBuf = [System.Collections.Generic.List[string]]::new()
  $leftTitle = if ($State.Overlay -eq 'list') { " $($State.ListTitle) " }
               elseif ($State.Overlay -eq 'input-file') { ' 导入本地文本 ' }
               elseif ($State.Overlay -eq 'input-ai') { ' AI 生成词库 ' }
               else { ' 练习区 ' }
  $ltPad = '─' * [Math]::Max(0, $mainW - 3 - (Get-DisplayWidth $leftTitle))
  $leftBuf.Add("$C_BORDER╭─$C_CYAN$C_BOLD$leftTitle$C_RESET$C_BORDER$ltPad╮$C_RESET")

  $leftContent = [System.Collections.Generic.List[string]]::new()
  $contentH = [Math]::Max(1, $bodyRows - 2)

  if ($State.Overlay -eq 'list') {
    foreach ($hl in (Wrap-Plain $State.ListHint $mainInner)) { $leftContent.Add((Fit-Plain $hl $mainInner)) }
    $headCount = $leftContent.Count + 1
    $leftContent.Add((' ' * $mainInner))
    $items = $State.ListItems
    $maxShow = [Math]::Max(1, [Math]::Min($items.Count, $contentH - $headCount))
    if ($State.CursorIdx -lt $State.ScrollTop) { $State.ScrollTop = $State.CursorIdx }
    if ($State.CursorIdx -ge $State.ScrollTop + $maxShow) { $State.ScrollTop = $State.CursorIdx - $maxShow + 1 }
    for ($i = 0; $i -lt $maxShow; $i++) {
      $idx = $State.ScrollTop + $i
      $li = $items[$idx]
      $mark = if ($li.active) { '*' } else { ' ' }
      $txt = Fit-Plain "$mark $($li.label)" $mainInner
      if ($idx -eq $State.CursorIdx) { $leftContent.Add("$C_BG_SEL$C_BOLD$txt$C_RESET") } else { $leftContent.Add($txt) }
      $script:Hitboxes.Add(@{ y = $bodyStartIdx + 2 + $headCount + $i; x1 = 3; x2 = $mainW - 2; action = $li.action; value = $li.value })
    }
  } elseif ($State.Overlay -eq 'input-file') {
    foreach ($hl in (Wrap-Plain "请输入本地 .txt 路径（支持英文文章或 词|义 行）：" $mainInner)) { $leftContent.Add((Fit-Plain $hl $mainInner)) }
    $leftContent.Add((' ' * $mainInner))
    foreach ($pl in (Wrap-Plain "> $($State.PromptBuf)_" $mainInner)) { $leftContent.Add("$C_BG_SEL" + (Fit-Plain $pl $mainInner) + $C_RESET) }
    $leftContent.Add((' ' * $mainInner))
    foreach ($hl in (Wrap-Plain "Enter 确认导入  |  Esc 取消" $mainInner)) { $leftContent.Add("$C_DIM" + (Fit-Plain $hl $mainInner) + $C_RESET) }
  } elseif ($State.Overlay -eq 'input-ai') {
    foreach ($hl in (Wrap-Plain "当前模型：$($Persisted.aiModel) ($($Persisted.aiUrl))" $mainInner)) { $leftContent.Add((Fit-Plain $hl $mainInner)) }
    foreach ($hl in (Wrap-Plain "请输入主题（如：商务邮件、旅游英语）：" $mainInner)) { $leftContent.Add((Fit-Plain $hl $mainInner)) }
    $leftContent.Add((' ' * $mainInner))
    foreach ($pl in (Wrap-Plain "> $($State.PromptBuf)_" $mainInner)) { $leftContent.Add("$C_BG_SEL" + (Fit-Plain $pl $mainInner) + $C_RESET) }
    $leftContent.Add((' ' * $mainInner))
    foreach ($hl in (Wrap-Plain "Enter 调用 AI 生成  |  Esc 取消" $mainInner)) { $leftContent.Add("$C_DIM" + (Fit-Plain $hl $mainInner) + $C_RESET) }
  } elseif ($State.Finished) {
    $leftContent.Add("$C_GREEN$C_BOLD" + (Fit-Plain "* 本组练习完成！" $mainInner) + $C_RESET)
    $leftContent.Add((' ' * $mainInner))
    foreach ($hl in (Wrap-Plain "完成：$($State.Items.Count) 条 | 正确率：$acc% | 速度：$wpm WPM | 最高连击：$($State.MaxStreak) | 错题：$($Persisted.mistakes.Count)" $mainInner)) {
      $leftContent.Add((Fit-Plain $hl $mainInner))
    }
    $leftContent.Add((' ' * $mainInner))
    foreach ($hl in (Wrap-Plain "[Enter] 下一组  [R] 重练  [F1] 换词库" $mainInner)) {
      $leftContent.Add("$C_CYAN" + (Fit-Plain $hl $mainInner) + $C_RESET)
    }
  } elseif ($State.Items.Count -gt 0) {
    $item = $State.Items[$State.Index]
    $show = (-not $State.Dictation) -or $State.Peek

    # 进度条（纯 ASCII 1列宽，自适应窄屏）
    $barW = if ($mainInner -lt 48) { [Math]::Max(6, [Math]::Min(12, $mainInner - 28)) } else { [Math]::Min(24, [Math]::Max(10, $mainInner - 42)) }
    $doneCnt = $State.DoneSet.Count
    $fill = [int][Math]::Round(($doneCnt / [Math]::Max(1, $State.Items.Count)) * $barW)
    $bar = ('#' * $fill) + ('-' * ($barW - $fill))
    $statText = if ($mainInner -lt 48) {
      "[$bar] $($State.Index + 1)/$($State.Items.Count) $acc% $($State.Streak)连 ${wpm}W"
    } else {
      "[$bar] $($State.Index + 1)/$($State.Items.Count)  正确率:$acc%  连击:$($State.Streak)  $wpm WPM"
    }
    foreach ($sl in (Wrap-Plain $statText $mainInner)) {
      $leftContent.Add("$C_DIM" + (Fit-Plain $sl $mainInner) + $C_RESET)
    }
    if ($contentH -ge 8) { $leftContent.Add((' ' * $mainInner)) }

    # 目标词/句（带增量高亮与自动换行）
    $tLines = Build-TargetLines $item $mainInner $show
    foreach ($tl in $tLines) { $leftContent.Add($tl) }
    if ($contentH -ge 7) { $leftContent.Add((' ' * $mainInner)) }

    if ($item.phonetic) {
      foreach ($pl in (Wrap-Plain $item.phonetic $mainInner)) {
        $leftContent.Add("$C_DIM" + (Fit-Plain $pl $mainInner) + $C_RESET)
      }
    }
    foreach ($ml in (Wrap-Plain $item.meaning $mainInner)) {
      $leftContent.Add("$C_YELLOW" + (Fit-Plain $ml $mainInner) + $C_RESET)
    }

    if ($leftContent.Count + 3 -le $contentH) {
      $leftContent.Add((' ' * $mainInner))
      $prevMeaning = if ($State.Index -gt 0) { if ($State.Items[$State.Index - 1].meaning) { $State.Items[$State.Index - 1].meaning } else { '暂无释义' } } else { '（已是第一条）' }
      $nextMeaning = if ($State.Index + 1 -lt $State.Items.Count) { if ($State.Items[$State.Index + 1].meaning) { $State.Items[$State.Index + 1].meaning } else { '暂无释义' } } else { '（本组最后一条）' }
      $prevTxt = "上一条：$prevMeaning"
      $nextTxt = "下一条：$nextMeaning"
      $leftContent.Add("$C_DIM" + (Fit-Plain $prevTxt $mainInner) + $C_RESET)
      $leftContent.Add("$C_DIM" + (Fit-Plain $nextTxt $mainInner) + $C_RESET)
    }
  } else {
    foreach ($hl in (Wrap-Plain "当前列表为空（请按 F1 选择词库，或 Ctrl+L 导入）" $mainInner)) {
      $leftContent.Add((Fit-Plain $hl $mainInner))
    }
  }

  for ($i = 0; $i -lt $contentH; $i++) {
    $rowTxt = if ($i -lt $leftContent.Count) { $leftContent[$i] } else { ' ' * $mainInner }
    $leftBuf.Add("$C_BORDER│$C_RESET $rowTxt $C_BORDER│$C_RESET")
  }
  $leftBuf.Add("$C_BORDER╰" + ('─' * ($mainW - 2)) + "╯$C_RESET")

  if ($hasSide) {
    # 预构建右栏：本组词汇队列（可鼠标点击跳词）
    $rightBuf = [System.Collections.Generic.List[string]]::new()
    $sideTitle = ' 本组队列 '
    $rtPad = '─' * [Math]::Max(0, $sideW - 3 - (Get-DisplayWidth $sideTitle))
    $rightBuf.Add("$C_BORDER╭─$C_YELLOW$C_BOLD$sideTitle$C_RESET$C_BORDER$rtPad╮$C_RESET")

    $qScroll = [Math]::Max(0, $State.Index - [int]($contentH / 2))
    if ($State.Items.Count -gt $contentH -and $qScroll + $contentH -gt $State.Items.Count) {
      $qScroll = [Math]::Max(0, $State.Items.Count - $contentH)
    }
    for ($i = 0; $i -lt $contentH; $i++) {
      $qi = $qScroll + $i
      if ($qi -lt $State.Items.Count) {
        $qItem = $State.Items[$qi]
        $qIcon = if ($qi -eq $State.Index) { '>' } elseif ($State.DoneSet.ContainsKey($qi)) { '+' } else { '.' }
        $qLabel = if ($State.Dictation -and $qi -ge $State.Index -and -not $State.DoneSet.ContainsKey($qi)) {
          "$qIcon [听写 #$($qi + 1)]"
        } else {
          "$qIcon $($qItem.target)"
        }
        $qFit = Fit-Plain $qLabel $sideInner
        if ($qi -eq $State.Index) {
          $rightBuf.Add("$C_BORDER│$C_RESET $C_BG_SEL$C_BOLD$qFit$C_RESET $C_BORDER│$C_RESET")
        } elseif ($State.DoneSet.ContainsKey($qi)) {
          $rightBuf.Add("$C_BORDER│$C_RESET $C_GREEN$qFit$C_RESET $C_BORDER│$C_RESET")
        } else {
          $rightBuf.Add("$C_BORDER│$C_RESET $C_DIM$qFit$C_RESET $C_BORDER│$C_RESET")
        }
        $script:Hitboxes.Add(@{ y = $bodyStartIdx + 2 + $i; x1 = $mainW + 2; x2 = $w - 1; action = 'jump-word'; value = $qi })
      } else {
        $rightBuf.Add("$C_BORDER│$C_RESET $(' ' * $sideInner) $C_BORDER│$C_RESET")
      }
    }
    $rightBuf.Add("$C_BORDER╰" + ('─' * ($sideW - 2)) + "╯$C_RESET")

    for ($r = 0; $r -lt $bodyRows; $r++) {
      $lines[$bodyStartIdx + $r] = $leftBuf[$r] + ' ' + $rightBuf[$r]
    }
  } else {
    for ($r = 0; $r -lt $bodyRows; $r++) {
      $lines[$bodyStartIdx + $r] = $leftBuf[$r]
    }
  }

  # ── 状态通知栏 ──
  if ($statusIdx -ge 0 -and $statusIdx -lt $h) {
    $lines[$statusIdx] = "$C_DIM " + (Fit-Plain $State.StatusMsg ($w - 1)) + $C_RESET
  }

  # ── 增量 diff 刷屏（只输出有变化的整行，全行定宽，无需 \x1b[K） ──
  $out = [System.Text.StringBuilder]::new()
  for ($r = 0; $r -lt $h; $r++) {
    $line = $lines[$r]
    $prev = $null
    if (-not $script:PrevLines.TryGetValue($r, [ref]$prev) -or $prev -ne $line) {
      [void]$out.Append("$E[$($r + 1);1H$line")
      $script:PrevLines[$r] = $line
    }
  }
  if ($out.Length -gt 0) {
    [Console]::Write($out.ToString())
  }
}

function Open-ListOverlay([string]$kind) {
  if ($State.Overlay -eq 'list' -and $State.ListKind -eq $kind) {
    $State.Overlay = 'none'
    return
  }
  $items = [System.Collections.Generic.List[object]]::new()
  $cur = 0
  if ($kind -eq 'deck') {
    $State.ListTitle = '切换词库'
    $State.ListHint = 'Up/Down 移动 | Enter/点击确认 | Esc 返回'
    for ($i = 0; $i -lt $Catalog.Count; $i++) {
      $c = $Catalog[$i]
      $tag = if ($c.type -eq 'word') { '单词' } else { '句子' }
      $isCur = ($c.id -eq $State.DeckId)
      if ($isCur) { $cur = $i }
      $items.Add(@{ label = "[$tag] $($c.name) ($($c.id))"; active = $isCur; action = 'pick-deck'; value = $i })
    }
  } else {
    $State.ListTitle = '切换分组'
    $State.ListHint = "共 $($State.TotalGroups) 组 | Up/Down 移动 | Enter/点击确认"
    for ($gi = 0; $gi -lt $State.TotalGroups; $gi++) {
      $gNum = $gi + 1
      $s = $gi * $Size + 1
      $e = [Math]::Min(($gi + 1) * $Size, $State.Entries.Count)
      $isCur = ($gNum -eq $State.Group)
      if ($isCur) { $cur = $gi }
      $items.Add(@{ label = "第 $gNum 组 ($s - $e)"; active = $isCur; action = 'pick-group'; value = $gNum })
    }
  }
  $State.Overlay = 'list'
  $State.ListKind = $kind
  $State.ListItems = $items
  $State.CursorIdx = $cur
  $State.ScrollTop = 0
}

function Handle-Action([string]$action, $val = $null) {
  switch ($action) {
    'open-deck'  { Open-ListOverlay 'deck' }
    'open-group' { Open-ListOverlay 'group' }
    'open-mistakes' {
      if ($Persisted.mistakes.Count -eq 0) {
        $State.StatusMsg = '错题本目前为空（练习拼错的词会自动收录）'
      } else {
        $State.Overlay = 'none'
        $State.DeckId = 'mistakes'
        $State.Title = '我的错题本'
        $State.Entries = [System.Collections.Generic.List[object]]::new()
        foreach ($m in $Persisted.mistakes) { $State.Entries.Add($m) }
        Set-Group 1
        $State.StatusMsg = "已进入错题本，共 $($State.Entries.Count) 条"
        if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }
      }
    }
    'open-file' { $State.Overlay = 'input-file'; $State.PromptBuf = '' }
    'open-ai'   { $State.Overlay = 'input-ai';   $State.PromptBuf = '' }
    'toggle-mode' {
      $State.Dictation = -not $State.Dictation
      $State.Peek = $false
      $State.StatusMsg = "已切换为$(if ($State.Dictation) { '听写模式' } else { '跟打模式' })"
    }
    'toggle-sound' {
      $script:SoundOn = -not $script:SoundOn
      $State.StatusMsg = "语音朗读已$(if ($script:SoundOn) { '开启' } else { '静音' })"
      if ($script:SoundOn -and $State.Items.Count -gt 0) { Speak-Text $State.Items[$State.Index].target }
    }
    'shuffle' {
      if ($State.Items.Count -gt 1) {
        $rnd = [System.Random]::new()
        $State.Items = @($State.Items | Sort-Object { $rnd.Next() })
        $State.Index = 0; $State.Typed = ''; $State.Peek = $false; $State.DoneSet = @{}
        $State.StatusMsg = '已随机打乱本组顺序'
        Speak-Text $State.Items[0].target
      }
    }
    'pick-deck' {
      $meta = $Catalog[[int]$val]
      $State.Overlay = 'none'
      Select-DeckAndGroup $meta.id 1
      if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }
    }
    'pick-group' {
      $State.Overlay = 'none'
      Set-Group ([int]$val)
      $State.StatusMsg = "已切换到第 $($State.Group) 组"
      if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }
    }
    'jump-word' {
      $qi = [int]$val
      if ($qi -ge 0 -and $qi -lt $State.Items.Count) {
        $State.Index = $qi; $State.Typed = ''; $State.HasError = $false; $State.WordWrong = $false; $State.Peek = $false
        Speak-Text $State.Items[$State.Index].target
      }
    }
    'speak' { if ($State.Items.Count -gt 0) { Speak-Text $State.Items[$State.Index].target } }
    'peek'  { $State.Peek = -not $State.Peek }
    'prev-word' {
      if ($State.Index -gt 0) {
        $State.Index--; $State.Typed = ''; $State.HasError = $false; $State.WordWrong = $false; $State.Peek = $false
        Speak-Text $State.Items[$State.Index].target
      }
    }
    'next-word' {
      if ($State.Index + 1 -lt $State.Items.Count) {
        $State.Index++; $State.Typed = ''; $State.HasError = $false; $State.WordWrong = $false; $State.Peek = $false
        Speak-Text $State.Items[$State.Index].target
      }
    }
    'exit' { return $true }
  }
  return $false
}

function Read-InputEvent {
  $k = [Console]::ReadKey($true)
  if ($k.Key -eq [ConsoleKey]::Escape -and [Console]::KeyAvailable) {
    $seq = [System.Text.StringBuilder]::new()
    while ([Console]::KeyAvailable) {
      $next = [Console]::ReadKey($true)
      [void]$seq.Append($next.KeyChar)
      if ($next.KeyChar -eq 'M' -or $next.KeyChar -eq 'm' -or $next.KeyChar -eq '~' -or ($seq.Length -eq 2 -and $seq[0] -eq 'O')) { break }
    }
    $s = $seq.ToString()
    if ($s -match '^\[<(\d+);(\d+);(\d+)([Mm])$') {
      return @{ kind = 'mouse'; btn = [int]$Matches[1]; x = [int]$Matches[2]; y = [int]$Matches[3]; type = $Matches[4] }
    }
    $vtMap = @{
      'OP' = [ConsoleKey]::F1; '[11~' = [ConsoleKey]::F1
      'OQ' = [ConsoleKey]::F2; '[12~' = [ConsoleKey]::F2
      'OR' = [ConsoleKey]::F3; '[13~' = [ConsoleKey]::F3
      'OS' = [ConsoleKey]::F4; '[14~' = [ConsoleKey]::F4
      '[15~' = [ConsoleKey]::F5
      '[17~' = [ConsoleKey]::F6
    }
    if ($vtMap.ContainsKey($s)) {
      return @{ kind = 'key'; info = [System.ConsoleKeyInfo]::new([char]0, $vtMap[$s], $false, $false, $false) }
    }
    return @{ kind = 'ignore' }
  }
  return @{ kind = 'key'; info = $k }
}

# ── 主循环 ──
try {
  [Console]::Write("$E[?1049h$E[?25l$E[?7l$E[?1000h$E[?1006h")
  Render-Frame
  if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }

  while ($true) {
    $ev = Read-InputEvent
    if ($ev.kind -eq 'ignore') { continue }

    if ($ev.kind -eq 'mouse') {
      if ($ev.type -eq 'M' -and $ev.btn -eq 0) {
        foreach ($hb in $script:Hitboxes) {
          if ($ev.y -eq $hb.y -and $ev.x -ge $hb.x1 -and $ev.x -le $hb.x2) {
            if (Handle-Action $hb.action $hb.value) { return }
            Render-Frame
            break
          }
        }
      }
      continue
    }

    $ki = $ev.info
    $isCtrl = ($ki.Modifiers -band [ConsoleModifiers]::Control) -ne 0

    if ($isCtrl -and $ki.Key -eq [ConsoleKey]::C) { return }
    if ($ki.Key -eq [ConsoleKey]::Escape) {
      if ($State.Overlay -ne 'none') { $State.Overlay = 'none'; Render-Frame; continue }
      return
    }

    # 文本输入弹窗（导入文件 / AI 出题）
    if ($State.Overlay -eq 'input-file' -or $State.Overlay -eq 'input-ai') {
      if ($ki.Key -eq [ConsoleKey]::Enter) {
        $val = $State.PromptBuf.Trim()
        $modeOverlay = $State.Overlay
        $State.Overlay = 'none'
        if ($val) {
          try {
            if ($modeOverlay -eq 'input-file') {
              $entries = Parse-TextToEntries (Get-Content (Resolve-Path $val) -Raw -Encoding UTF8)
              $State.Entries = $entries; $State.Title = Split-Path $val -Leaf; $State.DeckId = 'custom'
              Set-Group 1
              $State.StatusMsg = "已导入 $($entries.Count) 条自定义内容"
            } else {
              $State.StatusMsg = "正在调用 AI 生成「$val」…"; Render-Frame
              $entries = Invoke-AiDeck $val
              $State.Entries = $entries; $State.Title = "AI:$val"; $State.DeckId = 'ai'
              Set-Group 1
              $State.StatusMsg = "AI 已生成 $($entries.Count) 条「$val」词库"
            }
            if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }
          } catch {
            $State.StatusMsg = "失败：$($_.Exception.Message)"
          }
        }
        Render-Frame
        continue
      }
      if ($ki.Key -eq [ConsoleKey]::Backspace) {
        if ($State.PromptBuf.Length -gt 0) { $State.PromptBuf = $State.PromptBuf.Substring(0, $State.PromptBuf.Length - 1) }
        Render-Frame; continue
      }
      if (-not [char]::IsControl($ki.KeyChar)) {
        $State.PromptBuf += $ki.KeyChar
        Render-Frame
      }
      continue
    }

    # 全局快捷键
    if ($ki.Key -eq [ConsoleKey]::F1 -or ($isCtrl -and $ki.Key -eq [ConsoleKey]::B)) { $null = Handle-Action 'open-deck'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::F2 -or ($isCtrl -and $ki.Key -eq [ConsoleKey]::G)) { $null = Handle-Action 'open-group'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::F3 -or ($isCtrl -and $ki.Key -eq [ConsoleKey]::M)) { $null = Handle-Action 'toggle-mode'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::F4 -or ($isCtrl -and $ki.Key -eq [ConsoleKey]::V)) { $null = Handle-Action 'toggle-sound'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::F5) { $null = Handle-Action 'open-mistakes'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::F6) { $null = Handle-Action 'shuffle'; Render-Frame; continue }
    if ($isCtrl -and $ki.Key -eq [ConsoleKey]::L) { $null = Handle-Action 'open-file'; Render-Frame; continue }
    if ($isCtrl -and $ki.Key -eq [ConsoleKey]::A) { $null = Handle-Action 'open-ai'; Render-Frame; continue }

    if ($State.Overlay -eq 'list') {
      $maxIdx = [Math]::Max(0, $State.ListItems.Count - 1)
      if ($ki.Key -eq [ConsoleKey]::UpArrow -or $ki.Key -eq [ConsoleKey]::LeftArrow) { $State.CursorIdx = [Math]::Max(0, $State.CursorIdx - 1) }
      elseif ($ki.Key -eq [ConsoleKey]::DownArrow -or $ki.Key -eq [ConsoleKey]::RightArrow) { $State.CursorIdx = [Math]::Min($maxIdx, $State.CursorIdx + 1) }
      elseif ($ki.Key -eq [ConsoleKey]::Enter -and $State.ListItems.Count -gt 0) {
        $sel = $State.ListItems[$State.CursorIdx]
        $null = Handle-Action $sel.action $sel.value
      }
      Render-Frame; continue
    }

    if ($State.Finished) {
      if ($ki.Key -eq [ConsoleKey]::Enter -and $State.Group -lt $State.TotalGroups) {
        Set-Group ($State.Group + 1); Render-Frame
        if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }
      } elseif ($ki.Key -eq [ConsoleKey]::R) {
        Set-Group $State.Group; Render-Frame
        if ($State.Items.Count -gt 0) { Speak-Text $State.Items[0].target }
      }
      continue
    }

    if ($State.Items.Count -eq 0) { continue }
    $item = $State.Items[$State.Index]
    $target = $item.target

    if ($ki.Key -eq [ConsoleKey]::Enter)    { $null = Handle-Action 'speak'; continue }
    if ($ki.Key -eq [ConsoleKey]::Tab)      { $null = Handle-Action 'peek'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::PageUp)   { $null = Handle-Action 'prev-word'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::PageDown) { $null = Handle-Action 'next-word'; Render-Frame; continue }
    if ($ki.Key -eq [ConsoleKey]::Backspace) {
      if ($State.Typed.Length -gt 0) { $State.Typed = $State.Typed.Substring(0, $State.Typed.Length - 1) }
      $State.HasError = $false; Render-Frame; continue
    }

    $ch = $ki.KeyChar
    if ([char]::IsControl($ch)) { continue }

    if ($null -eq $State.StartTime) { $State.StartTime = Get-Date }
    $expected = if ($State.Typed.Length -lt $target.Length) { $target[$State.Typed.Length] } else { $null }
    $State.TotalKeys++

    if ($null -ne $expected -and ([string]$ch).ToLowerInvariant() -eq ([string]$expected).ToLowerInvariant()) {
      $State.Typed += $expected
      $rest = $target.Substring($State.Typed.Length)
      if ($rest -and $rest -match '^[.!?,;:''"()]+$') { $State.Typed = $target }
      $State.HasError = $false
      $State.CorrectKeys++

      if ($State.Typed.Length -eq $target.Length) {
        $State.Streak++
        if ($State.Streak -gt $State.MaxStreak) { $State.MaxStreak = $State.Streak }
        $State.DoneSet[$State.Index] = $true
        Render-Frame
        if ($State.Index + 1 -ge $State.Items.Count) {
          $State.Finished = $true; Render-Frame
        } else {
          Start-Sleep -Milliseconds 100
          $State.Index++; $State.Typed = ''; $State.Peek = $false; $State.WordWrong = $false
          Render-Frame
          Speak-Text $State.Items[$State.Index].target
        }
      } else {
        Render-Frame
      }
    } else {
      $State.HasError = $true
      $State.Streak = 0
      if (-not $State.WordWrong) {
        $State.WordWrong = $true
        if ($State.Dictation) {
          Add-Mistake $item
          $State.StatusMsg = '拼写错误，已自动加入错题本'
        } else {
          $State.StatusMsg = '拼写有误，请继续'
        }
      }
      [Console]::Beep(400, 50)
      Render-Frame
    }
  }
} finally {
  [Console]::Write("$E[?1006l$E[?1000l$E[?7h$E[?25h$E[?1049l")
}

