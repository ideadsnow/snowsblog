#!/bin/bash

# 输入文件
input_file="favicon.svg"

# 转换为 ICO
magick -density 300 "$input_file" -resize 48x48 -define icon:auto-resize=48 favicon.ico

# 生成不同大小的 PNG
for size in 16 32 48 64 96 128 192 256 512; do
    magick -density 300 "$input_file" -resize ${size}x${size} "favicon-${size}x${size}.png"
done

# mv favicon-128x128.png apple-touch-icon.png
# mv favicon-192x192.png web-app-manifest-192x192.png
# mv favicon-512x512.png web-app-manifest-512x512.png