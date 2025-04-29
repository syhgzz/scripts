#!/bin/bash
#脚本放置在源目录下，自适应目录名，delete模式，硬链接模式
# crontab用法 06 17 29 4 * root  /mnt/extra1/lab/backup.sh > /mnt/extra1/lab_backup/log.txt 2>&1 
export LANG=C.utf8
export LC_ALL=C.utf8

readonly BACKUPSH_PATH="$(readlink -f $0)"
readonly SOURCE_DIR="$(dirname ${BACKUPSH_PATH})"
readonly SOURCE_NAME="${SOURCE_DIR##*/}"


readonly BACKUP_DIR="/mnt/extra1/lab_backup"
readonly DATETIME="$(date '+%Y_%m_%d_%H_%M_%S')"
readonly BACKUP_PATH="${BACKUP_DIR}/lab_${DATETIME}"
readonly LATEST_LINK="${BACKUP_DIR}/latest"

echo ${SOURCE_DIR}
echo ${SOURCE_NAME}
echo ${BACKUP_DIR}
echo ${BACKUP_PATH}
echo ${LATEST_LINK}
mkdir -p "${BACKUP_PATH}"
 
rsync -av --delete \
  "${SOURCE_DIR}/" \
  --link-dest "${LATEST_LINK}" \
  --exclude=".cache" \
  "${BACKUP_PATH}" 
 
rm -rf "${LATEST_LINK}"
ln -s "${BACKUP_PATH}" "${LATEST_LINK}"