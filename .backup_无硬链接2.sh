# 脚本只能放在当前目录下

readonly BACKUPSH_PATH="$(readlink -f $0)"
readonly SOURCE_DIR="$(dirname ${BACKUPSH_PATH})"
readonly SOURCE_NAME="${SOURCE_DIR##*/}"

readonly BACKUP_DIR="/Volumes/ZZ_SSD/存档/backup/${SOURCE_NAME}_backup"
readonly DATETIME="$(date '+%Y_%m_%d_%H_%M_%S')"



echo ${SOURCE_DIR}
echo ${BACKUP_DIR}


 
rsync -avuP  "${SOURCE_DIR}/" "${BACKUP_DIR}" &> "${BACKUP_DIR}/../${SOURCE_NAME}${DATETIME}.txt"



