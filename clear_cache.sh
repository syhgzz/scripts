#!/bin/bash
# clear_cache.sh — 整理自今晚的手动清理记录（clear_cache.txt）
# 注意：运行前请先退出 Safari / Edge / VS Code / 钉钉等应用

echo "==> 清理 ~/.workbuddy*"
rm -rf "$HOME"/.workbuddy* || echo "跳过: ~/.workbuddy*"

echo "==> 清理 ~/Library/Caches/*"
rm -rf "$HOME"/Library/Caches/* || echo "跳过: ~/Library/Caches/*"

echo "==> 删除 Safari 容器数据"
rm -rf "$HOME/Library/Containers/com.apple.Safari" || echo "跳过: com.apple.Safari"

echo "==> 删除 wallpaper agent 容器数据"
rm -rf "$HOME/Library/Containers/com.apple.wallpaper.agent" || echo "跳过: com.apple.wallpaper.agent"

echo "==> 清理 mediaanalysisd 缓存"
rm -rf "$HOME/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/"* || echo "跳过: mediaanalysisd Caches"

echo "==> 删除 Edge Service Worker CacheStorage"
rm -rf "$HOME/Library/Application Support/Microsoft Edge/Default/Service Worker/CacheStorage" || echo "跳过: Edge CacheStorage"

echo "==> 删除 EdgeUpdater"
rm -rf "$HOME/Library/Application Support/Microsoft/EdgeUpdater" || echo "跳过: EdgeUpdater"

echo "==> 清理 VS Code Cache_Data"
rm -rf "$HOME/Library/Application Support/Code/Cache/Cache_Data" || echo "跳过: Code Cache_Data"

echo "==> 清理钉钉 resource_cache"
rm -rf "$HOME/Library/Application Support/DingTalkMac/98485467_v2/resource_cache" || echo "跳过: 钉钉 resource_cache"

echo "==> 清理钉钉 EAppFiles"
rm -rf "$HOME/Library/Application Support/DingTalkMac/98485467_v2/EAppFiles" || echo "跳过: 钉钉 EAppFiles"

echo "==> 清理 npm 缓存"
npm cache clean --force || echo "跳过: npm 缓存"

echo "==> 清理 uv 过期缓存"
uv cache prune || echo "跳过: uv 缓存"

echo "==> 清理 Homebrew 缓存"
brew cleanup -s || echo "跳过: Homebrew 缓存"

# 需要管理员权限
echo "==> 清理 /Library/Caches/* (sudo)"
sudo rm -rf /Library/Caches/* || echo "跳过: /Library/Caches/*"

echo "==> 完成"
