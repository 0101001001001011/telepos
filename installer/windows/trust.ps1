<#
.SYNOPSIS
    Установка корневого сертификата магазина в доверенные корневые центры
    Windows и его гарантированное удаление.

.DESCRIPTION
    Корень выписывает КАССА, а не установщик: он свой у каждой установки и
    появляется только после первого запуска. Поэтому установщик не может
    «вшить» готовый файл — он ставит этот скрипт и задачу планировщика, а
    корень подбирается позже, когда касса его выпишет.

    ПОЧЕМУ ПОЛЬЗОВАТЕЛЬСКОЕ ХРАНИЛИЩЕ, А НЕ МАШИННОЕ.
    Касса кладёт корень в свой профиль: %APPDATA%\TelePOS\TelePOS\pki\certs\.
    Этот файл может переписать сам пользователь — прав на это не нужно. Если бы
    мы забирали его в машинное хранилище, любой пользователь кассы мог бы
    положить туда собственный корень и стать доверенным центром ДЛЯ ВСЕЙ
    МАШИНЫ, включая чужие учётные записи. Это повышение привилегий, а не
    удобство. В пользовательском хранилище пользователь получает доверие только
    к самому себе — ровно то, что он и так может сделать руками.
    Побочная выгода: прав администратора в момент работы кассы не нужно совсем.

    Измерено 2026-08-06: программная установка в Cert:\CurrentUser\Root через
    X509Store проходит МОЛЧА, без окна подтверждения. Окно показывает оболочка
    при открытии .crt двойным щелчком, а не сам вызов CryptoAPI.

    УДАЛЕНИЕ. Хранилище пользовательское, но снимать корни при деинсталляции
    приходится за всех сразу — иначе корень пережил бы удаление программы.
    Поэтому режим -Unregister работает от SYSTEM и обходит профили, при
    необходимости подгружая куст реестра неактивного пользователя.

    Режимы:
      -Register    зарегистрировать задачу планировщика (зовёт установщик, SYSTEM)
      -Sync        поставить корень текущего пользователя (зовёт задача, обычные права)
      -Unregister  снять задачу и убрать корни У ВСЕХ пользователей (деинсталляция, SYSTEM)

.NOTES
    Только Windows PowerShell 5.1 и .NET. Модуль PKI (Import-Certificate)
    намеренно не используется: он есть не в каждой редакции Windows, а
    X509Store есть везде и даёт точный контроль над отпечатком.

    Файл обязан храниться в UTF-8 С BOM. Windows PowerShell 5.1 читает файл без
    BOM как ANSI, и кириллица превращается в мусор — скрипт при этом не просто
    печатает крякозябры, а НЕ РАЗБИРАЕТСЯ ВОВСЕ. Проверено 2026-08-06.
    Это закреплено в .gitattributes.
