<#
.SYNOPSIS
    Сборка установщика TelePOS для Windows (MSI).

.DESCRIPTION
    Единственный поддерживаемый способ собрать установщик. Графических окон,
    ручных шагов и «сначала открой WiX Toolset» здесь нет и быть не должно:
    установщик, который собирается только руками, через полгода не собирается
    вовсе — так уже случилось, от июньской сборки остались артефакты, а
    исходников не осталось ни в дереве, ни в истории.

    Версия берётся ИЗ pubspec.yaml и больше нигде не пишется. Два места одной
    версии расходятся — это уже проверено на сплеше, где литерал 3.3.0 пережил
    две минорных.

.PARAMETER Bump
    Поднять версию в pubspec.yaml перед сборкой: patch, minor или major.
    Номер сборки (+N) увеличивается на единицу при любом из них.
    Руками версию не правят — только этим ключом.

.PARAMETER SkipFlutter
    Не пересобирать ни кассу, ни страницу терминала — взять то, что уже лежит в
    build/windows и build/web. Для отладки самого установщика: полная сборка
    занимает минуты, а разметку приходится править десятками итераций.
    Проверки состава при этом НЕ пропускаются: собрать установщик без бандла
    или без нативных библиотек нельзя ни с каким ключом.

.PARAMETER Output
    Куда положить .msi. По умолчанию build\installer.

.EXAMPLE
    tools\build_windows_installer.ps1
    tools\build_windows_installer.ps1 -Bump patch
    tools\build_windows_installer.ps1 -SkipFlutter
#>
[CmdletBinding()]
param(
    [ValidateSet('patch', 'minor', 'major')]
    [string] $Bump,

    [switch] $SkipFlutter,

    [string] $Output,

    # Откуда брать собранное приложение. По умолчанию — build\windows в этом же
    # дереве. Переопределяют в двух случаях: CI собирает не там, где пакует, и
    # отладка разметки установщика по готовой сборке из другого дерева.
    [string] $BuildDir,

    # Откуда брать собранный браузерный бандл. По умолчанию — build\web в этом
    # же дереве, куда и кладёт `flutter build web`.
    [string] $WebDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Корень репозитория — на уровень выше tools\.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Pubspec  = Join-Path $RepoRoot 'pubspec.yaml'
if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot 'build\windows\x64\runner\Release' }
if (-not $WebDir)   { $WebDir   = Join-Path $RepoRoot 'build\web' }
$ObjDir = Join-Path $RepoRoot 'build\installer\obj'
if (-not $Output) { $Output = Join-Path $RepoRoot 'build\installer' }

# Нативные библиотеки, без которых касса не поднимает ни TLS, ни провод.
# Список не «на всякий случай»: зелёная сборка без библиотеки в этом проекте —
# наблюдавшийся исход, а не гипотеза, поэтому проверка обязательная и жёсткая.
$RequiredNativeLibraries = @('rk_pki.dll', 'rk_quic.dll', 'rk_mdns.dll', 'rk_syslog.dll')

# Файлы, по которым каталог опознаётся как собранный браузерный бандл.
# Тот же список назван в lib/backend/web_bundle.dart (kWebBundleMarkers), и он
# обязан оставаться одним: разойдись они — установщик соберёт то, что касса не
# признает бандлом, и терминал снова получит отказ. Сторож на пару —
# test/architecture/installer_ships_web_bundle_test.dart.
$RequiredWebFiles = @('index.html', 'main.dart.js')

# Версия WiX. Пин намеренный: «просто поставь WiX» даёт разные сборки на разных
# машинах, а установщик обязан быть воспроизводимым.
$WixVersion    = '6.0.2'
$WixExtensions = @('WixToolset.UI.wixext', 'WixToolset.Util.wixext')

