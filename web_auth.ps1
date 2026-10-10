# 城院校园网上网认证脚本 (Srun 门户, IPv4 / IPv6 双栈)
# 检查两个协议栈各自的认证状态, 只给需要认证的那一侧重新登录.
#
# 用法:
#   只检查状态 (不需要凭据, 无副作用): pwsh -File web_auth.ps1 -ProbeOnly
#   认证一次:                          pwsh -File web_auth.ps1 -User <学号> -Password <密码>
#
# 计划任务的动作 (任务计划程序 -> 操作 -> 编辑):
#   程序或脚本 : pwsh
#   添加参数   : -File "C:\Users\<用户名>\repos\scripts\web_auth.ps1" -User <学号> -Password "<密码>"
#
#   【引号: 一律用双引号, 绝不要用单引号】
#   计划任务是用 CreateProcess 直接把 pwsh 拉起来的, 中间不经过任何 shell。
#   这条路上 Windows 只认双引号, 单引号会被原样当成参数值的一部分传进来:
#       -Password "abc123"  ->  脚本收到 abc123      (正确)
#       -Password 'abc123'  ->  脚本收到 'abc123'    (多出两个单引号, 长度 +2)
#       -Password 'ab cd'   ->  脚本收到 'ab, 且 cd' 掉成多余参数 (彻底崩坏)
#   后果: RC4 加密的是带引号的错字符串, 门户解密失败并回 "用户名或密码错误",
#   重试 3 轮后以退出码 2 结束 —— 症状是"密码明明是对的却怎么也登不上"。
#
#   实测 (2026-09-24, 同一条口令):
#     计划任务   : 双引号 OK / 不加引号 OK / 单引号 失败
#     PowerShell : 双引号 OK / 不加引号 OK / 单引号 OK  (shell 会先解析掉引号)
#     cmd.exe    : 双引号 OK / 不加引号 OK / 单引号 失败 (cmd 同样不认单引号)
#   => 不存在"计划任务不加、手动必须加"这种区别。统一写双引号, 一个写法到处都对;
#      密码里含空格等特殊字符时双引号更是必须的。
#
# 注意:
#   密码会出现在进程命令行里(任务管理器可见), 但本文件本身不含任何凭据.
#   判定必须走 HTTPS —— 这个网络里 HTTP 永远返回反代理提醒页, 判断不了认证状态.
#   IPv4 与 IPv6 是各自独立的会话, 必须分别认证, 只登一侧救不了另一侧.
#   依赖 curl.exe (Win10 1803+ 自带); 首次运行需管理员以创建事件源.
#
# 退出码 0=正常或已恢复 1=缺少凭据 2=重试耗尽  |  事件日志 WEBCONNECT, ID 20001-20009
# 原作者 Ye Yanghan; 修改 zhouzhuo (事件日志 / pwsh7 兼容 / IPv6 双栈 / 凭据改为命令行传入)

[CmdletBinding()]
param(
    # 校园网账号 (学号). 使用 -ProbeOnly 时可省略.
    [string]$User,

    # 校园网密码. 使用 -ProbeOnly 时可省略.
    [string]$Password,

    # 只探测并打印两栈状态, 绝不发送登录请求 (也不发唤醒请求), 不需要凭据.
    [switch]$ProbeOnly,

    # 单次运行内的最大重试轮数
    [int]$MaxAttempts = 3
)

if (-not $ProbeOnly) {
    if ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Password)) {
        Write-Output 'ERROR: 缺少凭据.'
        Write-Output '  认证       : pwsh -File web_auth.ps1 -User <账号> -Password <密码>'
        Write-Output '  只检查状态 : pwsh -File web_auth.ps1 -ProbeOnly'
        Write-Output '  引号请一律用双引号: 单引号在计划任务 / cmd 里会变成密码的一部分 (症状是"用户名或密码错误").'
        Write-Output '  详见本文件开头的使用说明.'
        exit 1
    }
}

# ---------------------------------------------------------------- 事件 ID
# 20000 段在 Application 日志采样中无任何其它来源占用
# (0-19999 被 Security-SPP / WER / MsiInstaller / Winsrv / RestartManager 等大量占用)
$EventBase   = 20000
$EV_START    = $EventBase + 1   # 20001 Start
$EV_ONLINE   = $EventBase + 2   # 20002 两栈均正常
$EV_NEEDAUTH = $EventBase + 3   # 20003 需要认证
$EV_OK       = $EventBase + 4   # 20004 认证/唤醒成功
$EV_FAIL     = $EventBase + 5   # 20005 认证失败
$EV_NOIPV6   = $EventBase + 6   # 20006 IPv6 不可用, 跳过
$EV_GIVEUP   = $EventBase + 7   # 20007 重试耗尽
$EV_PROBERR  = $EventBase + 8   # 20008 探测异常
$EV_V6STATE  = $EventBase + 9   # 20009 IPv6 地址/租期快照 (纯取证, 不参与判定)

