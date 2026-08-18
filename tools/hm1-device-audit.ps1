[CmdletBinding()]
param(
  [string]$Serial = '88X9K26526081036',
  [string]$BundleName = 'com.plagod.WiFiEdgeManager',
  [string]$AbilityName = 'EntryAbility',
  [string]$HdcPath = 'D:\devEcoStudio\DevEcoStudio\sdk\default\openharmony\toolchains\hdc.exe'
)

$ErrorActionPreference = 'Stop'
$remoteLayout = "/data/local/tmp/hm1-device-audit-$PID.json"
$localLayout = Join-Path $env:TEMP "hm1-device-audit-$PID.json"
$script:checks = 0

function Invoke-Hdc {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [switch]$AllowEmpty
  )

  $output = @(& $HdcPath @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "hdc failed ($LASTEXITCODE): $($Arguments -join ' ')`n$($output -join "`n")"
  }
  $text = ($output -join "`n").Trim()
  if (-not $AllowEmpty -and $text.Length -eq 0) {
    throw "hdc returned no output: $($Arguments -join ' ')"
  }
  return $text
}
function Write-Check {
  param([string]$Message)
  $script:checks += 1
  Write-Host ("[PASS {0:D2}] {1}" -f $script:checks, $Message)
}

function Get-Bounds {
  param([string]$Value)
  if ($Value -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
    return $null
  }
  return [pscustomobject]@{
    Left = [int]$Matches[1]
    Top = [int]$Matches[2]
    Right = [int]$Matches[3]
    Bottom = [int]$Matches[4]
    CenterX = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
    CenterY = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
  }
}

function Get-Layout {
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'dumpLayout',
    '-p', $remoteLayout, '-b', $BundleName
  ) | Out-Null
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'file', 'recv', $remoteLayout, $localLayout
  ) | Out-Null
  return Get-Content -LiteralPath $localLayout -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Find-TextNodes {
  param(
    [Parameter(Mandatory = $true)]$Node,
    [Parameter(Mandatory = $true)][string]$Text,
    $ClickableAncestor = $null
  )

  $found = @()
  $nodeBounds = Get-Bounds ([string]$Node.attributes.bounds)
  if ([string]$Node.attributes.clickable -eq 'true' -and $null -ne $nodeBounds) {
    $ClickableAncestor = $nodeBounds
  }
  $nodeText = [string]$Node.attributes.text
  $originalText = [string]$Node.attributes.originalText
  if ($nodeText -eq $Text -or $originalText -eq $Text) {
    if ($null -ne $nodeBounds -and $nodeBounds.Right -gt $nodeBounds.Left -and
      $nodeBounds.Bottom -gt $nodeBounds.Top) {
      $found += [pscustomobject]@{
        Node = $Node
        Bounds = $nodeBounds
        ClickBounds = if ($null -ne $ClickableAncestor) {
          $ClickableAncestor
        } else {
          $nodeBounds
        }
      }
    }
  }
  foreach ($child in @($Node.children)) {
    $found += @(Find-TextNodes -Node $child -Text $Text -ClickableAncestor $ClickableAncestor)
  }
  return $found
}

function Test-Text {
  param(
    [Parameter(Mandatory = $true)]$Layout,
    [Parameter(Mandatory = $true)][string]$Text
  )
  return @(Find-TextNodes -Node $Layout -Text $Text).Count -gt 0
}

function Wait-Text {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [int]$TimeoutSeconds = 8
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $layout = Get-Layout
    if (Test-Text -Layout $layout -Text $Text) {
      return $layout
    }
    Start-Sleep -Milliseconds 300
  } while ((Get-Date) -lt $deadline)
  throw "Timed out waiting for text: $Text"
}

function Select-TextNode {
  param(
    [Parameter(Mandatory = $true)]$Layout,
    [Parameter(Mandatory = $true)][string]$Text,
    [ValidateSet('Any', 'Top', 'Bottom')]
    [string]$Area = 'Any',
    [int]$NearestY = -1
  )

  $nodes = @(Find-TextNodes -Node $Layout -Text $Text)
  if ($nodes.Count -eq 0) {
    throw "Text is not visible: $Text"
  }

  $screen = Get-Bounds ([string]$Layout.attributes.bounds)
  if ($null -eq $screen) {
    throw 'The layout root does not expose valid screen bounds.'
  }
  if ($Area -eq 'Top') {
    $nodes = @($nodes | Where-Object { $_.Bounds.CenterY -lt ($screen.Bottom * 0.4) })
  } elseif ($Area -eq 'Bottom') {
    $nodes = @($nodes | Where-Object { $_.Bounds.CenterY -gt ($screen.Bottom * 0.65) })
  }
  if ($nodes.Count -eq 0) {
    throw "Text '$Text' has no node in area '$Area'."
  }

  if ($NearestY -ge 0) {
    return $nodes |
      Sort-Object { [Math]::Abs($_.Bounds.CenterY - $NearestY) } |
      Select-Object -First 1
  }
  if ($Area -eq 'Bottom') {
    return $nodes | Sort-Object { $_.Bounds.CenterY } -Descending | Select-Object -First 1
  }
  return $nodes | Sort-Object { $_.Bounds.CenterY } | Select-Object -First 1
}