function Write-Stage { param([string] $Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Note  { param([string] $Text) Write-Host "    $Text" -ForegroundColor DarkGray }

# ── Версия ───────────────────────────────────────────────────────────────────

function Get-PubspecVersion {
    <#
        Читает строку «version: 3.5.0+19» из pubspec.yaml.
        Возвращает объект с полями Version (3.5.0) и Build (19).
    #>
    $line = Select-String -Path $Pubspec -Pattern '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$' | Select-Object -First 1
    if (-not $line) { throw "в $Pubspec не найдена строка version: вида x.y.z+N" }
    $m = $line.Matches[0]
    return [pscustomobject]@{
        Major = [int] $m.Groups[1].Value
        Minor = [int] $m.Groups[2].Value
        Patch = [int] $m.Groups[3].Value
        Build = [int] $m.Groups[4].Value
        Version = "$($m.Groups[1].Value).$($m.Groups[2].Value).$($m.Groups[3].Value)"
    }
}

function Set-PubspecVersion {
    param([string] $Kind)

    $v = Get-PubspecVersion
    switch ($Kind) {
        'major' { $major = $v.Major + 1; $minor = 0;          $patch = 0 }
        'minor' { $major = $v.Major;     $minor = $v.Minor+1; $patch = 0 }
        'patch' { $major = $v.Major;     $minor = $v.Minor;   $patch = $v.Patch+1 }
    }
    $build = $v.Build + 1
    $new   = "$major.$minor.$patch+$build"

    # Правим ровно одну строку и сохраняем в UTF-8 без BOM: pubspec.yaml читает
    # Dart, а BOM в YAML он не любит.
    $text = [System.IO.File]::ReadAllText($Pubspec)
    $text = [regex]::Replace($text, '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$', "version: $new")
    [System.IO.File]::WriteAllText($Pubspec, $text, [System.Text.UTF8Encoding]::new($false))

    Write-Note "версия поднята: $($v.Version)+$($v.Build) -> $new"
}

# ── Тулчейн ──────────────────────────────────────────────────────────────────

function Resolve-Wix {
    <#
        Находит wix.exe и доводит его до нужного состояния.
        Ставится как dotnet tool — тем же способом на машине разработчика и в CI,
        без графического установщика.
    #>
    $wix = (Get-Command 'wix' -ErrorAction SilentlyContinue).Source
    if (-not $wix) {
        $candidate = Join-Path $env:USERPROFILE '.dotnet\tools\wix.exe'
        if (Test-Path $candidate) { $wix = $candidate }
    }
    if (-not $wix) {
        throw @"
не найден wix.exe. Поставить так:

    dotnet tool install --global wix --version $WixVersion

Затем повторить сборку. Ставить WiX графическим установщиком не нужно.
"@
    }

    $version = (& $wix --version) -replace '\+.*$', ''
    Write-Note "wix $version — $wix"
    if ($version -ne $WixVersion) {
        Write-Warning "ожидалась версия WiX $WixVersion, найдена $version — установщик может собраться иначе."
    }

    # Расширения: UI даёт мастер с выбором каталога, Util — вспомогательные
    # действия. Без них сборка падает на разборе разметки.
    $installed = (& $wix extension list --global) -join "`n"
    foreach ($ext in $WixExtensions) {
        if ($installed -notmatch [regex]::Escape($ext)) {
            Write-Note "ставим расширение $ext"
            & $wix extension add --global "$ext/$WixVersion"
            if ($LASTEXITCODE -ne 0) { throw "не удалось поставить расширение $ext" }
        }
    }
    return $wix
}

# ── Сборка приложения ────────────────────────────────────────────────────────

function Invoke-FlutterBuild {
    $flutter = (Get-Command 'flutter' -ErrorAction SilentlyContinue).Source
    if (-not $flutter) { throw 'не найден flutter в PATH' }

    # Дом Rust задаём явно. На этой машине две установки rustup, и процесс,
    # запущенный не из пользовательской оболочки, молча уходит не в тот дом —
    # это описано в docs/internal/toolchains.md и стоило прогона.
    if (Test-Path 'D:\rust\.cargo') {
        $env:RUSTUP_HOME = 'D:\rust\.rustup'
        $env:CARGO_HOME  = 'D:\rust\.cargo'
        $env:PATH        = "D:\rust\.cargo\bin;$env:PATH"
    }

    Push-Location $RepoRoot
    try {
        # ErrorActionPreference = Stop роняет сборку на СТРОКЕ В ПОТОКЕ ОШИБОК
        # внешней программы, не дожидаясь её кода возврата. Измерено
        # 2026-08-06: `flutter build windows` пишет безобидное «Nuget.exe not
        # found, trying to download or use cached version», PowerShell
        # превращает это в NativeCommandError, и сборка установщика падает при
        # совершенно исправном flutter.
        #
        # У внешней программы судить надо по коду возврата — он ниже и уже
        # проверялся, просто до него не доходило.
        $keep = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $flutter build windows --release
        } finally { $ErrorActionPreference = $keep }
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows завершился с кодом $LASTEXITCODE" }
    } finally { Pop-Location }
}

function Invoke-FlutterWebBuild {
    <#
        Собирает страницу терминала.

        Своя точка входа: lib/web/main_web.dart, а не lib/main.dart. Обычная
        точка входа тянет dart:ffi через GetIt<AppDatabase> и в браузере не
        собирается вовсе.

        --pwa-strategy=none намеренно. Умолчание (offline-first) порождает
        service worker, который кэширует бандл целиком, и после обновления кассы
        планшет ещё раз-другой открывает ПРЕЖНЮЮ страницу — то есть старый
        браузерный код против нового провода. Для кассы это негодный отказ: он
        выглядит как поломка провода. Автономность терминалу не нужна и в
        принципе: без кассы на связи он бесполезен.

        Одного этого ключа мало — см. Remove-ServiceWorkerRegistration ниже.
    #>
    $flutter = (Get-Command 'flutter' -ErrorAction SilentlyContinue).Source
    if (-not $flutter) { throw 'не найден flutter в PATH' }

    Push-Location $RepoRoot
    try {
        # То же, что и у сборки под Windows: судим по коду возврата, а не по
        # тому, что программа написала в поток ошибок.
        $keep = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            # `--pwa-strategy=none` убран 2026-08-28: с Flutter 3.47 флаг
            # объявлен устаревшим и печатает предупреждение в поток ошибок,
            # а регистрацию service worker всё равно вырезает
            # `Remove-ServiceWorkerRegistration` ниже — она и была настоящей
            # мерой, флаг лишь дублировал её и однажды будет удалён совсем.
            & $flutter build web -t lib/web/main_web.dart --release
        } finally { $ErrorActionPreference = $keep }
        if ($LASTEXITCODE -ne 0) { throw "flutter build web завершился с кодом $LASTEXITCODE" }
    } finally { Pop-Location }
}

