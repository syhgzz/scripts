#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
用法:
  bash check_dir_md5.sh <A_DIR> <B_DIR>

说明:
  校验 A_DIR 下所有普通文件是否都能在 B_DIR 的相对路径找到且 MD5 一致。
  - 发现缺失/MD5 不一致: 输出到 stderr, 退出码 1
  - 全部一致: 输出到 stdout, 退出码 0
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

if ! command -v md5sum >/dev/null 2>&1; then
    err "错误: 未找到 md5sum 命令。请先安装 coreutils。"
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

A_ABS=$(cd "$A_DIR" && pwd)
B_ABS=$(cd "$B_DIR" && pwd)

manifest=$(mktemp)
cleanup() {
    rm -f "$manifest"
}
trap cleanup EXIT

while IFS= read -r -d '' file; do
    rel_path=${file#"$A_ABS"/}
    hash=$(md5sum -- "$file" | awk '{print $1}')
    printf '%s  %s\n' "$hash" "$rel_path" >>"$manifest"
done < <(find "$A_ABS" -type f -print0 | sort -z)

if [ ! -s "$manifest" ]; then
    echo "OK: A_DIR 中没有普通文件需要校验。"
    exit 0
fi

if (cd "$B_ABS" && md5sum --check --quiet "$manifest" 1>&2); then
    echo "OK: 校验通过。A_DIR 所有文件均存在于 B_DIR 且 MD5 一致。"
    exit 0
fi

err "ERROR: 检测到缺失文件或 MD5 不一致。"
exit 1
