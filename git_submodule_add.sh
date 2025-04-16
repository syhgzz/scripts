#!/bin/bash

# 定义存放路径的变量
DIR="your_directory_path"

# 定义字符串数组
branches=("branch1" "branch2" "branch3")

# 循环遍历数组
for BRANCH in "${branches[@]}"; do
    # 拼接路径
    FULL_PATH="${DIR}/${BRANCH}"

    git submodule add --force -b ${BRANCH} git@github.com:syhgzz/dml.git ${FULL_PATH}
    # 检查命令执行结果
    if [ $? -eq 0 ]; then
        echo "成功添加子模块到路径 $FULL_PATH"
    else
        echo "添加子模块到路径 $FULL_PATH 时出错"
    fi
done
    