function Remove-ServiceWorkerRegistration {
    <#
        Убирает из бандла регистрацию service worker целиком.

        # Зачем, если уже стоит --pwa-strategy=none

        Затем, что этот ключ делает не то, чего от него ждёшь. Он опустошает
        сам файл `flutter_service_worker.js` (0 байт), но НЕ убирает его
        регистрацию: `flutter_bootstrap.js` по-прежнему зовёт
        `_flutter.loader.load({serviceWorkerSettings: {serviceWorkerVersion:
        "…"}})`. Пустой worker не активируется никогда, загрузчик ждёт его
        ЧЕТЫРЕ СЕКУНДЫ и только потом идёт дальше.

        Измерено 2026-08-06 на установленной кассе, в консоли браузера:
        «Exception while loading service worker: Error: prepareServiceWorker
        took more than 4000ms to resolve. Moving on.» То есть ключ давал худшее
        из обоих: кэша нет И четыре секунды простоя на КАЖДОМ открытии
        терминала. Для экрана кассира это цена, которой никто не заказывал.

        # Почему не вернуться к offline-first

        Тогда вернулась бы устаревшая страница после обновления кассы: worker
        отдаёт из кэша немедленно, а новую версию подхватывает только к
        следующему открытию. Это старый браузерный код против нового провода, и
        выглядит он как поломка провода, а запасного пути через HTTP нет.

        Без worker'а вовсе нет ни того, ни другого: бандл едет по HTTPS с кассы
        из соседней комнаты, а повторные открытия закрывает обычный HTTP-кэш —
        shelf_static отдаёт ETag и Last-Modified, и браузер обходится условными
        запросами.

        # Почему с проверкой, а не «заменили и ладно»

        Правка идёт по порождённому файлу, а его форму задаёт Flutter и вправе
        менять. Молча не совпавшая замена вернула бы те же четыре секунды, и
        никто бы не заметил — поэтому несовпадение здесь отказ, а не пропуск.
    #>
    $bootstrap = Join-Path $WebDir 'flutter_bootstrap.js'
    if (-not (Test-Path $bootstrap)) {
        throw "не найден $bootstrap — бандл собран не тем, чем мы думаем"
    }

    $text = [System.IO.File]::ReadAllText($bootstrap)

    # Уже убрана — например, при повторной сборке с -SkipFlutter по тому же
    # бандлу. Это обычный ход, а не повод отказывать.
    if ($text -match '_flutter\.loader\.load\(\{\s*\}\);') {
        Write-Note 'service worker уже убран из бандла'
        return
    }

    # Вызов вообще без доводов — форма, которую порождает Flutter 3.47.
    #
    # Проверено по коду самого загрузчика в собранном бандле, а не по
    # предположению: `load({serviceWorkerSettings: e, ...} = {})` передаёт `e`
    # в `loadServiceWorker(e)`, а тот начинается с
    # `if (!e || !("serviceWorker" in navigator)) return Promise.resolve()`.
    # То есть при отсутствующем доводе регистрации не происходит вовсе —
    # ровно то состояние, ради которого написана эта функция.
    #
    # Файл `flutter_service_worker.js` при этом остаётся в бандле, и это не
    # упущение: его никто не регистрирует, он лежит мёртвым грузом. Удалять
    # его отдельно не нужно, но и рассчитывать на его отсутствие нельзя.
    if ($text -match '_flutter\.loader\.load\(\s*\);') {
        Write-Note 'загрузчик зовётся без доводов — service worker не регистрируется'
        return
    }

    # Якорь — сам вызов загрузчика в конце файла, а не имя свойства: имя
    # встречается и внутри минифицированного загрузчика выше по файлу.
    $patched = [regex]::Replace(
        $text,
        '_flutter\.loader\.load\(\{[\s\S]*?\}\);\s*$',
        "_flutter.loader.load({});`r`n"
    )

    if ($patched -eq $text) {
        throw @"
не удалось убрать регистрацию service worker из $bootstrap

Ожидался вызов вида `_flutter.loader.load({ serviceWorkerSettings: {...} });`
в конце файла — Flutter его, видимо, порождает иначе.

Оставить как есть нельзя: пустой worker не активируется, загрузчик ждёт его
четыре секунды, и столько же ждёт кассир при каждом открытии терминала.
"@
    }

    [System.IO.File]::WriteAllText($bootstrap, $patched, [System.Text.UTF8Encoding]::new($false))

    # Проверяем итог, а не факт замены: регулярное выражение могло совпасть и
    # оставить настройки на месте.
    $result = [System.IO.File]::ReadAllText($bootstrap)
    if ($result -match 'serviceWorkerVersion\s*:\s*"') {
        throw "в $bootstrap осталась версия service worker — регистрация не убрана"
    }

    # Пустой файл worker'а больше никому не нужен: регистрировать его нечем.
    $worker = Join-Path $WebDir 'flutter_service_worker.js'
    if (Test-Path $worker) { Remove-Item $worker -Force }

    Write-Note 'service worker убран из бандла (иначе +4 с на каждое открытие)'
}

