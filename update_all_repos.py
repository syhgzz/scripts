#!/usr/bin/python3
# 将文件中每个子目录更新git所有分支
# Windows执行方法 python .\update_all_repos.py
import os
import sys


def update_repos(wd):
    repos = os.listdir()
    for repo in repos:
        repopath = wd + "/" + repo
        if os.path.isdir(repopath):
            # os.chdir(repopath)
            print("UPDATE Repo:",repopath)
            p  = f"git  --git-dir={repopath}/.git  fetch"
            os.system(p)
            os.system(f"git  --git-dir={repopath}/.git  pull --all")
        else:
            pass

if __name__ == "__main__":
    basedir, filename = os.path.split(os.path.abspath(sys.argv[0])) 
    wd = basedir
    update_repos(wd)


