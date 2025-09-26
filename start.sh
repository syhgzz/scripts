#!/bin/bash
# 启动实验的脚本
# 该脚本会将当前目录拷贝到上级目录下新建实验名目录中，然后进入该目录执行实验py文件
# 使用方法：bash start.sh [实验名] [实验py文件名], 例如：bash start.sh experiment_2 experiment_2.py
# 如果不提供参数，默认实验名为experiment_2，实验py文件名为experiment_2.py

# 从参数中获取一个实验名到变量
experiment_name=$1
if [ -z "$experiment_name" ]; then
    experiment_name="experiment_2"
    echo "No experiment name provided. Using default: $experiment_name"
fi

# 从参数中获取实验py文件名到变量
experiment_py_file=$2
if [ -z "$experiment_py_file" ]; then
    experiment_py_file="experiment_2.py"
    echo "No experiment Python file provided. Using default: $experiment_py_file"
fi


# 将当前目录拷贝到上级目录下新建实验名目录中
current_dir=$(pwd)
current_dir_name=$(basename "$current_dir")
current_dir_parent=$(dirname "$current_dir")
experiment_dir="${current_dir_parent}/${experiment_name}"

echo $current_dir
echo $experiment_dir

#  
mkdir -p "$experiment_dir"
cp -a ${current_dir}/. $experiment_dir/
echo "Copied current directory '$current_dir' to experiment directory '$experiment_dir'."
# 进入实验目录
cd "$experiment_dir" || { echo "Failed to change directory to '$experiment_dir'"; exit 1; }
echo "Changed directory to '$experiment_dir'."
# 输出当前git的commit id
commit_id=$(git rev-parse --short HEAD )
echo "Current git commit id: $commit_id"
# 输出当前时间
current_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "Current time: $current_time"
# 执行实验
echo "Started experiment by running '$experiment_py_file' in background. Output is being logged to 'output.log'."
nohup bash -c "source ~/miniconda3/bin/activate dml && python ${experiment_py_file}; ./next.sh" > output.log 2>&1 &
echo "You can check the progress by tail -f output.log"