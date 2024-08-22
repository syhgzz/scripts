# ȥ���ظ��ļ� by zhouzhuo 2024.8.22

#-------------------------���Ʋ���-------------------------
#����Ŀ¼, �����޸�. ע���βҪ�ж���,
$dirs = @(
"C:\Users\zhouzhuo\Lab\Repo\�½��ļ���",
"C:\Users\zhouzhuo\Lab\Repo\�½��ļ���2",
"C:\Users\zhouzhuo\Lab\Repo\�½��ļ���3",
"")
#�Ƿ����ļ�����ִ��ȥ�ز���
$recurse = 1 
#�ظ���Ŀ�ŵ���Ŀ¼, �ɸ���
$duplicateName = "�ظ���Ŀ"
#-------------------------���Ʋ���-------------------------

function Remove-DuplicatedFile 
{
    
    param (
        $workDir
    )
    if($workDir -eq "") {return}
    # $workDir = "C:\Users\zhouzhuo\Lab\Repo\�½��ļ���"
    #�ظ���Ŀ�ŵ���Ŀ¼
    $duplicateDir = "$workDir\$duplicateName"
    [bool]$hasduplicatedir = Test-Path -Path $duplicateDir #�����Ƿ��Ѿ�����

    #��ȡ����Ŀ¼�Ķ���
    $dirarray = @()
    $dirarray += (Get-Item -Path $workDir)

    #�ݹ��ȡ���ļ��ж���, ���ų�"�ظ���Ŀ"Ŀ¼
    if($recurse -eq $true)
    {
        $subdirarray = Get-ChildItem -Path $workDir -Recurse | Where-Object {$_.Attributes -eq "Directory"} | Where-Object{$_.FullName -ne $duplicateDir}
        $dirarray += $subdirarray
    }

    #��ȡ�����ļ���Ŀ, �ų��ļ�����Ŀ
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
            echo "�ظ��� $value �Ƶ� $duplicateDir"
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
    echo "������Ŀ¼: $dir"
    Remove-DuplicatedFile -workDir $dir
}