function Click-Text {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [ValidateSet('Any', 'Top', 'Bottom')]
    [string]$Area = 'Any',
    [int]$NearestY = -1
  )

  $layout = Get-Layout
  $target = Select-TextNode -Layout $layout -Text $Text -Area $Area -NearestY $NearestY
  $x = [string]$target.ClickBounds.CenterX
  $y = [string]$target.ClickBounds.CenterY
  Write-Host "[ACTION] click '$Text' at ($x,$y)"
  $result = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'click',
    $x, $y
  )
  if ($result -notmatch 'No Error') {
    throw "Device did not confirm click '$Text': $result"
  }
  Start-Sleep -Milliseconds 600
}

function Press-Back {
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'keyEvent', 'Back'
  ) | Out-Null
  Start-Sleep -Milliseconds 300
}

function Swipe-Up {
  param($Layout)
  $screen = Get-Bounds ([string]$Layout.attributes.bounds)
  if ($null -eq $screen) {
    throw 'Cannot swipe without screen bounds.'
  }
  $x = [int]($screen.Right / 2)
  $fromY = [int]($screen.Bottom * 0.78)
  $toY = [int]($screen.Bottom * 0.30)
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'swipe',
    [string]$x, [string]$fromY, [string]$x, [string]$toY, '600'
  ) | Out-Null
  Start-Sleep -Milliseconds 350
}

function Reveal-Text {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [int]$MaxSwipes = 6
  )
  for ($attempt = 0; $attempt -le $MaxSwipes; $attempt += 1) {
    $layout = Get-Layout
    if (Test-Text -Layout $layout -Text $Text) {
      return $layout
    }
    if ($attempt -lt $MaxSwipes) {
      Swipe-Up -Layout $layout
    }
  }
  throw "Unable to reveal text after $MaxSwipes swipes: $Text"
}

function Start-App {
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'aa', 'start',
    '-a', $AbilityName, '-b', $BundleName
  ) | Out-Null
  Start-Sleep -Milliseconds 700
}

function Stop-App {
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'aa', 'force-stop', $BundleName
  ) -AllowEmpty | Out-Null
  Start-Sleep -Milliseconds 350
}

function Test-LoginPage {
  param($Layout)
  return (Test-Text -Layout $Layout -Text 'superadmin') -and
    (Test-Text -Layout $Layout -Text 'tenantadmin') -and
    (Test-Text -Layout $Layout -Text 'member')
}

function Return-To-Login {
  for ($attempt = 0; $attempt -lt 7; $attempt += 1) {
    $layout = Get-Layout
    if (Test-LoginPage -Layout $layout) {
      return
    }
    if (Test-Text -Layout $layout -Text '我的') {
      Click-Text -Text '我的' -Area Bottom
      Reveal-Text -Text '退出登录' | Out-Null
      Click-Text -Text '退出登录'
      $login = Wait-Text -Text 'superadmin'
      if (Test-LoginPage -Layout $login) {
        return
      }
    } else {
      Press-Back
    }
  }
  throw 'Unable to return to the login page without clearing app data.'
}

function Assert-BottomTabs {
  param([string[]]$Expected)
  $layout = Get-Layout
  foreach ($label in $Expected) {
    Select-TextNode -Layout $layout -Text $label -Area Bottom | Out-Null
  }
  Write-Check "bottom navigation: $($Expected -join ', ')"
}

function Login-PreviewAccount {
  param([string]$Account)

  $layout = Get-Layout
  if (-not (Test-LoginPage -Layout $layout)) {
    throw "Login page is not ready for account '$Account'."
  }
  $accountNode = Select-TextNode -Layout $layout -Text $Account
  Click-Text -Text '使用' -NearestY $accountNode.Bounds.CenterY
  Click-Text -Text '登录' -Area Bottom
  Wait-Text -Text '我的' | Out-Null
  Start-Sleep -Milliseconds 1800
  Write-Check "$Account login"
}