function Assert-WebBundle {
    <#
        Проверяет, что бандл действительно доехал.

        Ровно та же жёсткость, что и у нативных библиотек, и по той же
        измеренной причине: до 2026-08-06 установщик не клал бандл ВОВСЕ, а
        собирался при этом зелёным. У заказчика касса поднимала сервер, отвечала
        `Frontend bundle not found` — и браузерный терминал не работал.

        Пустой каталог считается отсутствующим бандлом: `flutter build web`
        умеет оставить каталог после неудачи, и «каталог есть» о его содержимом
        не говорит ничего.
    #>
    if (-not (Test-Path $WebDir)) {
        throw @"
нет каталога браузерного бандла: $WebDir

Без него установщик поставит кассу, которая не может отдать страницу терминалу.
Соберите бандл: flutter build web -t lib/web/main_web.dart --release
"@
    }

    $missing = @()
    foreach ($name in $RequiredWebFiles) {
        $path = Join-Path $WebDir $name
        if (Test-Path $path) {
            $size = [math]::Round((Get-Item $path).Length / 1KB)
            Write-Note "$name — $size КБ"
        } else {
            $missing += $name
        }
    }
    if ($missing.Count -gt 0) {
        throw @"
в браузерном бандле нет файлов: $($missing -join ', ')

Каталог $WebDir существует, но бандлом не является. Установщик с такой сборкой
собирать нельзя: касса поставится, сервер поднимется, а терминал получит отказ —
и проявится это только у заказчика.

Пересоберите: flutter build web -t lib/web/main_web.dart --release
"@
    }

    $count = (Get-ChildItem -Path $WebDir -Recurse -File).Count
    Write-Note "бандл: $count файлов в $WebDir"
}

