#!/bin/bash
payload=$(cat)
title=$(echo "$payload" | jq -r '.session_title // "Kimi Code 会话"')
cwd=$(echo "$payload" | jq -r '.cwd // ""')

curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"[notify] Kimi Code 任务结束\n会话：${title}\n目录：${cwd}\n时间：$(date '+%F %T')\"}}" \
https://open.feishu.cn/open-apis/bot/v2/hook/74efe7c2-82d8-481f-a092-9aa1d85849a0
