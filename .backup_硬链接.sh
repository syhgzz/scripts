#脚本放置在源目录下，自适应目录名，delete模式，硬链接模式
 
set -o errexit
set -o nounset
set -o pipefail

readonly BACKUPSH_PATH="$(readlink -f $0)"
readonly SOURCE_DIR="$(dirname ${BACKUPSH_PATH})"
readonly SOURCE_NAME="${SOURCE_DIR##*/}"


readonly BACKUP_DIR="/home/share/backup10/${SOURCE_NAME}_backup"
readonly DATETIME="$(date '+%Y_%m_%d_%H_%M_%S')"
readonly BACKUP_PATH="${BACKUP_DIR}/${DATETIME}"
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
