# 将当前目录下所有子目录名提取为变量a. 进入每个子目录, 进行如下操作: 
# 1. 将git origin, 改为git@github.com:syhgzz/dml.git; 
# 2.提交当前工作区到新的分支, 并且新的分支的名字是变量a; 
# 3. push 这个新的分支;

# 获取当前目录下的所有子目录名
$a = Get-ChildItem -Directory | Select-Object -ExpandProperty Name
$prefix="System_1_"

foreach ($subDirName in $a) {
    Write-Host "正在处理子目录: $subDirName"

    # 进入子目录
    Set-Location -Path $subDirName
    $BRANCH= $prefix + $subDirName

    try {
        # 1. 将 git origin 改为 git@github.com:syhgzz/dml.git
        git remote set-url origin git@github.com:syhgzz/dml.git
        if ($LASTEXITCODE -ne 0) {
            Write-Error "在 $subDirName 中设置 git origin 失败。"
            continue
        }
       
        # 2. 提交当前工作区到新的分支，新分支名字是变量 a

        git checkout -b $BRANCH
        if ($LASTEXITCODE -ne 0) {
            Write-Error "在 $subDirName 中创建并切换到新分支 $BRANCH失败。"
            continue
        }

        git add -u
        if ($LASTEXITCODE -ne 0) {
            Write-Error "在 $subDirName 中执行 git add 失败。"
            continue
        }
        
        git commit -m "王挺力代码分支备份点 原路径 $BRANCH"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "在 $subDirName 中执行 git commit 失败。"
            continue
        }


        # 3. push 这个新的分支
        do 
        {
            git push -u origin $BRANCH

        }
        while ($LASTEXITCODE -ne 0)


        Write-Host "成功处理子目录: $subDirName"
    }
    catch {
        Write-Error "处理子目录 $subDirName 时出现异常: $_"
    }
    finally {
        # 回到上级目录
        Set-Location -Path ..
    }
}