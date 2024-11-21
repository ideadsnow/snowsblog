#!/bin/bash

# 设置主题目录
THEME_DIR="themes/DoIt"

# 检查主题目录是否存在
if [ ! -d "$THEME_DIR" ]; then
  echo "主题目录 $THEME_DIR 不存在。请检查路径。"
  exit 1
fi

# 进入主题目录
cd "$THEME_DIR" || exit

# 拉取最新的主题更新
echo "更新主题 $THEME_DIR..."
git fetch origin main

# 获取当前和最新的提交哈希
CURRENT_COMMIT=$(git rev-parse HEAD)
git checkout main
git pull origin main
LATEST_COMMIT=$(git rev-parse HEAD)

# 检查提交是否有变化
if [ "$CURRENT_COMMIT" == "$LATEST_COMMIT" ]; then
  echo "主题没有更新，无需提交和推送。"
  exit 0
else
  echo "主题已更新。"
fi

# 返回主项目目录
cd ../..

# 提交更改
echo "提交主题更新..."
git add "$THEME_DIR"
git commit -m "Update DoIt theme submodule to latest version"

# 推送到远程仓库
echo "推送到远程仓库..."
git push origin main

echo "更新和提交完成！"
