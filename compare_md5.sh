#!/bin/bash
#
# compare_md5.sh - 双向比较两个文件夹中所有文件（含子目录）的 MD5
# 用法: ./compare_md5.sh <A_DIR> <B_DIR>
#
# 输出三类差异到 stdout:
#   [缺少]     A 有而 B 没有的文件
#   [多出]     B 有而 A 没有的文件
#   [不一致]   两边都有但 MD5 不同的文件（显示两边 hash）
#
# 退出码: 0 = 完全一致; 1 = 存在差异; 2 = 参数或运行错误
#

set -euo pipefail

usage() {
    cat <<'EOF'
用法:
  bash compare_md5.sh <A_DIR> <B_DIR>

说明:
  递归比较 A_DIR 与 B_DIR 内所有普通文件的 MD5，输出缺失/多出/不一致。
  - 存在差异: 输出明细与汇总到 stdout, 退出码 1
  - 完全一致: 输出 OK 到 stdout, 退出码 0
  - 参数或运行错误: 输出到 stderr, 退出码 2
EOF
}

err() {
    echo "$*" >&2
}

if [ "$#" -ne 2 ]; then
    usage >&2
    exit 2
fi

A_DIR=$1
B_DIR=$2

if [ ! -d "$A_DIR" ]; then
    err "错误: A_DIR 不是目录: $A_DIR"
    exit 2
fi

if [ ! -d "$B_DIR" ]; then
    err "错误: B_DIR 不是目录: $B_DIR"
    exit 2
fi

if [ ! -r "$A_DIR" ]; then
    err "错误: A_DIR 不可读: $A_DIR"
    exit 2
fi

if [ ! -r "$B_DIR" ]; then
    err "错误: B_DIR 不可读: $B_DIR"
    exit 2
fi

# 优先 md5sum (Linux / coreutils); 否则用 macOS 自带 md5 -r, 输出格式同为 "hash  path"
if command -v md5sum >/dev/null 2>&1; then
    MD5_CMD=md5sum
elif command -v md5 >/dev/null 2>&1; then
    MD5_CMD="md5 -r"
else
    err "错误: 未找到 md5sum 或 md5 命令。"
    exit 2
fi

A_ABS=$(cd "$A_DIR" && pwd)
B_ABS=$(cd "$B_DIR" && pwd)

# 生成清单: 每行 "hash<TAB>相对路径", 相对路径基于各自根目录
gen_manifest() {
    local dir=$1
    while IFS= read -r -d '' file; do
        rel_path=${file#"$dir"/}
        hash=$($MD5_CMD "$file" 2>/dev/null | awk '{print $1}')
        if [ -z "$hash" ]; then
            err "错误: 计算 MD5 失败: $file"
            exit 2
        fi
        printf '%s\t%s\n' "$hash" "$rel_path"
    done < <(find "$dir" -type f -print0 | sort -z)
}

manifest_a=$(mktemp)
manifest_b=$(mktemp)
cleanup() {
    rm -f "$manifest_a" "$manifest_b"
}
trap cleanup EXIT

gen_manifest "$A_ABS" > "$manifest_a"
gen_manifest "$B_ABS" > "$manifest_b"

# 按路径列排序, 供 comm / join 使用
sort -t $'\t' -k2,2 -o "$manifest_a" "$manifest_a"
sort -t $'\t' -k2,2 -o "$manifest_b" "$manifest_b"

missing=0    # A 有 B 没有
extra=0      # B 有 A 没有
mismatch=0   # 两边都有但 hash 不同
total=0      # 两边文件总数

# B 缺少: 只出现在 A 清单中的路径
while IFS= read -r path; do
    echo "[缺少] $path"
    ((missing++)) || true
done < <(comm -23 <(cut -f2 "$manifest_a") <(cut -f2 "$manifest_b"))

# B 多出: 只出现在 B 清单中的路径
while IFS= read -r path; do
    echo "[多出] $path"
    ((extra++)) || true
done < <(comm -13 <(cut -f2 "$manifest_a") <(cut -f2 "$manifest_b"))

# hash 不一致: 按路径 join 两清单, 比较 hash 列 (join 输出: path<TAB>hash_a<TAB>hash_b)
common=0
while IFS=$'\t' read -r path hash_a hash_b; do
    ((common++)) || true
    if [ "$hash_a" != "$hash_b" ]; then
        echo "[不一致] $path (A: $hash_a, B: $hash_b)"
        ((mismatch++)) || true
    fi
done < <(join -t $'\t' -1 2 -2 2 "$manifest_a" "$manifest_b")

# 并集文件数 = 两边共有的 + A 独有 + B 独有
total=$(( common + missing + extra ))

if [ "$missing" -eq 0 ] && [ "$extra" -eq 0 ] && [ "$mismatch" -eq 0 ]; then
    echo "OK: 两个目录完全一致 (共 $total 个文件)。"
    exit 0
fi

echo "========================================"
echo "比较完成: 共 $total 个文件, 缺少 $missing, 多出 $extra, 不一致 $mismatch"
exit 1
