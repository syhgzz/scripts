# 城院上网脚本Powershell版
# 来源: https://github.com/YYH2913/ZUCC_Internet_Automatic_Authrazation/tree/main  By Ye Yanghan


#此处填城院上网的用户名和密码
$user = "your_account_number_here"
$password = "your_password_here"

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

do {
    $ping = Test-Connection -ComputerName "www.baidu.com" -Count 3 -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Output "Network OK"
        exit
    } else {
        Write-Output "No Network"
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
        Invoke-RestMethod -Uri 'http://1.1.1.3/ac_portal/login.php' -Method POST -Headers $headers -Body $body
        Write-Output "Web authentication authenticated"
    }
    Start-Sleep -Seconds 1
} while ($true)
