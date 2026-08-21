[CmdletBinding()]
param(
  [string]$Serial = '88X9K26526081036',
  [string]$BundleName = 'com.plagod.WiFiEdgeManager',
  [string]$AbilityName = 'EntryAbility',
  [string]$HdcPath = 'D:\devEcoStudio\DevEcoStudio\sdk\default\openharmony\toolchains\hdc.exe',
  [switch]$AccountRefreshOnly,
  [switch]$Hm3Only
)

$ErrorActionPreference = 'Stop'
$remoteLayout = "/data/local/tmp/hm1-device-audit-$PID.json"
$localLayout = Join-Path $env:TEMP "hm1-device-audit-$PID.json"
$script:checks = 0
$script:observedAppPids = @()

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
  $hintText = [string]$Node.attributes.hint
  $accessibilityText = [string]$Node.attributes.accessibilityText
  if ($nodeText -eq $Text -or $originalText -eq $Text -or
    $hintText -eq $Text -or $accessibilityText -eq $Text) {
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

function Find-ClickableNodes {
  param(
    [Parameter(Mandatory = $true)]$Node
  )

  $found = @()
  $bounds = Get-Bounds ([string]$Node.attributes.bounds)
  if ([string]$Node.attributes.clickable -eq 'true' -and $null -ne $bounds -and
    $bounds.Right -gt $bounds.Left -and $bounds.Bottom -gt $bounds.Top) {
    $found += [pscustomobject]@{
      Node = $Node
      Bounds = $bounds
    }
  }
  foreach ($child in @($Node.children)) {
    $found += @(Find-ClickableNodes -Node $child)
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

function Wait-AnyText {
  param(
    [Parameter(Mandatory = $true)][string[]]$Texts,
    [int]$TimeoutSeconds = 8
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $layout = Get-Layout
    foreach ($text in $Texts) {
      if (Test-Text -Layout $layout -Text $text) {
        return $layout
      }
    }
    Start-Sleep -Milliseconds 300
  } while ((Get-Date) -lt $deadline)
  throw "Timed out waiting for any text: $($Texts -join ', ')"
}

function Wait-TextGone {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [int]$TimeoutSeconds = 8
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $layout = Get-Layout
    if (-not (Test-Text -Layout $layout -Text $Text)) {
      return $layout
    }
    Start-Sleep -Milliseconds 300
  } while ((Get-Date) -lt $deadline)
  throw "Timed out waiting for text to disappear: $Text"
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

function Click-TopRightButton {
  $layout = Get-Layout
  $screen = Get-Bounds ([string]$layout.attributes.bounds)
  if ($null -eq $screen) {
    throw 'The layout root does not expose valid screen bounds.'
  }
  $candidates = @(
    Find-ClickableNodes -Node $layout |
      Where-Object {
        $_.Bounds.CenterX -gt ($screen.Right * 0.65) -and
        $_.Bounds.CenterY -lt ($screen.Bottom * 0.25)
      } |
      Sort-Object { $_.Bounds.CenterY }, { -1 * $_.Bounds.CenterX }
  )
  if ($candidates.Count -eq 0) {
    throw 'No top-right clickable control is visible.'
  }
  $target = $candidates[0].Bounds
  Write-Host "[ACTION] click top-right control at ($($target.CenterX),$($target.CenterY))"
  $result = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'click',
    [string]$target.CenterX, [string]$target.CenterY
  )
  if ($result -notmatch 'No Error') {
    throw "Device did not confirm the top-right click: $result"
  }
  Start-Sleep -Milliseconds 600
}

function Input-TextAtPlaceholder {
  param(
    [Parameter(Mandatory = $true)][string]$Placeholder,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $layout = Get-Layout
  $target = Select-TextNode -Layout $layout -Text $Placeholder
  $x = [string]$target.ClickBounds.CenterX
  $y = [string]$target.ClickBounds.CenterY
  Write-Host "[ACTION] input text at '$Placeholder' ($x,$y)"
  $focusResult = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'click',
    $x, $y
  )
  if ($focusResult -notmatch 'No Error') {
    throw "Device did not confirm input focus at '$Placeholder': $focusResult"
  }
  Start-Sleep -Milliseconds 300
  $result = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'inputText',
    $x, $y, $Value
  )
  if ($result -notmatch 'No Error') {
    throw "Device did not confirm text input at '$Placeholder': $result"
  }
  Start-Sleep -Milliseconds 300
}

function Press-Back {
  Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'uitest', 'uiInput', 'keyEvent', 'Back'
  ) | Out-Null
  Start-Sleep -Milliseconds 300
}

