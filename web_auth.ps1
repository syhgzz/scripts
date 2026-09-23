# 城院上网脚本Powershell版
# 来源: https://github.com/YYH2913/ZUCC_Internet_Automatic_Authrazation/tree/main  By Ye Yanghan
# 修改 by zhouzhuo, 增加事件日志; 修复pwsh7的问题.
# 2026-09-23 增加 IPv6 双栈认证; 事件 ID 从 1001-1005 迁移到 20001-20008
#            (1001 在 Application 日志中被 Windows Error Reporting 等来源共用, 仅按 ID 过滤会混)

[CmdletBinding()]
param(
    # 只探测并打印两栈状态, 绝不发送登录请求 (也不发唤醒请求)
    [switch]$ProbeOnly,
    # 单次运行内的最大重试轮数
    [int]$MaxAttempts = 3
)

#此处填城院上网的用户名和密码
$user = "2240201012"
$password = "hzcu@5a413"

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

# curl.exe 缺失时 Test-StackGated 会永远返回"未知", 脚本静默退化成仅 ping 判据.
# 必须显式告警, 否则这种降级在日志里看不出来.
if (-not $Script:CurlExe) {
    Write-AuthEvent $EV_PROBERR "curl.exe 未找到: 无法进行 HTTPS 分栈探测, 已退化为仅 ping 判据" 'Warning'
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
    $encrypted_password = RC4 $password $rckey

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
        'userName' = $user
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

# ---------------------------------------------------------------- IPv6 唤醒
function Send-Ipv6Wakeup {
    # 纯 GET, 不带任何凭据. 目的只是让网关看到本机 IPv6 流量.
    # 之前观察到"发一次 IPv6 门户请求后 IPv6 即恢复", 但当时有手工干预, 归因未定;
    # 先唤醒再按需认证可同时覆盖"只需产生流量"和"确需认证"两种假设.
    $a = @{
        Uri                = "http://$PortalV6/"
        MaximumRedirection = 0
        TimeoutSec         = 8
        UseBasicParsing    = $true
        ErrorAction        = 'Stop'
    }
    try {
        $null = Invoke-WebRequest @a
    } catch {
        # 302 会抛异常, 属预期, 忽略
    }
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

# ---------------------------------------------------------------- 主流程
Write-AuthEvent $EV_START ("Start. ProbeOnly={0} MaxAttempts={1} curl={2}" -f `
        [bool]$ProbeOnly, $MaxAttempts, $(if ($Script:CurlExe) { $Script:CurlExe } else { 'NOT FOUND' }))

$attempt = 0
while ($attempt -lt $MaxAttempts) {
    $attempt++

    # --- 链路层: 保留原有的 ping 判据 (实测走 IPv4, 对 IPv6 完全失明) ---
    $icmpOk = $false
    try {
        $ping = Test-Connection -ComputerName "taobao.com" -Count 1 -ErrorAction SilentlyContinue
        if ($null -ne $ping -and "$($ping.Status)" -eq 'Success') { $icmpOk = $true }
    } catch { $icmpOk = $false }

    # --- 分栈判据: HTTPS + 证书校验 ---
    $hasV6 = Test-HasIpv6
    $g4 = $null
    $g6 = $null
    try { $g4 = Test-StackGated 4 } catch { Write-AuthEvent $EV_PROBERR "IPv4 探测异常: $($_.Exception.Message)" }
    if ($hasV6) {
        try { $g6 = Test-StackGated 6 } catch { Write-AuthEvent $EV_PROBERR "IPv6 探测异常: $($_.Exception.Message)" }
    }

    if ($icmpOk -and $g4 -eq $false -and ($g6 -eq $false -or -not $hasV6)) {
        Write-AuthEvent $EV_ONLINE ("Online. attempt={0} icmp=OK g4=clean g6={1}" -f $attempt, (Format-Gate $g6))
        exit 0
    }

    $icmpText = if ($icmpOk) { 'OK' } else { 'FAIL' }
    Write-AuthEvent $EV_NEEDAUTH ("NeedAuth. attempt={0} icmp={1} g4={2} g6={3} hasV6={4}" -f `
            $attempt, $icmpText, (Format-Gate $g4), (Format-Gate $g6), $hasV6)

    if ($ProbeOnly) { exit 0 }

    # --- IPv4 分支 ---
    if ((-not $icmpOk) -or ($g4 -ne $false)) {
        $res4 = Invoke-PortalLogin -PortalHost $PortalV4 -Stack 'IPv4'
        if ($res4.Ok) { Write-AuthEvent $EV_OK $res4.Msg }
        else { Write-AuthEvent $EV_FAIL $res4.Msg 'Warning' }
    }

    # --- IPv6 分支: 先唤醒, 再按需认证 ---
    if (-not $hasV6) {
        Write-AuthEvent $EV_NOIPV6 "网卡上没有可用的 IPv6 地址, 跳过"
    } elseif ($g6 -eq $true) {
        Send-Ipv6Wakeup
        Start-Sleep -Seconds 2
        $g6b = $null
        try { $g6b = Test-StackGated 6 } catch { }
        if ($g6b -eq $false) {
            Write-AuthEvent $EV_OK "IPv6 : 唤醒后已恢复 (未发登录请求)"
        } else {
            $res6 = Invoke-PortalLogin -PortalHost $PortalV6 -Stack 'IPv6'
            if ($res6.Ok) { Write-AuthEvent $EV_OK $res6.Msg }
            else { Write-AuthEvent $EV_FAIL $res6.Msg 'Warning' }
        }
    }

    Start-Sleep -Seconds 2
}

Write-AuthEvent $EV_GIVEUP ("GiveUp. 已重试 {0} 轮仍未恢复" -f $MaxAttempts) 'Warning'
exit 2