function Assert-NativeLibraries {
    <#
        Проверяет, что нативные библиотеки действительно доехали.

        Зелёная сборка доказательством не является: библиотека может не
        собраться, а сборка приложения при этом завершится успешно. Проверяем
        файлом, ровно как предписывает docs/internal/toolchains.md.
    #>
    $missing = @()
    foreach ($lib in $RequiredNativeLibraries) {
        $path = Join-Path $BuildDir $lib
        if (Test-Path $path) {
            $size = [math]::Round((Get-Item $path).Length / 1KB)
            Write-Note "$lib — $size КБ"
        } else {
            $missing += $lib
        }
    }
    if ($missing.Count -gt 0) {
        throw @"
в сборке нет нативных библиотек: $($missing -join ', ')

Без них касса не поднимает ни TLS, ни провод. Установщик с такой сборкой
собирать нельзя — он поставит неработоспособную кассу, и отказ проявится
только у заказчика.

Проверьте тулчейн Rust (docs/internal/toolchains.md): скорее всего, процесс ушёл в
дом на C:, где нет нужных целей.
"@
    }
}

# ── Лицензия для мастера ─────────────────────────────────────────────────────

function New-LicenseRtf {
    <#
        Порождает license.rtf из LICENSE. Копию текста лицензии в репозитории
        не держим: две копии одного текста расходятся так же, как две копии
        версии.
    #>
    param([string] $Destination)

    $text = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'LICENSE'))
    # В RTF служебные символы — обратная косая и фигурные скобки.
    $escaped = $text -replace '\\', '\\\\' -replace '\{', '\{' -replace '\}', '\}'
    # Скобки обязательны: без них PowerShell пытается приклеить перевод строки к
    # правому операнду -replace и отказывается разбирать выражение.
    $escaped = ($escaped -replace "`r`n", "`n") -replace "`n", ('\par' + "`r`n")

    $rtf = "{\rtf1\ansi\deff0{\fonttbl{\f0\fnil\fcharset0 Segoe UI;}}`r`n\fs18`r`n$escaped`r`n}"
    [System.IO.File]::WriteAllText($Destination, $rtf, [System.Text.ASCIIEncoding]::new())
    Write-Note "license.rtf порождён из LICENSE"
}

# ── Проверка кодировки скрипта доверия ───────────────────────────────────────

function Assert-TrustScriptEncoding {
    <#
        trust.ps1 обязан быть в UTF-8 С BOM.

        Windows PowerShell 5.1 читает файл без BOM как ANSI, кириллица
        превращается в мусор, и скрипт НЕ РАЗБИРАЕТСЯ ВОВСЕ — то есть корень не
        поставится, а установка при этом пройдёт. Измерено 2026-08-06, поэтому
        проверка стоит здесь, а не в чьей-то памяти.
    #>
    $path  = Join-Path $RepoRoot 'installer\windows\trust.ps1'
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        throw "$path сохранён без BOM. PowerShell 5.1 не сможет его разобрать. См. .gitattributes."
    }

    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref] $null, [ref] $errors)
    if ($errors.Count -gt 0) {
        throw "$path не разбирается: $($errors[0].Message)"
    }
    Write-Note 'trust.ps1 — BOM на месте, разбирается без ошибок'
}

# ── Основной ход ─────────────────────────────────────────────────────────────

if ($Bump) {
    Write-Stage "Поднимаем версию ($Bump)"
    Set-PubspecVersion -Kind $Bump
}

$v = Get-PubspecVersion
Write-Stage "TelePOS $($v.Version)+$($v.Build)"

