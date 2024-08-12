#!/bin/bash
# Compress all the directories. By Zhou Zhuo
dir=/home/share/guest/guest/产品部共享文件夹/做视频素材衣服+布料2021年初王老师论文任务/
dirnames=$(ls -d ${dir}*/)
for i in ${dirnames}
do 
	fullname=${i%/}
	echo $fullname
	dirn=$(dirname $fullname)
	filename=$(basename $fullname)
	echo $dirn
	echo $filename
	tar -Jcv -f ${filename}.tar.xz ${filename}/ #使用相对路径压缩,必须在当前目录下执行
done