function Back-UntilText {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [int]$MaxBacks = 4
  )
  for ($attempt = 0; $attempt -le $MaxBacks; $attempt += 1) {
    $layout = Get-Layout
    if (Test-Text -Layout $layout -Text $Text) {
      return $layout
    }
    if ($attempt -lt $MaxBacks) {
      Press-Back
    }
  }
  throw "Unable to return to text after $MaxBacks back actions: $Text"
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
  $pidText = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'pidof', $BundleName
  ) -AllowEmpty
  $appPid = (($pidText -split '\s+')[0]).Trim()
  if ($appPid -match '^\d+$' -and $script:observedAppPids -notcontains $appPid) {
    $script:observedAppPids += $appPid
  }
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
      Open-ProfileTab
      Reveal-Text -Text '退出登录' | Out-Null
      Click-Text -Text '退出登录'
      $login = Wait-Text -Text 'superadmin'
      if (Test-LoginPage -Layout $login) {
        return
      }
    } elseif (Test-Text -Layout $layout -Text '返回平台') {
      Click-Text -Text '返回平台'
      Wait-Text -Text '我的' | Out-Null
    } else {
      Press-Back
      Start-App
    }
  }
  Start-App
  try {
    $login = Wait-Text -Text 'superadmin'
    if (Test-LoginPage -Layout $login) {
      return
    }
  } catch {
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

function Open-ProfileTab {
  Click-TabAndWait -Tab '我的' -ExpectedText '账号与应用' | Out-Null
}

function Assert-SuperAdminSwitch {
  $accounts = Click-TabAndWait -Tab '账号' -ExpectedText '删除审核'
  if (Test-Text -Layout $accounts -Text '平台可用服务') {
    throw 'Services content leaked into the accounts tab.'
  }

  $services = Click-TabAndWait -Tab '服务' -ExpectedText '平台可用服务'
  if (Test-Text -Layout $services -Text '删除审核') {
    throw 'Accounts content leaked into the services tab.'
  }

  $accountsAgain = Click-TabAndWait -Tab '账号' -ExpectedText '删除审核'
  if (Test-Text -Layout $accountsAgain -Text '平台可用服务') {
    throw 'Services content remained after returning to accounts.'
  }
  Write-Check 'superadmin accounts -> services -> accounts'
}

function Reset-Hm2DemoState {
  Open-ProfileTab
  Reveal-Text -Text '环境' | Out-Null
  Click-Text -Text '环境'
  Wait-Text -Text '重置本地演示' | Out-Null
  Click-Text -Text '重置本地演示'
  Wait-Text -Text '重置' | Out-Null
  Click-Text -Text '重置'
  Wait-Text -Text '本地演示已重置' | Out-Null
  Write-Check 'HM-2 Demo state reset without clearing app data'
  Press-Back
}

function Set-Hm2Scenario {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  Open-ProfileTab
  Reveal-Text -Text '环境' | Out-Null
  Click-Text -Text '环境'
  Wait-Text -Text '平台场景' | Out-Null
  for ($attempt = 0; $attempt -lt 10; $attempt += 1) {
    $layout = Get-Layout
    if (Test-Text -Layout $layout -Text $Label) {
      Press-Back
      Wait-Text -Text '我的' | Out-Null
      return
    }
    Click-Text -Text '切换'
  }
  throw "Unable to select HM-2 scenario: $Label"
}

function Assert-Hm2Scenarios {
  Set-Hm2Scenario -Label '空数据'
  Click-TabAndWait -Tab '组织' -ExpectedText '没有符合条件的组织' | Out-Null
  Write-Check 'HM-2 EMPTY page state'

  Set-Hm2Scenario -Label '筛选无结果'
  Click-Text -Text '组织' -Area Bottom
  Wait-Text -Text '选择组织' | Out-Null
  Input-TextAtPlaceholder -Placeholder '组织名称或标识' -Value 'edge'
  Press-Back
  Click-Text -Text '搜索'
  Wait-Text -Text '没有符合条件的组织' | Out-Null
  Write-Check 'HM-2 FILTER_EMPTY page state'

  Set-Hm2Scenario -Label '延迟加载'
  Click-Text -Text '首页' -Area Bottom
  Wait-Text -Text '正在更新平台摘要' -TimeoutSeconds 2 | Out-Null
  Wait-Text -Text '平台概览' | Out-Null
  Write-Check 'HM-2 LOADING page state'

  $readErrors = @(
    [pscustomobject]@{ Label = '局部失败'; Message = '平台服务摘要暂时不可用' },
    [pscustomobject]@{ Label = '无权限'; Message = '当前账号无权访问平台治理能力' },
    [pscustomobject]@{ Label = '请求限流'; Message = '请求过于频繁，请稍后再试' },
    [pscustomobject]@{ Label = '依赖不可用'; Message = '平台依赖暂时不可用' }
  )
  foreach ($scenario in $readErrors) {
    Set-Hm2Scenario -Label $scenario.Label
    Click-Text -Text '首页' -Area Bottom
    Wait-Text -Text $scenario.Message | Out-Null
    Click-Text -Text $scenario.Message
    Wait-Text -Text $scenario.Message | Out-Null
    Write-Check "HM-2 $($scenario.Label) error and retry state"
  }

  Set-Hm2Scenario -Label '正常'
  Click-TabAndWait -Tab '首页' -ExpectedText '平台概览' | Out-Null
  Write-Check 'HM-2 scenario recovery to NORMAL'
}

function Assert-Hm2SuperAdminJourney {
  Reset-Hm2DemoState

  $homeLayout = Click-TabAndWait -Tab '首页' -ExpectedText '平台概览'
  foreach ($marker in @('平台治理', '常用操作')) {
    if (-not (Test-Text -Layout $homeLayout -Text $marker)) {
      throw "Platform home is missing: $marker"
    }
  }
  Write-Check 'P100 platform home'

  $tenants = Click-TabAndWait -Tab '组织' -ExpectedText '选择组织'
  foreach ($marker in @('全部', '可用', '停用')) {
    if (-not (Test-Text -Layout $tenants -Text $marker)) {
      throw "Tenant list is missing: $marker"
    }
  }
  Write-Check 'P101 tenant list'

  Wait-Text -Text '加载更多' | Out-Null
  Click-Text -Text '加载更多'
  Wait-Text -Text '共 4 个组织' | Out-Null
  Click-Text -Text '停用'
  $disabledTenants = Wait-Text -Text '历史项目归档组'
  if (Test-Text -Layout $disabledTenants -Text '边缘网络实验室') {
    throw 'Tenant status filter retained an active tenant.'
  }
  Click-Text -Text '全部'
  Wait-Text -Text '边缘网络实验室' | Out-Null
  Write-Check 'P101 pagination and status filtering'

  Click-TopRightButton
  $create = Wait-Text -Text '创建组织'
  foreach ($marker in @('组织标识', '组织名称', '负责人账号', '时区')) {
    if (-not (Test-Text -Layout $create -Text $marker)) {
      throw "Tenant create page is missing: $marker"
    }
  }
  Write-Check 'P102 tenant create form'

  Click-Text -Text '创建组织' -Area Bottom
  Wait-Text -Text '请输入组织标识' | Out-Null
  Input-TextAtPlaceholder -Placeholder '例如 branch-office' -Value 'hm2-audit'
  Input-TextAtPlaceholder -Placeholder '输入对外显示名称' -Value 'HM2 Audit Org'
  Input-TextAtPlaceholder -Placeholder '输入已有正常账号' -Value 'trial-user'
  Press-Back
  Reveal-Text -Text '创建组织' | Out-Null
  Click-Text -Text '创建组织' -Area Bottom
  Wait-Text -Text '选择组织' | Out-Null
  Wait-Text -Text 'HM2 Audit Org' | Out-Null
  Write-Check 'P102 validation and actual organization creation'

  Click-TopRightButton
  Wait-Text -Text '创建组织' | Out-Null
  Input-TextAtPlaceholder -Placeholder '例如 branch-office' -Value 'hm2-audit'
  Input-TextAtPlaceholder -Placeholder '输入对外显示名称' -Value 'Duplicate HM2 Org'
  Input-TextAtPlaceholder -Placeholder '输入已有正常账号' -Value 'trial-user'
  Press-Back
  Reveal-Text -Text '创建组织' | Out-Null
  Click-Text -Text '创建组织' -Area Bottom
  Wait-Text -Text '组织标识已存在' | Out-Null
  Write-Check 'P102 duplicate organization conflict'
  Press-Back
  Wait-Text -Text '选择组织' | Out-Null

  Click-Text -Text '边缘网络实验室'
  Wait-Text -Text '开始管理' | Out-Null
  Input-TextAtPlaceholder -Placeholder '简要说明为什么需要管理该组织' -Value 'HM2 audit'
  Press-Back
  Click-Text -Text '开始管理'
  $tenantDetail = Wait-Text -Text '组织详情'
  if (-not (Test-Text -Layout $tenantDetail -Text '平台代管')) {
    throw 'Managed tenant detail does not expose PLATFORM_TENANT context.'
  }
  Write-Check 'P103 PLATFORM_TENANT detail'

  Reveal-Text -Text '保存资料' | Out-Null
  Click-Text -Text '保存资料'
  Wait-Text -Text '组织资料已更新' | Out-Null
  Reveal-Text -Text '停用组织' | Out-Null
  Click-Text -Text '停用组织'
  Wait-Text -Text '停用' | Out-Null
  Click-Text -Text '停用'
  Wait-Text -Text '组织已停用' | Out-Null
  Reveal-Text -Text '启用组织' | Out-Null
  Click-Text -Text '启用组织'
  Wait-Text -Text '启用' | Out-Null
  Click-Text -Text '启用'
  Wait-Text -Text '组织已启用' | Out-Null
  Write-Check 'P103 profile save and reversible status transition'

  Reveal-Text -Text '成员列表' | Out-Null
  Click-Text -Text '成员列表'
  $members = Wait-Text -Text '组织成员'
  foreach ($marker in @('平台只读', '平台代管仅可查看成员，成员管理由组织负责人执行。')) {
    if (-not (Test-Text -Layout $members -Text $marker)) {
      throw "Tenant members page is missing: $marker"
    }
  }
  Write-Check 'P104 managed tenant members are read-only'
  Input-TextAtPlaceholder -Placeholder '账号、昵称或角色' -Value '管理员'
  Press-Back
  Click-Text -Text '搜索'
  $filteredMembers = Wait-Text -Text '网络管理员'
  if (Test-Text -Layout $filteredMembers -Text '实验室负责人') {
    throw 'Managed tenant member filtering retained a non-matching member.'
  }
  Write-Check 'P104 managed tenant member filtering'
  Press-Back
  Wait-Text -Text '组织详情' | Out-Null

  Click-Text -Text '返回平台'
  $platformRoot = Wait-AnyText -Texts @('平台概览', '选择组织')
  Assert-BottomTabs -Expected @('首页', '组织', '账号', '服务', '我的')
  if (-not (Test-Text -Layout $platformRoot -Text '选择组织')) {
    Click-TabAndWait -Tab '组织' -ExpectedText '选择组织' | Out-Null
  }
  Stop-App
  Start-App
  $platformRestored = Wait-AnyText -Texts @('平台概览', '选择组织')
  if (Test-Text -Layout $platformRestored -Text '组织详情') {
    throw 'Managed tenant detail remained after returning to PLATFORM.'
  }
  Assert-BottomTabs -Expected @('首页', '组织', '账号', '服务', '我的')
  if (-not (Test-Text -Layout $platformRestored -Text '选择组织')) {
    Click-TabAndWait -Tab '组织' -ExpectedText '选择组织' | Out-Null
  }
  Write-Check 'return to PLATFORM clears managed route and survives force-stop'

  Click-Text -Text '边缘网络实验室'
  Wait-Text -Text '开始管理' | Out-Null
  Input-TextAtPlaceholder -Placeholder '简要说明为什么需要管理该组织' -Value 'cache audit'
  Press-Back
  Click-Text -Text '开始管理'
  Wait-Text -Text '组织详情' | Out-Null
  Stop-App
  Start-App
  $transientManaged = Wait-AnyText -Texts @('平台概览', '选择组织')
  if (Test-Text -Layout $transientManaged -Text '组织详情') {
    throw 'Transient managed tenant route survived process restart.'
  }
  Write-Check 'managed tenant can be re-entered and cold start returns to PLATFORM'

  $accounts = Click-TabAndWait -Tab '账号' -ExpectedText '删除审核'
  if (-not (Test-Text -Layout $accounts -Text '账号')) {
    throw 'Platform account list is not visible.'
  }
  Write-Check 'P105 platform accounts'

  Click-Text -Text '实验室负责人'
  $accountDetail = Wait-Text -Text '账号详情'
  foreach ($marker in @('账号治理', '提交删除审核')) {
    if (-not (Test-Text -Layout $accountDetail -Text $marker)) {
      throw "Account detail is missing: $marker"
    }
  }
  Write-Check 'P106 account detail'

  Click-Text -Text '停用账号'
  Wait-Text -Text '停用' | Out-Null
  Click-Text -Text '停用'
  Wait-Text -Text '账号已停用' | Out-Null
  Click-Text -Text '恢复账号'
  Wait-Text -Text '恢复' | Out-Null
  Click-Text -Text '恢复'
  Wait-Text -Text '账号已恢复' | Out-Null
  Reveal-Text -Text '说明删除原因，审核通过后才会删除' | Out-Null
  Input-TextAtPlaceholder -Placeholder '说明删除原因，审核通过后才会删除' -Value 'HM2 audit deletion'
  Press-Back
  Reveal-Text -Text '提交审核' | Out-Null
  Click-Text -Text '提交审核'
  Wait-Text -Text '删除申请已提交审核' | Out-Null
  Write-Check 'P106 reversible status transition and deletion request'
  Press-Back
  Wait-Text -Text '删除审核' | Out-Null
  Wait-Text -Text '删除待审核' | Out-Null
  Write-Check 'account list refreshes after returning from account detail'

  Click-Text -Text '删除审核'
  $reviews = Wait-Text -Text '删除审核'
  if (-not (Test-Text -Layout $reviews -Text '待审核')) {
    throw 'Pending account review filter is not visible.'
  }
  Write-Check 'P107 deletion reviews'

  Click-Text -Text '值班成员'
  $reviewDetail = Wait-Text -Text '审核详情'
  foreach ($marker in @('删除原因', '驳回', '通过')) {
    if (-not (Test-Text -Layout $reviewDetail -Text $marker)) {
      throw "Review detail is missing: $marker"
    }
  }
  Write-Check 'P132 deletion review detail'
  Click-Text -Text '通过'
  Wait-Text -Text '确认通过' | Out-Null
  Click-Text -Text '确认通过'
  Wait-Text -Text '已通过' | Out-Null
  Write-Check 'account review approval moves the account to deleted state'
  Press-Back
  Wait-Text -Text '删除审核' | Out-Null
  Wait-TextGone -Text '值班成员' | Out-Null
  Write-Check 'approved review is removed from the pending list after back navigation'
  Press-Back
  Wait-Text -Text '删除审核' | Out-Null

  Reset-Hm2DemoState
  Click-TabAndWait -Tab '账号' -ExpectedText '删除审核' | Out-Null
  Click-Text -Text '删除审核'
  Wait-Text -Text '删除审核' | Out-Null
  Click-Text -Text '值班成员'
  Wait-Text -Text '审核详情' | Out-Null
  Click-Text -Text '驳回'
  Wait-Text -Text '确认驳回' | Out-Null
  Click-Text -Text '确认驳回'
  Wait-Text -Text '已驳回' | Out-Null
  Write-Check 'account review rejection remains isolated after Demo reset'
  Press-Back
  Wait-Text -Text '删除审核' | Out-Null
  Wait-TextGone -Text '值班成员' | Out-Null
  Write-Check 'rejected review is removed from the pending list after back navigation'
  Press-Back
  Wait-Text -Text '删除审核' | Out-Null

  $services = Click-TabAndWait -Tab '服务' -ExpectedText '平台可用服务'
  if (-not (Test-Text -Layout $services -Text 'SaaS 套餐')) {
    throw 'Platform services does not expose SaaS plans.'
  }
  Write-Check 'P121 platform services'

  Click-Text -Text 'SaaS 套餐'
  $plans = Wait-Text -Text 'SaaS 套餐'
  foreach ($marker in @('已发布', '草稿')) {
    if (-not (Test-Text -Layout $plans -Text $marker)) {
      throw "SaaS plan list is missing: $marker"
    }
  }
  Write-Check 'P109 read-only SaaS plan list'

  Click-Text -Text '草稿'
  $draftPlans = Wait-Text -Text '企业版 v1.4'
  if (Test-Text -Layout $draftPlans -Text '基础版 v2.1') {
    throw 'SaaS status filter retained a published plan.'
  }
  Click-Text -Text '全部'
  Wait-Text -Text '基础版 v2.1' | Out-Null
  Input-TextAtPlaceholder -Placeholder '套餐名称、编码或版本' -Value 'PRO'
  Press-Back
  Click-Text -Text '搜索'
  $searchedPlans = Wait-Text -Text '专业版 v3.0'
  foreach ($writeMarker in @('新建套餐', '编辑套餐', '发布套餐')) {
    if (Test-Text -Layout $searchedPlans -Text $writeMarker) {
      throw "HM-2 SaaS list exposed write action: $writeMarker"
    }
  }
  Write-Check 'P109 SaaS search, status filter, and read-only boundary'

  Click-Text -Text '专业版 v3.0'
  $planDetail = Wait-Text -Text '套餐详情'
  foreach ($marker in @('只读', '套餐信息', '功能范围')) {
    if (-not (Test-Text -Layout $planDetail -Text $marker)) {
      throw "SaaS plan detail is missing: $marker"
    }
  }
  Write-Check 'P110 read-only SaaS plan detail'
  Press-Back
  Wait-Text -Text 'SaaS 套餐' | Out-Null
  Press-Back
  Wait-Text -Text '平台可用服务' | Out-Null

  Assert-Hm2Scenarios
  Reset-Hm2DemoState
  Assert-NetworkSentinel
  Write-Check 'HM-2 journey completed with zero Demo network attempts'
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
  Open-ProfileTab
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
  Open-ProfileTab
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
  Open-ProfileTab
  Reveal-Text -Text '退出登录' | Out-Null
  Click-Text -Text '退出登录'
  $login = Wait-Text -Text 'superadmin'
  if (-not (Test-LoginPage -Layout $login)) {
    throw 'Logout did not return to the login page.'
  }
  Write-Check 'logout returned to login'
}

function Assert-Hm2AccountRefresh {
  Login-PreviewAccount -Account 'superadmin'
  Assert-BottomTabs -Expected @('首页', '组织', '账号', '服务', '我的')
  Assert-SuperAdminSwitch
  Reset-Hm2DemoState
  Click-TabAndWait -Tab '账号' -ExpectedText '删除审核' | Out-Null
  Click-Text -Text '实验室负责人'
  Wait-Text -Text '账号详情' | Out-Null
  Reveal-Text -Text '说明删除原因，审核通过后才会删除' | Out-Null
  Input-TextAtPlaceholder -Placeholder '说明删除原因，审核通过后才会删除' -Value 'HM2 refresh audit'
  Press-Back
  Reveal-Text -Text '提交审核' | Out-Null
  Click-Text -Text '提交审核'
  Wait-Text -Text '删除申请已提交审核' | Out-Null
  Press-Back
  Wait-Text -Text '删除待审核' | Out-Null
  Write-Check 'account list refreshes after returning from account detail'
  Assert-NetworkSentinel
}

function Assert-VisibleMarkers {
  param(
    [Parameter(Mandatory = $true)]$Layout,
    [Parameter(Mandatory = $true)][string[]]$Markers,
    [Parameter(Mandatory = $true)][string]$Scope
  )
  foreach ($marker in $Markers) {
    if (-not (Test-Text -Layout $Layout -Text $marker)) {
      throw "$Scope is missing: $marker"
    }
  }
}

function Assert-Hm3DeviceCrud {
  Click-TabAndWait -Tab '设备' -ExpectedText '设备' | Out-Null
  Click-TopRightButton
  Wait-Text -Text '创建设备' | Out-Null
  Input-TextAtPlaceholder -Placeholder '设备编码' -Value 'HM3-AUDIT-01'
  Input-TextAtPlaceholder -Placeholder '设备名称' -Value 'HM3-Audit-Gateway'
  Press-Back
  Click-Text -Text '保存设备'
  Wait-Text -Text 'HM3-Audit-Gateway' | Out-Null
  Write-Check 'HM-3 device creation'

  Click-Text -Text '编辑'
  Wait-Text -Text '编辑设备' | Out-Null
  Input-TextAtPlaceholder -Placeholder '位置（选填）' -Value 'HM3-Lab'
  Press-Back
  Click-Text -Text '保存设备'
  Wait-Text -Text 'HM3-Lab' | Out-Null
  Write-Check 'HM-3 device editing'

  Click-Text -Text '删除'
  Wait-Text -Text '已删除' | Out-Null
  Wait-Text -Text '恢复' | Out-Null
  Click-Text -Text '恢复'
  Wait-Text -Text '离线' | Out-Null
  Wait-Text -Text '编辑' | Out-Null
  Write-Check 'HM-3 device delete and restore'

  Back-UntilText -Text '名称、编号或位置' | Out-Null
  Wait-Text -Text 'HM3-Audit-Gateway' | Out-Null
  Click-TopRightButton
  Wait-Text -Text '创建设备' | Out-Null
  Input-TextAtPlaceholder -Placeholder '设备编码' -Value 'HM3-AUDIT-01'
  Input-TextAtPlaceholder -Placeholder '设备名称' -Value 'HM3-Duplicate'
  Press-Back
  Click-Text -Text '保存设备'
  Wait-Text -Text '设备编码已经存在' | Out-Null
  Write-Check 'HM-3 duplicate device code returns 409 state'
  Back-UntilText -Text '名称、编号或位置' | Out-Null
  Wait-Text -Text 'HM3-Audit-Gateway' | Out-Null
}

function Open-Hm3PrimaryDevice {
  Click-TabAndWait -Tab '设备' -ExpectedText '上海办公室主网关' | Out-Null
  Click-Text -Text '上海办公室主网关'
  $detail = Wait-Text -Text '设备详情'
  Assert-VisibleMarkers -Layout $detail -Markers @(
    '设备控制与执行记录',
    '上游 WiFi 配置',
    '连接',
    '信号',
    '流量',
    '编辑',
    '删除'
  ) -Scope 'HM-3 device detail'
  Write-Check 'P202 tenant device detail actions'
}

function Assert-Hm3SessionSignalTraffic {
  Click-Text -Text '连接'
  Wait-Text -Text '34:12:98:AB:70:21' | Out-Null
  Click-Text -Text '34:12:98:AB:70:21'
  Wait-Text -Text '连接详情' | Out-Null
  Click-Text -Text '断开连接'
  Wait-Text -Text '确认' | Out-Null
  Click-Text -Text '确认'
  Wait-Text -Text '断开请求已提交，最终执行状态以后端和设备结果为准' | Out-Null
  Write-Check 'P203 tenant session detail and revoke'
  Press-Back
  Wait-Text -Text '已结束' | Out-Null
  Press-Back
  Wait-Text -Text '设备详情' | Out-Null

  Click-Text -Text '信号'
  Wait-Text -Text '信号记录' | Out-Null
  Wait-Text -Text '34:12:98:AB:70:21' | Out-Null
  Click-Text -Text '34:12:98:AB:70:21'
  $signalDetail = Wait-Text -Text '信号详情'
  Assert-VisibleMarkers -Layout $signalDetail -Markers @('RSSI', '估算距离', '采集时间') `
    -Scope 'HM-3 signal detail'
  Write-Check 'P204/P228 signal list and detail'
  Press-Back
  Wait-Text -Text '信号记录' | Out-Null
  Press-Back
  Wait-Text -Text '设备详情' | Out-Null

  Click-Text -Text '流量'
  $traffic = Wait-Text -Text '流量趋势'
  Assert-VisibleMarkers -Layout $traffic -Markers @('上行', '下行') -Scope 'HM-3 traffic trend'
  Write-Check 'P205 traffic trend'
  Press-Back
  Wait-Text -Text '设备详情' | Out-Null
}

function Assert-Hm3CommandAndWifi {
  Click-Text -Text '设备控制与执行记录'
  Wait-Text -Text '设备控制' | Out-Null
  Click-Text -Text '提交命令'
  Reveal-Text -Text '确认提交' | Out-Null
  Click-Text -Text '确认提交'
  Wait-Text -Text '设备已确认命令执行成功' -TimeoutSeconds 15 | Out-Null
  Wait-Text -Text '当前命令' | Out-Null
  Click-Text -Text '查看详情'
  $commandDetail = Wait-Text -Text '命令详情'
  Assert-VisibleMarkers -Layout $commandDetail -Markers @(
    'requestId',
    '设备',
    '失败/结果',
    'Demo 设备已确认执行'
  ) -Scope 'HM-3 command detail'
  Write-Check 'P206/P229 command submit, terminal polling, and detail'
  Press-Back
  Wait-Text -Text '设备控制' | Out-Null
  Press-Back
  Wait-Text -Text '设备详情' | Out-Null

  Click-Text -Text '上游 WiFi 配置'
  Wait-Text -Text '上游 WiFi 配置' | Out-Null
  Input-TextAtPlaceholder -Placeholder '请输入新的 WiFi 名称' -Value 'HM3-Audit-WiFi'
  Press-Back
  Input-TextAtPlaceholder -Placeholder '开放网络留空，其他网络至少 8 字节' -Value 'HM3pass123'
  Press-Back
  $wifiForm = Get-Layout
  if (-not (Test-Text -Layout $wifiForm -Text 'HM3-Audit-WiFi')) {
    throw 'WiFi SSID changed while entering the password.'
  }
  Click-Text -Text '修改设备 WiFi'
  Reveal-Text -Text '确认修改' | Out-Null
  Click-Text -Text '确认修改'
  Wait-Text -Text '设备已确认新的上游 WiFi 配置生效' -TimeoutSeconds 15 | Out-Null
  Click-Text -Text '查看任务详情'
  $wifiDetail = Wait-Text -Text 'WiFi 任务详情'
  Assert-VisibleMarkers -Layout $wifiDetail -Markers @(
    'requestId',
    'SSID',
    'HM3-Audit-WiFi',
    '密码已配置',
    '生效时间'
  ) -Scope 'HM-3 WiFi task detail'
  if (Test-Text -Layout $wifiDetail -Text 'HM3pass123') {
    throw 'WiFi password leaked into the task detail.'
  }
  Write-Check 'P207/P230 WiFi submit, terminal polling, detail, and password boundary'
  Press-Back
  Wait-Text -Text '上游 WiFi 配置' | Out-Null
  Press-Back
  Wait-Text -Text '设备详情' | Out-Null
}

function Assert-Hm3TenantServices {
  Click-Text -Text '服务' -Area Bottom
  $services = Wait-Text -Text '租户运维'
  Assert-VisibleMarkers -Layout $services -Markers @(
    '设备管理',
    '连接会话',
    '设备命令',
    '上游 WiFi',
    '黑名单'
  ) -Scope 'HM-3 tenant services'
  Click-Text -Text '黑名单'
  Wait-Text -Text '新增黑名单' | Out-Null
  Input-TextAtPlaceholder -Placeholder 'MAC 地址，例如 AA:BB:CC:11:22:33' `
    -Value 'AA:BB:CC:77:88:99'
  Input-TextAtPlaceholder -Placeholder '加入原因' -Value 'HM3-audit'
  Press-Back
  Click-Text -Text '新增黑名单' -NearestY 1350
  Wait-Text -Text '黑名单记录已新增' | Out-Null
  Input-TextAtPlaceholder -Placeholder 'MAC 地址，例如 AA:BB:CC:11:22:33' `
    -Value 'AA:BB:CC:77:88:99'
  Input-TextAtPlaceholder -Placeholder '加入原因' -Value 'HM3-duplicate'
  Press-Back
  Click-Text -Text '新增黑名单' -NearestY 1350
  Wait-Text -Text '该 MAC 已在黑名单中' | Out-Null
  Click-Text -Text '重试'
  Reveal-Text -Text '移除' | Out-Null
  Click-Text -Text '移除'
  Wait-Text -Text '移除黑名单' | Out-Null
  Click-Text -Text '移除' -NearestY 1385
  Wait-Text -Text '黑名单记录已移除' | Out-Null
  Write-Check 'P211 blacklist create, duplicate 409, and removal'
  Press-Back
  Wait-Text -Text '租户运维' | Out-Null
}

function Assert-Hm3Scenarios {
  Set-Hm2Scenario -Label '空数据'
  Click-TabAndWait -Tab '设备' -ExpectedText '当前工作区没有设备' | Out-Null
  Write-Check 'HM-3 EMPTY page state'

  Set-Hm2Scenario -Label '筛选无结果'
  Click-TabAndWait -Tab '设备' -ExpectedText '设备' | Out-Null
  Input-TextAtPlaceholder -Placeholder '名称、编号或位置' -Value 'missing-device'
  Press-Back
  Click-Text -Text '查询'
  Wait-Text -Text '当前工作区没有设备' | Out-Null
  Write-Check 'HM-3 FILTER_EMPTY page state'

  $readErrors = @(
    [pscustomobject]@{ Label = '无权限'; Message = '当前场景无权读取租户运维数据' },
    [pscustomobject]@{ Label = '请求限流'; Message = '请求过于频繁' },
    [pscustomobject]@{ Label = '依赖不可用'; Message = '租户运维依赖暂不可用' }
  )
  foreach ($scenario in $readErrors) {
    Set-Hm2Scenario -Label $scenario.Label
    Click-TabAndWait -Tab '设备' -ExpectedText $scenario.Message | Out-Null
    Click-Text -Text '重试'
    Wait-Text -Text $scenario.Message | Out-Null
    Write-Check "HM-3 $($scenario.Label) error and bounded retry state"
  }

  Set-Hm2Scenario -Label '局部失败'
  Click-TabAndWait -Tab '设备' -ExpectedText '上海办公室主网关' | Out-Null
  Click-Text -Text '上海办公室主网关'
  Wait-Text -Text '设备详情' | Out-Null
  Click-Text -Text '信号'
  Wait-Text -Text '局部运维数据加载失败' | Out-Null
  Write-Check 'HM-3 PARTIAL_FAILURE remains a visible error'
  Press-Back
  Wait-Text -Text '设备详情' | Out-Null
  Press-Back
  Wait-Text -Text '上海办公室主网关' | Out-Null

  Set-Hm2Scenario -Label '状态冲突'
  Click-TabAndWait -Tab '设备' -ExpectedText '上海办公室主网关' | Out-Null
  Click-Text -Text '上海办公室主网关'
  Wait-Text -Text '设备详情' | Out-Null
  Click-Text -Text '删除'
  Wait-Text -Text '当前状态已变化，请刷新后重试' | Out-Null
  Write-Check 'HM-3 write conflict remains a visible 409 state'

  Press-Back
  Wait-Text -Text '上海办公室主网关' | Out-Null
  Reset-Hm2DemoState
  Click-TabAndWait -Tab '设备' -ExpectedText '上海办公室主网关' | Out-Null
  Write-Check 'HM-3 scenario recovery to NORMAL'
}

function Assert-Hm3TenantAdminJourney {
  Assert-BottomTabs -Expected @('首页', '设备', '告警', '服务', '我的')
  Reset-Hm2DemoState
  Assert-Hm3DeviceCrud
  Open-Hm3PrimaryDevice
  Assert-Hm3SessionSignalTraffic
  Assert-Hm3CommandAndWifi
  Back-UntilText -Text '名称、编号或位置' | Out-Null
  Wait-Text -Text '上海办公室主网关' | Out-Null
  Assert-Hm3TenantServices
  Assert-Hm3Scenarios
  Assert-NetworkSentinel
  Write-Check 'HM-3 tenant administrator journey completed'
}

function Enter-Hm3ManagedTenant {
  param([Parameter(Mandatory = $true)][string]$TenantName)

  Click-TabAndWait -Tab '组织' -ExpectedText '选择组织' | Out-Null
  Click-Text -Text $TenantName
  Wait-Text -Text '开始管理' | Out-Null
  Input-TextAtPlaceholder -Placeholder '简要说明为什么需要管理该组织' -Value 'HM3-audit'
  Press-Back
  Click-Text -Text '开始管理'
  Wait-Text -Text '组织详情' | Out-Null
  Click-Text -Text '进入组织工作台'
  Wait-Text -Text '我的' | Out-Null
  Assert-BottomTabs -Expected @('首页', '设备', '告警', '服务', '我的')
}

function Return-Hm3Platform {
  Open-ProfileTab
  Reveal-Text -Text '返回系统管理' | Out-Null
  Click-Text -Text '返回系统管理'
  Wait-Text -Text '选择组织' | Out-Null
  Assert-BottomTabs -Expected @('首页', '组织', '账号', '服务', '我的')
}

function Assert-Hm3SuperAdminJourney {
  Assert-BottomTabs -Expected @('首页', '组织', '账号', '服务', '我的')
  Reset-Hm2DemoState

  Enter-Hm3ManagedTenant -TenantName '边缘网络实验室'
  Click-TabAndWait -Tab '设备' -ExpectedText '上海办公室主网关' | Out-Null
  $tenantOne = Get-Layout
  if (Test-Text -Layout $tenantOne -Text '北京分部主网关') {
    throw 'Tenant 02 device leaked into tenant 01.'
  }
  Click-Text -Text '服务' -Area Bottom
  Wait-Text -Text '黑名单' | Out-Null
  Click-Text -Text '黑名单'
  $readonlyBlacklist = Wait-Text -Text '黑名单'
  if (Test-Text -Layout $readonlyBlacklist -Text '新增黑名单') {
    throw 'Platform delegate unexpectedly received BLACKLIST_WRITE.'
  }
  Write-Check 'PLATFORM_TENANT tenant 01 data and read-only blacklist boundary'
  Press-Back
  Wait-Text -Text '租户运维' | Out-Null
  Return-Hm3Platform

  Enter-Hm3ManagedTenant -TenantName '分部办公网络'
  Click-TabAndWait -Tab '设备' -ExpectedText '北京分部主网关' | Out-Null
  $tenantTwo = Get-Layout
  if (Test-Text -Layout $tenantTwo -Text '上海办公室主网关') {
    throw 'Tenant 01 device leaked into tenant 02.'
  }
  Write-Check 'PLATFORM_TENANT tenant 02 has an isolated device data set'
  Return-Hm3Platform
  Assert-NetworkSentinel
  Write-Check 'HM-3 super administrator managed-tenant journey completed'
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

  if ($Hm3Only -and $AccountRefreshOnly) {
    throw 'Hm3Only and AccountRefreshOnly cannot be used together.'
  }

  if ($Hm3Only) {
    Login-PreviewAccount -Account 'tenantadmin'
    Assert-Hm3TenantAdminJourney
    Logout-CurrentAccount

    Stop-App
    Start-App
    Wait-Text -Text 'superadmin' | Out-Null
    Login-PreviewAccount -Account 'superadmin'
    Assert-Hm3SuperAdminJourney
    Logout-CurrentAccount
  } elseif ($AccountRefreshOnly) {
    Assert-Hm2AccountRefresh
  } else {
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
        Assert-Hm2SuperAdminJourney
      }

      Assert-SessionRestore -Account $journey.Account -ExpectedTabs $journey.Tabs

      if ($journey.Account -eq 'superadmin') {
        Assert-ThemeAndSentinel
      } else {
        Assert-NetworkSentinel
      }

      Logout-CurrentAccount
    }
  }

  $pidText = Invoke-Hdc -Arguments @(
    '-t', $Serial, 'shell', 'pidof', $BundleName
  )
  $appPid = (($pidText -split '\s+')[0]).Trim()
  if ($appPid -notmatch '^\d+$') {
    throw "Invalid application PID: $pidText"
  }
  if ($script:observedAppPids -notcontains $appPid) {
    $script:observedAppPids += $appPid
  }
  $errorLines = @()
  foreach ($observedPid in $script:observedAppPids) {
    $errorLog = Invoke-Hdc -Arguments @(
      '-t', $Serial, 'shell', 'hilog', '-x',
      '-P', $observedPid, '-L', 'ERROR,FATAL'
    ) -AllowEmpty
    $errorLines += @(
      $errorLog -split '\r?\n' |
        Where-Object { $_.Trim().Length -gt 0 }
    )
  }
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

  if ($Hm3Only) {
    Write-Host "HM-3 DEVICE AUDIT PASSED: $script:checks checks"
  } else {
    Write-Host "HM-2 DEVICE AUDIT PASSED: $script:checks checks"
  }
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
