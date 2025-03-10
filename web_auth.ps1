# 城院上网脚本Powershell版
# 来源: https://github.com/YYH2913/ZUCC_Internet_Automatic_Authrazation/tree/main  By Ye Yanghan
# 修改 by zhouzhuo, 增加事件日志; 修复pwsh7的问题.


#此处填城院上网的用户名和密码
$user = "2240201012"
$password = "292519"

# 系统日志需要最高权限管理员权限. Windows日志->应用程序 
if (-not [System.Diagnostics.EventLog]::SourceExists("WEBCONNECT")) 
    { [System.Diagnostics.EventLog]::CreateEventSource("WEBCONNECT", "Application") 
}; 
Write-EventLog -LogName "Application" -Source "WEBCONNECT" -EventId 1001 -EntryType Information -Message "Start"

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

$rckey = Get-Date -Format "yyyyMMddHHmmss"

$encrypted_password = RC4 $password $rckey
# pwsh 7 ping在失败时返回对象. Windows Powershell在失败时返回$null
do {
    $ping = Test-Connection -ComputerName "taobao.com" -Count 1 
    if ($ping.Status -eq "Success") {
        Write-Output "Online"
        Write-EventLog -LogName "Application" -Source "WEBCONNECT" -EventId 1002 -EntryType Information -Message "Online."

        exit
    } else {
        Write-Output "Offline"
        Write-EventLog -LogName "Application" -Source "WEBCONNECT" -EventId 1003 -EntryType Information -Message "Offline."

        $headers = @{
            'Accept' = '*/*'
            'X-Requested-With' = 'XMLHttpRequest'
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.44'
            'Content-Type' = 'application/x-www-form-urlencoded; charset=UTF-8'
            'Origin' = 'http://1.1.1.3'
            'Referer' = 'http://1.1.1.3/ac_portal/20230318032256/pc.html?template=20230318032256&tabs=pwd-sms&vlanid=0&_ID_=0&switch_url=&url=http://1.1.1.3/homepage/index.html&controller_type=&mac=99-99-99-99-99-99'
            'Accept-Language' = 'zh-CN,zh;q=0.9'
            'Accept-Encoding' = 'gzip, deflate'
        }
        $body = @{
            'opr' = 'pwdLogin'
            'userName' = $user
            'pwd' = $encrypted_password
            'auth_tag' = $rckey
            'rememberPwd' = '0'
        }
        $r = Invoke-RestMethod -Uri 'http://1.1.1.3/ac_portal/login.php' -Method POST -Headers $headers -Body $body
        if ($r.success -eq "True") {
            Write-Output "Web authentication success."
            Write-EventLog -LogName "Application" -Source "WEBCONNECT" -EventId 1004 -EntryType Information -Message "Success."
        } else {
            Write-Output "Web authentication failed."
            Write-EventLog -LogName "Application" -Source "WEBCONNECT" -EventId 1005 -EntryType Information -Message "Failed."
        }

    }
    Start-Sleep -Seconds 1
} while ($true)