# 字面量 IP 天然钉死协议族: 1.1.1.3 -> IPv4, [1::3] -> IPv6
$PortalV4 = '1.1.1.3'
$PortalV6 = '[1::3]'

$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.44'

# 探测用的外部域名. 不依赖 DNS 解析结果做协议族选择 —— 直接交给 curl 的 -4/-6.
$ProbeHosts = @('www.qq.com', 'www.taobao.com')

# ---------------------------------------------------------------- 事件日志
# 写系统日志需要管理员权限. 非提权时降级为 Write-Output, 不中断认证逻辑.
$Script:EventLogReady = $false
if (-not $ProbeOnly) {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("WEBCONNECT")) {
            [System.Diagnostics.EventLog]::CreateEventSource("WEBCONNECT", "Application")
        }
        $Script:EventLogReady = $true
    } catch {
        $Script:EventLogReady = $false
    }
}

# curl.exe 是 Windows 10 1803+ 自带组件; 探测依赖它拿到"证书不可信"的精确退出码
$Script:CurlExe = $null
try {
    $c = Get-Command curl.exe -ErrorAction Stop
    $Script:CurlExe = $c.Source
} catch { $Script:CurlExe = $null }

function Write-AuthEvent {
    param(
        [int]$Id,
        [string]$Message,
        [string]$Level = 'Information'
    )
    Write-Output ("[{0}] {1}" -f $Id, $Message)
    if (-not $Script:EventLogReady) { return }
    try {
        $ea = @{
            LogName     = "Application"
            Source      = "WEBCONNECT"
            EventId     = $Id
            EntryType   = $Level
            Message     = $Message
            ErrorAction = 'Stop'
        }
        Write-EventLog @ea
    } catch {
        # 事件日志写失败绝不能影响认证本身
    }
}

# curl.exe 缺失时 Test-StackGated 会永远返回"未知", 脚本会退化成每次运行都登录一次.
# 必须显式告警, 否则这种降级在日志里看不出来.
if (-not $Script:CurlExe) {
    Write-AuthEvent $EV_PROBERR "curl.exe 未找到: 无法进行 HTTPS 分栈探测, 已退化为每次运行都执行一次登录 (幂等, 无害), 但无法判断是否已在线" 'Warning'
}

# ---------------------------------------------------------------- RC4
function RC4 {
    param (
        [string]$data,
        [string]$key
    )

    $s = 0..255
    $j = 0
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
    $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($data)

    for ($i = 0; $i -lt 256; $i++) {
        $j = ($j + $s[$i] + $keyBytes[$i % $keyBytes.Length]) % 256
        $s[$i], $s[$j] = $s[$j], $s[$i]
    }

    $i = $j = 0
    $encryptedBytes = @()

    foreach ($byte in $dataBytes) {
        $i = ($i + 1) % 256
        $j = ($j + $s[$i]) % 256
        $s[$i], $s[$j] = $s[$j], $s[$i]
        $k = $s[($s[$i] + $s[$j]) % 256]
        $encryptedBytes += ($byte -bxor $k)
    }

    return ($encryptedBytes | ForEach-Object { $_.ToString("X2") }) -join ''
}