Write-Stage 'Проверяем тулчейн'
$wix = Resolve-Wix
Assert-TrustScriptEncoding

if ($SkipFlutter) {
    Write-Stage 'Сборка приложения пропущена (-SkipFlutter)'
    if (-not (Test-Path (Join-Path $BuildDir 'telepos.exe'))) {
        throw "нечего упаковывать: не найден $BuildDir\telepos.exe. Запустите без -SkipFlutter."
    }
} else {
    Write-Stage 'Собираем приложение'
    Invoke-FlutterBuild

    # Бандл собирается ЗДЕСЬ, а не «кем-нибудь заранее». Пока он собирался
    # только в CI, его вывод никуда не ехал, и установщик паковал кассу без
    # страницы — молча.
    Write-Stage 'Собираем страницу терминала'
    Invoke-FlutterWebBuild
}

Write-Stage 'Проверяем нативные библиотеки'
Assert-NativeLibraries

Write-Stage 'Проверяем браузерный бандл'
# До проверки состава и безусловно — в том числе при -SkipFlutter, где бандл
# берут готовым и он вполне может быть непочиненным.
Remove-ServiceWorkerRegistration
Assert-WebBundle

Write-Stage 'Готовим промежуточные файлы'
New-Item -ItemType Directory -Force -Path $ObjDir, $Output | Out-Null
New-LicenseRtf -Destination (Join-Path $ObjDir 'license.rtf')

Write-Stage 'Собираем MSI'
$msi = Join-Path $Output "TelePOS_Setup_$($v.Version).msi"

& $wix build `
    (Join-Path $RepoRoot 'installer\windows\TelePOS.wxs') `
    -arch x64 `
    -culture ru-RU `
    -ext WixToolset.UI.wixext `
    -ext WixToolset.Util.wixext `
    -d "Version=$($v.Version)" `
    -d "BuildNumber=$($v.Build)" `
    -d "BuildDir=$BuildDir" `
    -d "WebDir=$WebDir" `
    -d "SourceRoot=$RepoRoot" `
    -d "ObjDir=$ObjDir" `
    -intermediatefolder $ObjDir `
    -o $msi

if ($LASTEXITCODE -ne 0) { throw "wix build завершился с кодом $LASTEXITCODE" }

$size = [math]::Round((Get-Item $msi).Length / 1MB, 1)
Write-Stage "Готово: $msi ($size МБ)"

# Подсказки печатаются полным путём и с оговорками, а не как шаблон
# `msiexec /x "<файл>.msi"`. Оба умолчания уже стоили времени.
#
# Права. Ставится это на всю машину, а тихая установка (/qn) повышения сама не
# запрашивает: без него она отказывает 1603 с откатом. Разметка теперь отвечает
# на это условием и внятным сообщением, но написать здесь всё равно надо — тот,
# кто читает вывод сборки, до сообщения установщика ещё не дошёл.
#
# Удаление. Код продукта у КАЖДОЙ сборки свой, и это не оплошность: обновление
# версией (MajorUpgrade) на том и стоит — новая сборка обязана быть другим
# продуктом, иначе Windows не поймёт, что одну надо сменить другой. Общим
# остаётся UpgradeCode, по нему они и связаны. Отсюда грабля, на которую уже
# наступили: `msiexec /x <этот файл>.msi` снимет ЭТУ сборку, но не ту, что
# поставлена прежней, — на неё ответит 1605 «такого продукта нет», и выглядит
# это как поломка установщика. Тогда снимать надо по коду установленного.
Write-Note 'Ставить и снимать — ТОЛЬКО от имени администратора.'
Write-Note ''
Write-Note "Установка:   msiexec /i `"$msi`""
Write-Note "Тихо:        msiexec /i `"$msi`" /qn   (из консоли администратора)"
Write-Note "Удаление:    msiexec /x `"$msi`"       (снимает ИМЕННО эту сборку)"
Write-Note ''
Write-Note 'Если удаление ответило 1605 — стоит другая сборка, у неё свой код.'
Write-Note 'Найти и снять её:'
Write-Note '  Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* |'
Write-Note '    Where-Object DisplayName -match TelePOS | Select-Object PSChildName'
Write-Note '  msiexec /x "{код-из-PSChildName}"'