function Assert-SessionRestore {
  param(
    [string]$Account,
    [string[]]$ExpectedTabs
  )
  Stop-App
  Start-App
  Wait-Text -Text '我的' | Out-Null
  Start-Sleep -Milliseconds 1200
  Assert-BottomTabs -Expected $ExpectedTabs
  $layout = Get-Layout
  if (Test-LoginPage -Layout $layout) {
    throw "Session was not restored for '$Account'."
  }
  Write-Check "$Account session restore after force-stop"
}

function Click-TabAndWait {
  param(
    [Parameter(Mandatory = $true)][string]$Tab,
    [Parameter(Mandatory = $true)][string]$ExpectedText
  )

  for ($attempt = 0; $attempt -lt 2; $attempt += 1) {
    Click-Text -Text $Tab -Area Bottom
    try {
      return Wait-Text -Text $ExpectedText -TimeoutSeconds 2
    } catch {
      if ($attempt -ge 1) {
        throw
      }
      $layout = Get-Layout
      Select-TextNode -Layout $layout -Text $Tab -Area Bottom | Out-Null
      if (Test-Text -Layout $layout -Text $ExpectedText) {
        return $layout
      }
      Write-Host "[RETRY] first post-login '$Tab' input was not applied; retrying once after state check"
      Start-Sleep -Milliseconds 1200
    }
  }
  throw "Unable to open tab: $Tab"
}

function Assert-SuperAdminSwitch {
  $accounts = Click-TabAndWait -Tab '账号' -ExpectedText '当前没有账号记录'
  if (Test-Text -Layout $accounts -Text '当前没有可用服务') {
    throw 'Services empty state leaked into the accounts tab.'
  }

  $services = Click-TabAndWait -Tab '服务' -ExpectedText '当前没有可用服务'
  if (Test-Text -Layout $services -Text '当前没有账号记录') {
    throw 'Accounts empty state leaked into the services tab.'
  }

  $accountsAgain = Click-TabAndWait -Tab '账号' -ExpectedText '当前没有账号记录'
  if (Test-Text -Layout $accountsAgain -Text '当前没有可用服务') {
    throw 'Services empty state remained after returning to accounts.'
  }
  Write-Check 'superadmin accounts -> services -> accounts'
}

function Get-PageBackground {
  param($Layout)
  $screen = Get-Bounds ([string]$Layout.attributes.bounds)

  function Find-BackgroundNodes {
    param($Node)
    $bounds = Get-Bounds ([string]$Node.attributes.bounds)
    $color = [string]$Node.attributes.backgroundColor
    if ($null -ne $bounds -and $color.Length -gt 0 -and $color -ne '#00000000') {
      $width = $bounds.Right - $bounds.Left
      $height = $bounds.Bottom - $bounds.Top
      if ($width -ge ($screen.Right * 0.9) -and $height -ge ($screen.Bottom * 0.8)) {
        [pscustomobject]@{
          Color = $color
          Area = $width * $height
        }
      }
    }
    foreach ($child in @($Node.children)) {
      Find-BackgroundNodes -Node $child
    }
  }

  $candidates = @(Find-BackgroundNodes -Node $Layout)
  if ($candidates.Count -eq 0) {
    throw 'No full-page background color was exposed by the UI tree.'
  }
  return [string](($candidates | Sort-Object Area -Descending | Select-Object -First 1).Color)
}

function Assert-ThemeAndSentinel {
  Click-Text -Text '我的' -Area Bottom
  Reveal-Text -Text '外观' | Out-Null
  Click-Text -Text '外观'
  Wait-Text -Text '跟随系统' | Out-Null

  Click-Text -Text '浅色'
  $lightLayout = Wait-Text -Text '适合明亮环境'
  $light = Get-PageBackground -Layout $lightLayout

  Click-Text -Text '深色'
  $darkLayout = Wait-Text -Text '适合弱光环境'
  $dark = Get-PageBackground -Layout $darkLayout
  if ($dark -eq $light) {
    throw "Dark theme did not change the page background ($light)."
  }

  Click-Text -Text '浅色'
  $lightAgainLayout = Wait-Text -Text '适合明亮环境'
  $lightAgain = Get-PageBackground -Layout $lightAgainLayout
  if ($lightAgain -ne $light) {
    throw "Light theme did not restore its page background ($light -> $lightAgain)."
  }
  Write-Check "theme light -> dark -> light ($light -> $dark -> $lightAgain)"

  Press-Back
  Assert-NetworkSentinel
}