# ---------------------------------------------------------------- 门户登录
function Invoke-PortalLogin {
    param(
        [string]$PortalHost,   # '1.1.1.3' 或 '[1::3]'
        [string]$Stack         # 'IPv4' 或 'IPv6'
    )

    # 每次调用重新生成时间戳密钥, 两个栈不共用
    $rckey = Get-Date -Format "yyyyMMddHHmmss"
    $encrypted_password = RC4 $Password $rckey

    $headers = @{
        'Accept' = '*/*'
        'X-Requested-With' = 'XMLHttpRequest'
        'User-Agent' = $UserAgent
        'Content-Type' = 'application/x-www-form-urlencoded; charset=UTF-8'
        'Origin' = "http://$PortalHost"
        'Referer' = "http://$PortalHost/ac_portal/20230318032256/pc.html?template=20230318032256&tabs=pwd-sms&vlanid=0&_ID_=0&switch_url=&url=http://$PortalHost/homepage/index.html&controller_type=&mac=99-99-99-99-99-99"
        'Accept-Language' = 'zh-CN,zh;q=0.9'
    }
    $body = @{
        'opr' = 'pwdLogin'
        'userName' = $User
        'pwd' = $encrypted_password
        'auth_tag' = $rckey
        'rememberPwd' = '0'
    }

    $reqArgs = @{
        Uri         = "http://$PortalHost/ac_portal/login.php"
        Method      = 'POST'
        Headers     = $headers
        Body        = $body
        TimeoutSec  = 20
        ErrorAction = 'Stop'
    }

    try {
        $r = Invoke-RestMethod @reqArgs
    } catch {
        return [pscustomobject]@{ Ok = $false; Msg = "$Stack 请求异常: $($_.Exception.Message)" }
    }

    # 门户有两种"成功"语义, 都必须认:
    #   IPv4 已在线重登 -> {"success": true,  "msg": "logon success"}
    #   IPv6 已在线登录 -> {"success": false, "msg": "用户已在线, 不需要再次认证"}
    $ok = $false
    if ($null -ne $r.success -and ([string]$r.success).Trim().ToLower() -eq 'true') { $ok = $true }
    if ("$($r.msg)" -match '已在线|不需要再次认证') { $ok = $true }

    return [pscustomobject]@{ Ok = $ok; Msg = "$Stack : $($r.msg)" }
}

# ---------------------------------------------------------------- 分栈判定
function Test-StackGated {
    param([int]$Family)   # 4 或 6
    # 返回 $true=被网关拦 / $false=正常 / $null=结果未知
    #
    # 【判据必须走 HTTPS】
    # 在这个网络里 HTTP 请求永远被顶到反代理提醒页
    # (http://1.1.1.3/proxytool/remind.htm), 与认证状态无关, 因此 HTTP 无法用来判定.
    # 而一旦被网关拦, HTTPS 会被换成不可信证书做中间人, curl 退出码为 60
    # (CURLE_PEER_FAILED_VERIFICATION) —— 这正是我们要的信号.
    if (-not $Script:CurlExe) { return $null }

    $flag = if ($Family -eq 4) { '-4' } else { '-6' }
    foreach ($h in $ProbeHosts) {
        $ca = $flag, '-sS', '-o', 'NUL', '--max-time', '12', '-A', $UserAgent, '-w', '%{http_code}', "https://$h/"
        $null = & $Script:CurlExe @ca 2>$null
        $code = $LASTEXITCODE
        if ($code -eq 60) { return $true }    # 证书被替换 -> 被网关拦
        if ($code -eq 0)  { return $false }   # 正常
        # 其余(6 解析失败 / 28 超时 / 35 SSL错误等): 换下一个站点再试
    }
    return $null
}

function Format-Gate {
    param($v)
    if ($null -eq $v) { return 'n/a' }
    if ($v) { return 'gated' }
    return 'clean'
}

# 网卡上是否存在可用的全局/ULA IPv6 地址 (排除 link-local 与 loopback)
function Test-HasIpv6 {
    try {
        $a = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction Stop |
            Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notmatch '^fe80' -and $_.IPAddress -ne '::1' }
        return (($a | Measure-Object).Count -gt 0)
    } catch {
        return $false
    }
}

