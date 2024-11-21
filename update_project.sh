#!/bin/bash

# 使用 set -e 来确保脚本在出现错误时退出
set -e

# 默认分支
BRANCH="main"

# 允许用户通过参数指定分支
if [ ! -z "$1" ]; then
  BRANCH="$1"
fi

# 拉取最新的主项目代码
echo "拉取最新的主项目代码从 $BRANCH..."
git pull origin "$BRANCH"

# 更新所有子模块
read -p "是否更新子模块？(y/n): " update_submodules

if [[ "$update_submodules" =~ ^[Yy]$ ]]; then
  echo "更新子模块..."
  git submodule update --init --recursive
fi

echo "主项目代码和子模块更新完成！"
