<#
.SYNOPSIS
  Пишет окно приложения в MP4, пока идёт съёмочный прогон.

.DESCRIPTION
  Запись держится снаружи теста намеренно: тест о своей съёмке знать не
  обязан, и тот же прогон годится и для проверки, и для камеры.

  Ждёт появления окна по заголовку, потому что `flutter test -d windows`
  сначала собирает приложение (десятки секунд), и запись, начатая сразу,
  сняла бы пустой рабочий стол.

  Захват идёт через gdigrab по ЗАГОЛОВКУ окна, а не по области экрана:
  так в кадр не попадает ничего постороннего — ни чужие окна, ни панель
  задач, ни уведомления.

.EXAMPLE
  # В одном окне:
  powershell -File tools/record_window.ps1 -Out docs/internal/video/out/pilot.mp4
  # В другом:
  flutter test integration_test/video_pilot_test.dart -d windows
#>
param(
  [string]$Title = 'TelePOS',
  [string]$Out = 'docs/internal/video/out/pilot.mp4',
  [int]$Fps = 30,
  [int]$WaitSeconds = 300,
  [int]$MaxSeconds = 600,
  # Ровное 16:9 по требованию правил (раздел 7). Пилот 20 сентября снят
  # 1264x680 — это 1.86:1, и на выкладке он получил бы чёрные поля сверху
  # и снизу. Подгоняется КЛИЕНТСКАЯ область, а не всё окно: рамка и
  # заголовок в кадр не попадают, и считать их в 16:9 нельзя.
  [int]$Width = 1280,
  [int]$Height = 720,
  # Курсор в кадре обязателен: правила требуют, чтобы он вёлся к цели.
  [int]$DrawMouse = 1
)

$ErrorActionPreference = 'Stop'

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinFind {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

  /// Подгоняет КЛИЕНТСКУЮ область окна под заданный размер.
  ///
  /// Наивное `SetWindowPos(w,h)` задаёт размер ВСЕГО окна вместе с рамкой,
  /// и клиентская область выходит меньше на её толщину — кадр получается
  /// не 16:9, а «почти». Поэтому разница между окном и клиентом меряется и
  /// прибавляется.
  public static string FitClient(string needle, int cw, int ch) {
    IntPtr h = Find(needle);
    if (h == IntPtr.Zero) return null;
    RECT w, c;
    if (!GetWindowRect(h, out w) || !GetClientRect(h, out c)) return null;
    int chromeX = (w.Right - w.Left) - (c.Right - c.Left);
    int chromeY = (w.Bottom - w.Top) - (c.Bottom - c.Top);
    SetWindowPos(h, IntPtr.Zero, 0, 0, cw + chromeX, ch + chromeY, 0x0004 | 0x0002);
    GetClientRect(h, out c);
    return (c.Right - c.Left) + "x" + (c.Bottom - c.Top);
  }

  public static IntPtr Find(string needle) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      int len = GetWindowTextLength(h);
      if (len == 0) return true;
      var sb = new StringBuilder(len + 1);
      GetWindowTextW(h, sb, sb.Capacity);
      if (sb.ToString().IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static string Match(string needle) {
    string found = null;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      int len = GetWindowTextLength(h);
      if (len == 0) return true;
      var sb = new StringBuilder(len + 1);
      GetWindowTextW(h, sb, sb.Capacity);
      string t = sb.ToString();
      if (t.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0) { found = t; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
'@ -Language CSharp

Write-Host "[rec] жду окно с заголовком, содержащим '$Title' (до $WaitSeconds с)..."
$deadline = (Get-Date).AddSeconds($WaitSeconds)
$actual = $null
while ((Get-Date) -lt $deadline) {
  $actual = [WinFind]::Match($Title)
  if ($actual) { break }
  Start-Sleep -Milliseconds 400
}

if (-not $actual) {
  Write-Error "[rec] окно '$Title' не появилось за $WaitSeconds с. Записывать нечего."
  exit 1
}

Write-Host "[rec] нашёл окно: '$actual'"

$client = [WinFind]::FitClient($Title, $Width, $Height)
if ($client -ne "${Width}x${Height}") {
  Write-Error "[rec] клиентская область $client вместо ${Width}x${Height}. Записывать нельзя: кадр не 16:9, и на выкладке будут поля."
  exit 1
}
Write-Host "[rec] клиентская область подогнана: $client"
Start-Sleep -Milliseconds 700
Write-Host "[rec] пишу в $Out ($Fps к/с, не дольше $MaxSeconds с)"

# -f gdigrab -i title=... — захват одного окна по заголовку.
# yuv420p и чётные размеры: без них половина проигрывателей покажет
# чёрный кадр, а видео «работает» только у того, кто его снял.
& ffmpeg -hide_banner -loglevel warning -y `
  -f gdigrab -framerate $Fps -draw_mouse $DrawMouse -i "title=$actual" `
  -t $MaxSeconds `
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" `
  -c:v libx264 -preset veryfast -crf 20 -movflags +faststart `
  $Out

if (Test-Path $Out) {
  $size = [math]::Round((Get-Item $Out).Length / 1MB, 2)
  Write-Host "[rec] готово: $Out ($size МБ)"
} else {
  Write-Error '[rec] ffmpeg не оставил файла'
  exit 1
}