# 取证用: 快照当前非 link-local 的 IPv6 地址及其租期状态.
#
# 为什么需要它: 校园网卡的 IPv6 是 DHCPv6 有状态分配 (PrefixOrigin/SuffixOrigin 均为 Dhcp),
# 寿命有限 —— 实测剩余 ValidLife 约 11 小时 / PrefLife 约 6.5 小时. 而"IPv4 登录是否顺带
# 放行 IPv6"这件事很可能随租期阶段而变 (地址刚续期/刚更换时网关未必已建立映射).
# 把每次判定时刻的租期状态落到日志里, 才能把 g4/g6 的走向与租期关联起来,
# 而不是只凭某一次观测就下结论.
#
# 任何异常都必须吞掉: 取证绝不能影响认证主流程.
function Get-Ipv6LeaseState {

    # 无限寿命渲染成 inf, 否则给出紧凑的 d/h 形式, 避免 10675199.02:48:05 这种噪音
    function Format-Life([object]$t) {
        if ($null -eq $t) { return 'n/a' }
        if ($t.TotalDays -ge 3650) { return 'inf' }
        if ($t.TotalDays -ge 1) { return ('{0}d{1:00}:{2:00}' -f [int]$t.TotalDays, $t.Hours, $t.Minutes) }
        return ('{0}h{1:00}m' -f [int]$t.TotalHours, $t.Minutes)
    }

    try {
        $a = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notmatch '^fe80' -and $_.IPAddress -ne '::1' }
        if (-not $a) { return 'none' }

        $parts = foreach ($x in $a) {
            '{0}@{1}|{2}/{3}|{4}|pref={5}|valid={6}' -f `
                $x.IPAddress, $x.InterfaceAlias, $x.PrefixOrigin, $x.SuffixOrigin, $x.AddressState,
                (Format-Life $x.PreferredLifetime), (Format-Life $x.ValidLifetime)
        }
        return ($parts -join '; ')
    } catch {
        return 'n/a'
    }
}

# ---------------------------------------------------------------- 主流程
Write-AuthEvent $EV_START ("Start. ProbeOnly={0} MaxAttempts={1} user={2} curl={3}" -f `
        [bool]$ProbeOnly, $MaxAttempts, $(if ($ProbeOnly) { '(probe only)' } else { $User }), $(if ($Script:CurlExe) { $Script:CurlExe } else { 'NOT FOUND' }))

$attempt = 0
while ($attempt -lt $MaxAttempts) {
    $attempt++

    # --- 链路层: ping 仅作取证, 不参与判定 ---
    # 它测的"能不能 ping 通"与"要不要登录"没有因果关系: g4 为 clean 已说明网络是好的,
    # g4 为 gated 就必须登录, g4 未知时按安全默认也要登录 —— 三种情况 ping 都改变不了结论.
    # 超时压到 1 秒: 断网时默认要等 5 秒左右, 实测最大 5.97s, 曾占单次运行的 44%.
    $icmpOk = $false
    try {
        $ping = Test-Connection -ComputerName "taobao.com" -Count 1 -TimeoutSeconds 1 -ErrorAction SilentlyContinue
        if ($null -ne $ping -and "$($ping.Status)" -eq 'Success') { $icmpOk = $true }
    } catch { $icmpOk = $false }

    # --- 分栈判据: HTTPS + 证书校验 ---
    $hasV6 = Test-HasIpv6
    # 在判定发生的这一刻快照租期状态, 才能与本次 attempt 的 g4/g6 关联
    Write-AuthEvent $EV_V6STATE ("IPv6State. attempt={0} hasV6={1} {2}" -f $attempt, $hasV6, (Get-Ipv6LeaseState))
    $g4 = $null
    $g6 = $null
    try { $g4 = Test-StackGated 4 } catch { Write-AuthEvent $EV_PROBERR "IPv4 探测异常: $($_.Exception.Message)" }
    if ($hasV6) {
        try { $g6 = Test-StackGated 6 } catch { Write-AuthEvent $EV_PROBERR "IPv6 探测异常: $($_.Exception.Message)" }
    }

    if ($g4 -eq $false -and ($g6 -eq $false -or -not $hasV6)) {
        Write-AuthEvent $EV_ONLINE ("Online. attempt={0} icmp=OK g4=clean g6={1}" -f $attempt, (Format-Gate $g6))
        exit 0
    }

    $icmpText = if ($icmpOk) { 'OK' } else { 'FAIL' }
    Write-AuthEvent $EV_NEEDAUTH ("NeedAuth. attempt={0} icmp={1} g4={2} g6={3} hasV6={4}" -f `
            $attempt, $icmpText, (Format-Gate $g4), (Format-Gate $g6), $hasV6)

    if ($ProbeOnly) { exit 0 }

    # --- IPv4 分支 ---
    if ($g4 -ne $false) {
        $res4 = Invoke-PortalLogin -PortalHost $PortalV4 -Stack 'IPv4'
        if ($res4.Ok) { Write-AuthEvent $EV_OK $res4.Msg }
        else { Write-AuthEvent $EV_FAIL $res4.Msg 'Warning' }
    }

    # --- IPv6 分支: 独立会话, 直接按判定结果登录 ---
    # 两栈会话独立(实测: 从一侧登出完全不影响另一侧), 所以 IPv4 登录不会顺带放行 IPv6,
    # 不需要"登录后复测 / 唤醒 / 再复测"这条链 —— 全量日志里它从未改变过结果.
    if (-not $hasV6) {
        Write-AuthEvent $EV_NOIPV6 "网卡上没有可用的 IPv6 地址, 跳过"
    } elseif ($g6 -ne $false) {
        $res6 = Invoke-PortalLogin -PortalHost $PortalV6 -Stack 'IPv6'
        if ($res6.Ok) { Write-AuthEvent $EV_OK $res6.Msg }
        else { Write-AuthEvent $EV_FAIL $res6.Msg 'Warning' }
    }

    Start-Sleep -Seconds 2
}

Write-AuthEvent $EV_GIVEUP ("GiveUp. 已重试 {0} 轮仍未恢复" -f $MaxAttempts) 'Warning'
exit 2
