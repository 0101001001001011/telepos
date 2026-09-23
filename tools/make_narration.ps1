# УСТАРЕЛО 2026-09-20. Решение Rob'а: озвучка и сборка обучающих роликов
# уходят на сторону SphereX целиком.
#
# Причина не в качестве этого кода. Голос здесь — Microsoft Zira Desktop,
# системный SAPI Windows, и он заметно хуже голоса SphereX, который
# выбирали долго и который один на весь канал. Плюс у SphereX это ОДИН
# механизм сборки с проверками, из которого сразу выходят постеры,
# вертикальные коротышки, водяной знак и выкладка на площадки. Два
# механизма на один канал — это две интонации и две очереди правок.
#
# ЧТО ОСТАЁТСЯ ЗДЕСЬ: съёмка. record_window.ps1 и отметки [VIDEO-MARK],
# которые печатает съёмочный прогон, — это наша часть работы и она не
# меняется. См. docs/video-production.md.
#
# Файл не удалён намеренно: пока сборщик SphereX не заработал, им можно
# сделать местную прикидку. Ролик для зрителя им собирать нельзя.

<#
.SYNOPSIS
  Озвучивает закадровый текст по сегментам и сообщает длительность каждого.

.DESCRIPTION
  Один файл WAV на сегмент, а не одна дорожка целиком. Причина простая:
  ролик пересниматься будет, и паузы в нём поедут. Сегментами их можно
  разложить заново по новым отметкам времени, целую дорожку пришлось бы
  переозвучивать.

  Длительности печатаются в конце и складываются в narration.json — по ним
  собирается и звуковая дорожка, и файл субтитров, так что расчёт делается
  один раз и врозь не разъедется.

.EXAMPLE
  powershell -File tools/make_narration.ps1 `
    -In docs/internal/video/01-narration.txt `
    -OutDir docs/internal/video/out/voice
#>
param(
  [string]$In = 'docs/internal/video/01-narration.txt',
  [string]$OutDir = 'docs/internal/video/out/voice',
  [string]$Voice = 'Microsoft Zira Desktop',
  [int]$Rate = -1
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $In)) { Write-Error "нет файла с текстом: $In"; exit 1 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

$available = $synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name }
if ($available -notcontains $Voice) {
  Write-Error "голос '$Voice' не установлен. Есть: $($available -join ', ')"
  exit 1
}
$synth.SelectVoice($Voice)
$synth.Rate = $Rate

# Разбор: "@имя" открывает сегмент, "#" — комментарий, остальное — речь.
$segments = [ordered]@{}
$current = $null
foreach ($line in Get-Content -Path $In -Encoding UTF8) {
  $t = $line.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  if ($t.StartsWith('@')) {
    $current = $t.Substring(1).Trim()
    $segments[$current] = @()
    continue
  }
  if ($null -eq $current) { continue }
  $segments[$current] += $t
}

if ($segments.Count -eq 0) { Write-Error 'в файле нет ни одного сегмента'; exit 1 }

$report = @()
$order = 0
foreach ($name in $segments.Keys) {
  $order++
  $text = ($segments[$name] -join ' ')
  $file = Join-Path $OutDir ("{0:d2}-{1}.wav" -f $order, $name)

  $synth.SetOutputToWaveFile($file)
  $synth.Speak($text)
  $synth.SetOutputToNull()

  $dur = [double](& ffprobe -v error -show_entries format=duration -of csv=p=0 $file)
  $report += [pscustomobject]@{
    order    = $order
    name     = $name
    file     = (Resolve-Path $file).Path
    seconds  = [math]::Round($dur, 3)
    text     = $text
  }
  Write-Host ("[voice] {0,-12} {1,6:n2} с  {2}" -f $name, $dur, (Split-Path $file -Leaf))
}

$synth.Dispose()

$total = ($report | Measure-Object -Property seconds -Sum).Sum
Write-Host ("[voice] всего {0:n1} с в {1} сегментах" -f $total, $report.Count)

$json = Join-Path $OutDir 'narration.json'
$report | ConvertTo-Json -Depth 4 | Out-File -FilePath $json -Encoding utf8
Write-Host "[voice] раскладка: $json"
