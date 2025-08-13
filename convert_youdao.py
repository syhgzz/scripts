# 将金山词霸导出的单词本转换为有道词典的XML格式 隐式需要 openpyxl 和 pandas 库
import pandas as pd
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom.minidom import parseString
import re

def convert_to_youdao_xml(excel_data):
    # 创建根元素
    wordbook = Element('wordbook')
    
    for i, row in excel_data.iterrows():
        # 处理音标：提取英式和美式音标
        phonetic = row['Phonetic Symbol']
        eng_phonetic = re.search(r'英\s*(/.+?/)', phonetic)
        usa_phonetic = re.search(r'美\s*(/.+?/)', phonetic)
        
        phonetic_str = ""
        if eng_phonetic and usa_phonetic:
            phonetic_str = f"英 {eng_phonetic.group(1)} 美 {usa_phonetic.group(1)}"
        elif eng_phonetic:
            phonetic_str = f"英 {eng_phonetic.group(1)}"
        elif usa_phonetic:
            phonetic_str = f"美 {usa_phonetic.group(1)}"
        
        # 创建单词项
        item = SubElement(wordbook, 'item')
        word = SubElement(item, 'word').text = row['Word']
        trans = SubElement(item, 'trans').text = row['Meaning']
        phonetic_elem = SubElement(item, 'phonetic').text = phonetic_str
        progress = SubElement(item, 'progress').text = '1'
        tags = SubElement(item, 'tags')  # 空标签
    
    # 生成格式化的XML
    xml_str = tostring(wordbook, encoding='utf-8')
    pretty_xml = parseString(xml_str).toprettyxml(indent='  ')
    return re.sub(r'<\?xml.*\?>', '<?xml version="1.0" encoding="UTF-8"?>', pretty_xml)

# 读取Excel数据
df = pd.read_excel("C:\\Users\\zhouzhuo\Desktop\\2.xlsx", sheet_name='Sheet1')

# 转换为有道XML格式
youdao_xml = convert_to_youdao_xml(df)

# 保存到文件
with open('youdao_wordbook.xml', 'w', encoding='utf-8') as f:
    f.write(youdao_xml)

print("转换完成！已保存至 youdao_wordbook.xml")