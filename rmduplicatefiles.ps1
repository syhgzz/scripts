# 去掉重复文件 by zhouzhuo 2024.8.22

#-------------------------控制参数-------------------------
#工作目录, 可以修改. 注意结尾要有逗号,
$dirs = @(
"C:\Users\zhouzhuo\Lab\Repo\新建文件夹",
"C:\Users\zhouzhuo\Lab\Repo\新建文件夹2",
"C:\Users\zhouzhuo\Lab\Repo\新建文件夹3",
"")
#是否到子文件夹中执行去重操作
$recurse = 1 
#重复项目放到此目录, 可改名
$duplicateName = "重复项目"
#-------------------------控制参数-------------------------

function Remove-DuplicatedFile 
{
    
    param (
        $workDir
    )
    if($workDir -eq "") {return}
    # $workDir = "C:\Users\zhouzhuo\Lab\Repo\新建文件夹"
    #重复项目放到此目录
    $duplicateDir = "$workDir\$duplicateName"
    [bool]$hasduplicatedir = Test-Path -Path $duplicateDir #测试是否已经存在

    #获取工作目录的对象
    $dirarray = @()
    $dirarray += (Get-Item -Path $workDir)

    #递归获取子文件夹对象, 并排除"重复项目"目录
    if($recurse -eq $true)
    {
        $subdirarray = Get-ChildItem -Path $workDir -Recurse | Where-Object {$_.Attributes -eq "Directory"} | Where-Object{$_.FullName -ne $duplicateDir}
        $dirarray += $subdirarray
    }

    #获取所有文件项目, 排除文件夹项目
    $filearray = Get-ChildItem  $dirarray.FullName | Where-Object {$_.Attributes -ne "Directory"}

    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]'

    foreach($item in $filearray)
    {
        $file= $item.FullName
        $md5 = Get-FileHash -Path $file -Algorithm MD5
        $key = $md5.Hash
        $value = $md5.Path
        if($map.ContainsKey($key) -eq $true)
        {
            if($hasduplicatedir -eq $false)
            {
                New-Item -ItemType "directory" -Path $duplicateDir | Out-Null
                $hasduplicatedir = $true
            }
            Move-Item  -Path $value -Destination $duplicateDir -Force
            echo "重复项 $value 移到 $duplicateDir"
        }
        else 
        {
            $map.Add($key, $value)
        }
    }



}

foreach($dir in $dirs)
{
    if($dir -eq "") {break}
    echo "正处理目录: $dir"
    Remove-DuplicatedFile -workDir $dir
}