#>
[CmdletBinding(DefaultParameterSetName = 'Sync')]
param(
    [Parameter(ParameterSetName = 'Register')]  [switch] $Register,
    [Parameter(ParameterSetName = 'Sync')]      [switch] $Sync,
    [Parameter(ParameterSetName = 'Unregister')][switch] $Unregister,

    # Каталог установки — нужен режиму -Register, чтобы задача знала, что звать.
    # Умолчание НЕ ставится здесь: $PSScriptRoot в значении параметра пуст, если
    # скрипт запущен через `powershell.exe -File`, — а установщик зовёт именно
    # так. Разбирается ниже, в теле.
    [string] $InstallDir,

    # Явный путь к корню. Обходит поиск целиком; нужен для проверок и для
    # ручного вмешательства, когда касса лежит не там, где принято.
    [string] $RootFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Шальная кавычка на конце пути — снять.
#
# Путь каталога в MSI всегда оканчивается обратной косой (`C:\Program
# Files\TelePOS\`), а в кавычках такая косая экранирует саму кавычку: до сюда
# доезжало `C:\Program Files\TelePOS"`. Test-Path на таком пути ложен, скрипт
# бросал «регистрировать нечего», и установка откатывалась целиком. Вызов
# исправлен (TelePOS.wxs больше не передаёт -InstallDir), но защита остаётся
# здесь: следующий, кто передаст путь из MSI, наступит на то же самое, и
# отказывать ему установкой, которая откатывается без объяснения, незачем.
$InstallDir = $InstallDir.TrimEnd('"')
if ($RootFile) { $RootFile = $RootFile.TrimEnd('"') }

# Каталог, где лежит сам скрипт, — и разбирается он ЗДЕСЬ, а не в значении
# параметра.
#
# Измерено 2026-08-06 на живой установке: при запуске через
# `powershell.exe -File <скрипт>` — а установщик зовёт именно так — $PSScriptRoot
# в значении параметра ПУСТ. Значения параметров вычисляются раньше, чем
# автоматическая переменная получает значение скрипта. При запуске через
# `& <скрипт>` из другого скрипта она заполнена, поэтому проверка «руками из
# оболочки» проходила, а установка падала: Join-Path на пустой строке —
# ParameterBindingValidationException, действие возвращало 1, MSI — 1722,
# установка — 1603 и полный откат.
#
# В теле скрипта $PSScriptRoot заполнен всегда. $MyInvocation — запасной путь
# для случая, когда скрипт исполняют способом, при котором нет и его.
if (-not $InstallDir) {
    $InstallDir = if ($PSScriptRoot) { $PSScriptRoot }
                  else { Split-Path -Parent $MyInvocation.MyCommand.Path }
}

# ── Константы ────────────────────────────────────────────────────────────────

# Отдельная папка задачи — чтобы её было видно и нельзя было спутать с чужой.
$TaskFolder = 'TelePOS'
$TaskName   = 'SyncRootTrust'

# Где rk_pki держит корень установки. Путь измерен, а не предположен:
# lib/main.dart зовёт getApplicationSupportDirectory() + '\pki', а
# packages/rk_pki/rust/src/store.rs кладёт корень в подкаталог certs/.
# CompanyName и ProductName в windows/runner/Runner.rc оба «TelePOS» — отсюда
# задвоение в пути.
$RootRelativePath = 'AppData\Roaming\TelePOS\TelePOS\pki\certs\ca.cert.pem'

# Журнал отпечатков в кусте самого пользователя. Без журнала деинсталляция не
# знает, какой сертификат поставила она, а какой — человек, и либо оставит свой
# навсегда, либо снесёт чужой.
$JournalSubKey = 'SOFTWARE\TelePOS\TrustedRoots'

# Пользовательское хранилище доверенных корневых центров в реестре. Именно сюда
# CryptoAPI кладёт то, что мы добавляем через X509Store, и именно отсюда режим
# -Unregister удаляет корни неактивных пользователей.
$RootStoreSubKey = 'SOFTWARE\Microsoft\SystemCertificates\Root\Certificates'

function Write-Step { param([string] $Message) Write-Host "[telepos-trust] $Message" }

# ── Режим -Sync: работает от имени обычного пользователя ─────────────────────

function Get-CertificateIfAuthority {
    <#
        Читает файл как сертификат и отдаёт его, только если это удостоверяющий
        центр. Ставить в доверенные корневые ЦС обычный лист нельзя — это молча
        расширило бы доверие совсем не на то.
    #>
    param([string] $Path)

    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 `
            -ArgumentList (, [System.IO.File]::ReadAllBytes($Path))
    } catch {
        Write-Step "не читается как сертификат: $Path — $($_.Exception.Message)"
        return $null
    }

    # Расширение достаём с приведением типа вручную: коллекция Extensions не
    # гарантирует типизированный объект, а под Set-StrictMode обращение к
    # несуществующему свойству — отказ, а не $null.
    $isCa = $false
    foreach ($ext in $cert.Extensions) {
        if ($ext.Oid.Value -ne '2.5.29.19') { continue }
        $basic = $ext -as [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]
        if ($null -eq $basic) {
            $basic = New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension
            $basic.CopyFrom($ext)
        }
        $isCa = $basic.CertificateAuthority
    }

    if (-not $isCa) { Write-Step "не удостоверяющий центр, пропускаем: $Path"; return $null }
    return $cert
}

function Invoke-Sync {
    <#
        Ставит корень ТЕКУЩЕГО пользователя в его же хранилище.

        Это синхронизация, а не «добавить»: если стор кассы пересоздали, она
        выпишет новый корень, а старый остался бы доверенным на десять лет.
        Поэтому всё, что записано в журнале и не совпало с нынешним корнем,
        снимается.
    #>
    $path = if ($RootFile) { $RootFile } else { Join-Path $env:USERPROFILE $RootRelativePath }

    $journalPath = "HKCU:\$JournalSubKey"
    $journalled  = @()
    if (Test-Path $journalPath) {
        $journalled = @((Get-Item $journalPath).GetValueNames() | Where-Object { $_ -match '^[0-9A-Fa-f]{40}$' })
    }

    $cert = $null
    if (Test-Path $path) { $cert = Get-CertificateIfAuthority -Path $path }
    else { Write-Step "корня нет ($path) — касса ещё не выписала свой." }

    $current = if ($cert) { $cert.Thumbprint.ToUpperInvariant() } else { $null }

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', 'CurrentUser')
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    try {
        # Сначала снимаем устаревшее. Если сделать наоборот и второй шаг упадёт,
        # машина останется без доверия к своей же кассе.
        foreach ($old in $journalled) {
            if ($old -eq $current) { continue }
            $found = $store.Certificates.Find(
                [System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint, $old, $false)
            foreach ($c in $found) { $store.Remove($c) }
            Remove-ItemProperty -Path $journalPath -Name $old -ErrorAction SilentlyContinue
            Write-Step "снят устаревший корень $old"
        }

        if (-not $cert) { return 0 }

        # Add идемпотентен: тот же отпечаток повторно ничего не меняет.
        $store.Add($cert)
    } finally { $store.Close() }

    if (-not (Test-Path $journalPath)) { New-Item -Path $journalPath -Force | Out-Null }
    New-ItemProperty -Path $journalPath -Name $current `
        -Value "$(Get-Date -Format 'o') $path" -PropertyType String -Force | Out-Null

    Write-Step "корень магазина доверен: $($cert.Subject) [$current]"
    return 0
}

# ── Режим -Register: работает от имени SYSTEM ────────────────────────────────

function Invoke-Register {
    <#
        Регистрирует задачу, которая зовёт -Sync ОТ ИМЕНИ ВОШЕДШЕГО
        ПОЛЬЗОВАТЕЛЯ, без повышения прав.

        ПОЧЕМУ задача, а не «касса просит прав». Кассиру нельзя показывать ни
        одного окна: измерено, что вручную корень ставится в три приёма, и никто
        этого делать не будет. Пользовательскому хранилищу прав не нужно вовсе,
        поэтому задача выполняется с обычными правами и UAC не всплывает никогда.
    #>
    $script = Join-Path $InstallDir 'trust.ps1'
    if (-not (Test-Path $script)) { throw "не найден $script — регистрировать нечего" }

    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()

    $root = $svc.GetFolder('\')
    try { $folder = $root.GetFolder($TaskFolder) } catch { $folder = $root.CreateFolder($TaskFolder) }

    $def = $svc.NewTask(0)
    $def.RegistrationInfo.Description = 'Ставит корневой сертификат магазина TelePOS в доверенные корневые центры пользователя.'
    $def.RegistrationInfo.Author      = 'TelePOS'

    # 9 = TASK_TRIGGER_LOGON. Именно вход — момент, когда появляется профиль и
    # хранилище того пользователя, которому нужно доверие. Триггера на загрузку
    # тут быть не может: до входа пользовательского хранилища не существует.
    [void] $def.Triggers.Create(9)

    $action = $def.Actions.Create(0)   # 0 = TASK_ACTION_EXEC
    $action.Path = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    # -ExecutionPolicy Bypass: политика на машине заказчика нам не подконтрольна,
    # а сам скрипт лежит в Program Files, куда без прав администратора не пишут.
    $action.Arguments = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Sync"

    $def.Settings.Enabled                    = $true
    $def.Settings.StartWhenAvailable         = $true
    $def.Settings.DisallowStartIfOnBatteries = $false
    $def.Settings.StopIfGoingOnBatteries     = $false
    $def.Settings.ExecutionTimeLimit         = 'PT5M'
    $def.Settings.MultipleInstances          = 2      # 2 = IgnoreNew

    # Задача принадлежит ГРУППЕ «Пользователи», а не конкретному человеку:
    # на кассе заводят по учётной записи на смену, и корень нужен каждой.
    # 4 = TASK_LOGON_GROUP, RunLevel 0 = TASK_RUNLEVEL_LUA (без повышения).
    $def.Principal.GroupId   = 'S-1-5-32-545'
    $def.Principal.LogonType = 4
    $def.Principal.RunLevel  = 0

    # SDDL: администраторы и SYSTEM — полный доступ, обычные пользователи —
    # чтение и ЗАПУСК. Без права запуска касса не смогла бы попросить задачу
    # отработать сразу после того, как выписала корень, и доверие появилось бы
    # только при следующем входе в систему.
    $sddl = 'D:(A;;GA;;;BA)(A;;GA;;;SY)(A;;GRGX;;;BU)'

    # 6 = TASK_CREATE_OR_UPDATE, 4 = TASK_LOGON_GROUP
    [void] $folder.RegisterTaskDefinition($TaskName, $def, 6, $null, $null, 4, $sddl)
    Write-Step "задача \$TaskFolder\$TaskName зарегистрирована."
    return 0
}

# ── Режим -Unregister: работает от имени SYSTEM ──────────────────────────────

function Get-UserProfiles {
    <#
        Профили берём из реестра, а не перечислением C:\Users: профиль может
        быть перенаправлен на другой диск. Служебные профили отсеиваем — касса
        под ними не работает, а C:\Windows\System32\config\systemprofile ещё и
        недоступен, и Test-Path по нему бросает отказ доступа.
    #>
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    if (-not (Test-Path $key)) { return @() }
    return @(
        Get-ChildItem $key | ForEach-Object {
            $path = (Get-ItemProperty -Path $_.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
            if ($path -and $path -notmatch '\\(ServiceProfiles|config\\systemprofile)\\?' -and (Test-Path $path -ErrorAction SilentlyContinue)) {
                [pscustomobject]@{ Sid = $_.PSChildName; Path = $path }
            }
        }
    )
}

function Clear-TrustForHive {
    <#
        Снимает корни в одном кусте пользователя.
        $HiveRoot — путь вида 'Registry::HKEY_USERS\<SID>'.
        Возвращает число снятых сертификатов.
    #>
    param([string] $HiveRoot)

    $journalPath = "$HiveRoot\$JournalSubKey"
    if (-not (Test-Path $journalPath)) { return 0 }

    $thumbs = @((Get-Item $journalPath).GetValueNames() | Where-Object { $_ -match '^[0-9A-Fa-f]{40}$' })
    $removed = 0
    foreach ($thumb in $thumbs) {
        # Пользовательское хранилище — это ключ реестра. Удаление ключа с
        # отпечатком и есть снятие сертификата с доверия; X509Store тут
        # неприменим, потому что открыть чужое хранилище им нельзя.
        $certKey = "$HiveRoot\$RootStoreSubKey\$thumb"
        if (Test-Path $certKey) {
            Remove-Item $certKey -Recurse -Force -ErrorAction SilentlyContinue
            $removed++
            Write-Step "корень $thumb снят с доверия."
        } else {
            Write-Step "корень $thumb в хранилище не найден — вероятно, снят вручную."
        }
    }

    # Журнал и наш раздел целиком: следов оставаться не должно.
    Remove-Item "$HiveRoot\SOFTWARE\TelePOS" -Recurse -Force -ErrorAction SilentlyContinue
    return $removed
}

function Invoke-Unregister {
    <#
        Деинсталляция. Оставленный корневой центр — это дыра, которая живёт
        после удаления программы, поэтому снятие корней делается ПЕРВЫМ: если
        удаление задачи упадёт, доверие уже снято.

        Хранилища пользовательские, а деинсталляцию может запустить кто угодно
        из администраторов, поэтому обходим все профили, а не только свой.
    #>
    $removed = 0

    # Кусты, уже загруженные (пользователь в системе), видны прямо в HKEY_USERS.
    $loaded = @(Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
                ForEach-Object { $_.PSChildName })

    foreach ($profile in (Get-UserProfiles)) {
        $sid = $profile.Sid
        try {
            if ($loaded -contains $sid) {
                $removed += Clear-TrustForHive -HiveRoot "Registry::HKEY_USERS\$sid"
                continue
            }

            # Пользователь не в системе: подгружаем его куст с диска, чистим и
            # обязательно отгружаем обратно — иначе профиль останется занят и
            # человек получит временный профиль при следующем входе.
            $hiveFile = Join-Path $profile.Path 'NTUSER.DAT'
            if (-not (Test-Path $hiveFile)) { continue }

            $mount = "TelePOS_$($sid -replace '[^0-9]', '')"
            $null = & reg.exe load "HKU\$mount" "$hiveFile" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Step "куст $sid занят, пропускаем."
                continue
            }
            try {
                $removed += Clear-TrustForHive -HiveRoot "Registry::HKEY_USERS\$mount"
            } finally {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()   # иначе куст не отгружается
                $null = & reg.exe unload "HKU\$mount" 2>&1
            }
        } catch {
            # Деинсталляция не имеет права падать: иначе программа останется
            # наполовину удалённой. Сообщаем и идём дальше.
            Write-Step "профиль $sid : $($_.Exception.Message)"
        }
    }

    try {
        $svc = New-Object -ComObject Schedule.Service
        $svc.Connect()
        $folder = $svc.GetFolder($TaskFolder)
        $folder.DeleteTask($TaskName, 0)
        $svc.GetFolder('\').DeleteFolder($TaskFolder, 0)
        Write-Step "задача \$TaskFolder\$TaskName снята."
    } catch {
        Write-Step "задача уже отсутствует: $($_.Exception.Message)"
    }

    Write-Step "снято корней: $removed."
    return 0
}

# ── Точка входа ──────────────────────────────────────────────────────────────

switch ($PSCmdlet.ParameterSetName) {
    'Register'   { exit (Invoke-Register)   }
    'Unregister' { exit (Invoke-Unregister) }
    default      { exit (Invoke-Sync)       }
}
