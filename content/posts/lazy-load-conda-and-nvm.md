+++
date = '2025-03-19T17:50:14+08:00'
lastmod = '2025-03-19T17:50:14+08:00'
draft = false
title = 'Lazy Load Conda and Nvm'
tags = ['Shell', 'Config']
categories = ['Tool && Env']
series = []
+++

随着日常安装的工具越来越多，每次打开新 shell 时，速度越来越慢，这里记录一下我的场景和解决方案。

我用的是 zsh，同时安装了 oh my zsh 插件，所以第一反应是 oh my zsh 这个有名的笨重玩意拖慢了我的 zsh，但是反复通过 `time zsh .zshrc` 实验计算启动时间后发现并不是，真正做坏事的是 `conda` 和 `nvm` 这两个家伙，他们的初始化动作都很耗时。然而我的日常工作流其实使用它们的频率并不高，所以研究了一番后，实现了一套**延迟加载**的玩法，在不影响 zsh 启动的同时，工具也可以按照以前一样正常使用。

废话不多说，直接看代码，在 `.zshrc` 文件中，删除原有 `conda` 和 `nvm` 的初始化代码，然后分别加入这两块代码：

## 针对 `conda`
```shell
# 设置 conda 的 PATH，为了提升在不同环境下的配置通用性，这里提供多个选项
export CONDA_PATH=(/opt/homebrew/bin/conda /data/miniconda3/bin/conda $HOME/miniconda3/bin/conda)
conda() {
    echo "Lazy loading conda upon first invocation..." # 提示行，可以删除
    unfunction conda
    for conda_path in $CONDA_PATH; do
        if [[ -f $conda_path ]]; then
            echo "Using Conda installation found in $conda_path" # 提示行，可以删除
            eval "$($conda_path shell.zsh hook)"
            conda $@
            return
        fi
    done
    echo "No conda installation found in $CONDA_PATH"
}
```

## 针对 `nvm`
```shell
function nvm ()
{
    echo "Lazy loading nvm upon first invocation..." # 提示行，可以删除
    unfunction nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"
    nvm $@
}
```

OK，以后每次打开 zsh 时，它们都不会被默认初始化了，而是在首次使用的时候才进行加载。

另外，针对 `conda`，还可以更进一步，将默认加载 `base` 环境的特性禁用，需要的时候手动加载即可：`conda config --set auto_activate_base false`。

看看我们最后的优化效果！

{{< image src="https://webp.slightsnow.com/2025/03/809147e49c1b49666473fa2067041c69.png" caption="恢复如初的 ZSH！"  height="1000" width="500" >}}


## 小甜点
`conda` 工具链的设计非常不便于使用，切换环境的命令总是让我头痛，又长又没有容错率，所以提供一个快速、且支持模糊搜索的切换环境的办法，同样，也是将这个函数放进 `.zshrc` 里：
```shell
ce() {
    conda activate $(conda info --envs | fzf | awk '{print $1}')
}
```

OK，可以去你的新 zsh 里试试 `ce` 命令了，Just have fun!

{{< image src="https://webp.slightsnow.com/2025/03/993d305092490af7c959c0a6ba878817.png" caption="ce 的运行效果"  height="1000" width="500" >}}
