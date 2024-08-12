#增量备份，无硬链接，delete模式，放置在源目录下执行
 
set -o errexit
set -o nounset
set -o pipefail

readonly BACKUPSH_PATH="$(readlink -f $0)"
readonly SOURCE_DIR="$(dirname ${BACKUPSH_PATH})"
readonly SOURCE_NAME="${SOURCE_DIR##*/}"


readonly BACKUP_DIR="/home/share/backup10/${SOURCE_NAME}_backup"
readonly DATETIME="$(date '+%Y_%m_%d_%H_%M_%S')"
readonly BACKUP_PATH="${BACKUP_DIR}"
#readonly LATEST_LINK="${BACKUP_DIR}/latest"

echo ${SOURCE_DIR}
echo ${SOURCE_NAME}
echo ${BACKUP_DIR}
echo ${BACKUP_PATH}
#echo ${LATEST_LINK}
mkdir -p "${BACKUP_PATH}"
 
rsync -av --delete \
  "${SOURCE_DIR}/" \
  "${BACKUP_PATH}"
 

