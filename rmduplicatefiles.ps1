# 去掉重复文件 by zhouzhuo


$map = New-Object 'System.Collections.Generic.Dictionary[string,string]'

$map.Add("WG", "file1.jpg")
$map.Add("WG2", "file2.jpg")


$workdir = "C:\Users\zhouzhuo\Lab\Repo\新建文件夹\"

Get-Item -Path $workdir
