#!/bin/bash
# 备份实验数据的脚本

# 指定实验数据文件夹和备份文件夹的名称
src_folder="experiment_2"
backup_root_folder="results_backup_dml"

# 获取当前目录的名字
dir_name=$(basename "$PWD")
# 获取当前目录的绝对路径
dir_path=$(pwd)
# 获取当前时间，格式为YYYYMMDD_HHMMSS
current_time=$(date +"%Y%m%d_%H%M%S")

# 获取git的commit id到变量
commit_id=$(git rev-parse --short HEAD ) 

# 定义源文件夹路径, 假设实验数据在当前目录下的实验名变量src_folder文件夹中
source_path="${dir_path}/${src_folder}"
# 定义备份文件夹路径
backup_folder="${dir_name}"
backup_path="${dir_path}/../${backup_root_folder}/${backup_folder}_${current_time}_${commit_id}"

# 创建备份文件夹
mkdir -p "$backup_path"
# 复制实验数据到备份文件夹
cp -a "$source_path/"* "$backup_path/"
# 设置只读属性
chmod -R a-w "$backup_path"
# 输出
echo "Data from '$source_path' copied to '$backup_path', setting read-only permissions."
# 压缩
tar -czf "$backup_path.tar.gz" "$backup_path"
# 输出备份完成的信息
echo "Backup of '$source_path' completed at '$backup_path.tar.gz'"