function Assert-NetworkSentinel {
  Click-Text -Text '我的' -Area Bottom
  Reveal-Text -Text '环境' | Out-Null
  Click-Text -Text '环境'
  $environment = Wait-Text -Text '网络哨兵：0 次阻断'
  if (-not (Test-Text -Layout $environment -Text '本地演示')) {
    throw 'Environment page is not in local Demo mode.'
  }
  Write-Check 'environment shows Demo network sentinel at 0'
  Press-Back
}

function Logout-CurrentAccount {
  $layout = Get-Layout
  if (-not (Test-Text -Layout $layout -Text '我的')) {
    Press-Back
  }
  Click-Text -Text '我的' -Area Bottom
  Reveal-Text -Text '退出登录' | Out-Null
  Click-Text -Text '退出登录'
  $login = Wait-Text -Text 'superadmin'
  if (-not (Test-LoginPage -Layout $login)) {
    throw 'Logout did not return to the login page.'
  }
  Write-Check 'logout returned to login'
}

try {
  if (-not (Test-Path -LiteralPath $HdcPath -PathType Leaf)) {
    throw "hdc not found: $HdcPath"
  }

  $targets = @(
    (Invoke-Hdc -Arguments @('list', 'targets')) -split '\r?\n' |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_.Length -gt 0 }
  )
  if ($targets.Count -ne 1 -or $targets[0] -ne $Serial) {
    throw "Expected only USB target '$Serial'; found: $($targets -join ', ')"
  }
  Write-Check "only approved USB target is connected: $Serial"

  Start-App
  Return-To-Login
  Write-Check 'cold start is at login without clearing app data'

  $journeys = @(
    [pscustomobject]@{
      Account = 'superadmin'
      Tabs = @('首页', '组织', '账号', '服务', '我的')
    },
    [pscustomobject]@{
      Account = 'tenantadmin'
      Tabs = @('首页', '设备', '告警', '服务', '我的')
    },
    [pscustomobject]@{
      Account = 'member'
      Tabs = @('首页', '连接', '服务', '我的')
    }
  )

  foreach ($journey in $journeys) {
    Stop-App
    Start-App
    $login = Wait-Text -Text 'superadmin'
    if (-not (Test-LoginPage -Layout $login)) {
      throw "Cold start before '$($journey.Account)' did not show login."
    }
    Login-PreviewAccount -Account $journey.Account
    Assert-BottomTabs -Expected $journey.Tabs

    if ($journey.Account -eq 'superadmin') {
      Assert-SuperAdminSwitch
    }

    Assert-SessionRestore -Account $journey.Account -ExpectedTabs $journey.Tabs

    if ($journey.Account -eq 'superadmin') {
      Assert-ThemeAndSentinel
    } else {
      Assert-NetworkSentinel
    }

    Logout-CurrentAccount
  }

  $pidText = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'pidof', $BundleName
  )
  $appPid = (($pidText -split '\s+')[0]).Trim()
  if ($appPid -notmatch '^\d+$') {
    throw "Invalid application PID: $pidText"
  }
  $errorLog = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'hilog', '-x',
    '-P', $appPid, '-L', 'ERROR,FATAL'
  ) -AllowEmpty
  $errorLines = @(
    $errorLog -split '\r?\n' |
      Where-Object { $_.Trim().Length -gt 0 }
  )
  $applicationErrors = @(
    $errorLines |
      Where-Object {
        $_ -match '/(wifi-manager|testTag):' -or
          $_ -match '(APP_CRASH|JS_CRASH|Fatal signal|uncaught exception|ArkTS runtime)'
      }
  )
  if ($applicationErrors.Count -gt 0) {
    throw "Application-authored ERROR/FATAL log is not empty for PID ${appPid}:`n$($applicationErrors -join "`n")"
  }
  Write-Check "PID $appPid has no app-authored ERROR/FATAL or crash signature ($($errorLines.Count) framework lines observed)"

  Write-Host "HM-1 DEVICE AUDIT PASSED: $script:checks checks"
} finally {
  if (Test-Path -LiteralPath $localLayout) {
    Remove-Item -LiteralPath $localLayout -Force
  }
  if (Test-Path -LiteralPath $HdcPath -PathType Leaf) {
    try {
      Invoke-Hdc -Arguments @(
        '-t', $Serial, 'shell', 'rm', '-f', $remoteLayout
      ) -AllowEmpty | Out-Null
    } catch {
      Write-Warning "Unable to remove remote audit layout: $remoteLayout"
    }
  }
}
