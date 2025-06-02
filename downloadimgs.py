# 从开发工具网络页导出har文件中,提取特定文件批量下载. Chrome和Edge浏览器的开发工具上测试有效. by zhouzhuo 2025.6.2
import json
import requests
from urllib.parse import urlparse
import os
from pathlib import Path




def get_files_from_har(file_path,output_basedir,prefix_list,ext_list):
    
    # 1. 读取 HAR 文件
    with open(file_path, "r", encoding="utf-8") as f:
        har_data = json.load(f)

    output_harfname, output_harext = os.path.splitext(os.path.basename(file_path))
    output_dir = output_basedir + "/" + output_harfname
    output_dir_Path = Path(output_dir)
    if not output_dir_Path.exists():
        output_dir_Path.mkdir()
    

    # 2. 提取所有图片 URL
    image_urls = []
    for entry in har_data["log"]["entries"]:
        # p = entry["response"]["content"]["mimeType"]
        if "mimeType" in entry["response"]["content"] and entry["response"]["content"]["mimeType"].startswith("image/"):
            url = entry["request"]["url"]
            parsed = urlparse(url)
            output_fname, output_ext = os.path.splitext(os.path.basename(parsed.path))
            if output_ext in ext_list and output_fname.startswith(prefix_list[0]):
                image_urls.append(url)  # 或直接取 URL
                response = requests.get(url)
                output_file = output_dir + "/" + output_fname +output_ext #输出文件名, 重命名image_序号
                with open(output_file, "wb") as f:
                    f.write(response.content)




if __name__ =="__main__":
    # 输入目录和输入文件的扩展名
    input_dir = './'
    input_ext = ".har"

    # 需要保存的扩展名
    ext_list = [".jpeg",".jpg"] 
    prefix_list = ["1"]

    # 输出目录
    output_basedir = "./output"
    output_basedir_Path = Path(output_basedir)
    if not output_basedir_Path.exists():
        output_basedir_Path.mkdir()


    input_dir_path = Path(input_dir)
    if input_dir_path.exists() and input_dir_path.is_dir():
        for item in input_dir_path.iterdir():
            if item.suffix == input_ext:

                file_path = str(item)
                get_files_from_har(file_path,output_basedir,prefix_list,ext_list)
