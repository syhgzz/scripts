#!/bin/bash
#
# compare_dirs.sh - 比较两个文件夹中的文件
# 用法：./compare_dirs.sh <文件夹 A> <文件夹 B>
#
# 功能：
#   - 递归检查文件夹 A 中的所有文件在文件夹 B 中是否存在且 MD5 一致
#   - 缺失或 MD5 不匹配的文件输出到 stderr
#   - 校验通过的文件输出到 stdout
#

set -e

# 颜色输出（如果终端支持）
if [[ -t 2 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    NC=''
fi

# 参数检查
if [[ $# -ne 2 ]]; then
    echo "用法：$0 <文件夹 A> <文件夹 B>" >&2
    exit 1
fi

DIR_A="$1"
DIR_B="$2"

# 目录存在性检查
if [[ ! -d "$DIR_A" ]]; then
    echo "错误：文件夹 A 不存在：$DIR_A" >&2
    exit 1
fi

if [[ ! -d "$DIR_B" ]]; then
    echo "错误：文件夹 B 不存在：$DIR_B" >&2
    exit 1
fi

# 转换为绝对路径
DIR_A=$(cd "$DIR_A" && pwd)
DIR_B=$(cd "$DIR_B" && pwd)

# 创建临时文件存储 MD5 校验和
CHECKSUM_FILE=$(mktemp)
trap "rm -f '$CHECKSUM_FILE'" EXIT

# 在 DIR_A 中生成所有文件的 MD5 校验和（使用相对路径）
(cd "$DIR_A" && find . -type f -print0 | xargs -0 md5sum) > "$CHECKSUM_FILE"

# 统计
total=0
ok=0
failed=0

# 在 DIR_B 中校验每个文件
while IFS= read -r line; do
    # 解析 md5sum 输出格式："md5hash  ./path/to/file"
    md5_hash=$(echo "$line" | awk '{print $1}')
    rel_path=$(echo "$line" | awk '{print $2}')
    
    # 去掉开头的 ./
    rel_path="${rel_path#./}"
    
    ((total++)) || true
    
    target_file="$DIR_B/$rel_path"
    
    if [[ ! -f "$target_file" ]]; then
        # 文件不存在
        echo -e "${RED}✗${NC} $rel_path: 文件不存在" >&2
        ((failed++)) || true
    else
        # 文件存在，计算 MD5 并比较
        target_md5=$(md5sum "$target_file" | awk '{print $1}')
        if [[ "$md5_hash" == "$target_md5" ]]; then
            echo -e "${GREEN}✓${NC} $rel_path: OK"
            ((ok++)) || true
        else
            echo -e "${RED}✗${NC} $rel_path: MD5 不一致 (A: $md5_hash, B: $target_md5)" >&2
            ((failed++)) || true
        fi
    fi
done < "$CHECKSUM_FILE"

# 汇总报告
echo ""
echo "========== 校验完成 =========="
echo "总计文件数：$total"
echo -e "校验通过：${GREEN}$ok${NC}"
if [[ $failed -gt 0 ]]; then
    echo -e "失败/缺失：${RED}$failed${NC}"
    exit 1
else
    echo "失败/缺失：0"
    exit 0
fi
