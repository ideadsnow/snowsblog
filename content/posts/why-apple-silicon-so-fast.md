+++
date = '2025-01-21T11:20:56+08:00'
lastmod = '2025-01-21T11:20:56+08:00'
draft = false
title = '为什么 Apple Silicon 如此之快？'
tags = ['Thinking', 'Ask Why']
categories = ['Hardware']
series = []
+++

**在真实的使用体验和各种测试中，M 系列芯片的 Mac 性能几乎吊打 Intel 系列的 Mac，大家不禁要问，这到底是怎么做到的？**

本文将以 M1 芯片为例，尽力把 Apple 在 M 系列芯片上施展的黑魔法一一讲明白。我想很多人都会有这样的疑问：
1. M1 芯片这么快的原因是什么？
2. Apple 在技术上是不是做了一些特别的选择？
3. 对于 Intel 和 AMD 这样的对手来说，采用相同的方案是不是容易？

当然你可以先尝试去 Google 一下，但是估计你很快就会被晦涩的专业术语淹没，比如例如 M1 使用了非常宽的指令解码器、巨大的重排缓冲区（ROB）等。除非你是芯片专家，否则你看的大部分东西其实都是废话。

为了能更好地讨论下面的内容，建议阅读这篇文章 [What Does RISC and CISC Mean in 2020?](https://medium.com/swlh/what-does-risc-and-cisc-mean-in-2020-7b4d42c9a9de)，这里面解释了 CPU 的核心概念如：
- 指令集架构（ISA）
- 流水线（Pipelining）
- 加载、存储架构（Load/Store architecture）
- 微代码和微操作（microcode vs. micro-operations）

但是如果你是急性子，下面是一些简要说明，方便你快速了解～

## 什么是微处理器（中央处理器）

通常，在谈到 Intel 和 AMD 的芯片时，我们会说到微处理器（microprocessors）或者中央处理器（CPU）。这些处理器从内存中提取指令。然后，每条指令通常按顺序执行。

{{< image src="https://webp.slightsnow.com/2025/01/2fe246a59da016cadf42ee5237c220e8.png" caption="一个非常基本的 RISC CPU，不是 M1。指令从内存沿着蓝色箭头进入指令寄存器。在寄存器中，解码器会找出指令的内容，并通过红色控制线启动 CPU 的不同部分。ALU 对寄存器中的数字进行加减运算。"  height="1000" width="500" >}}

最基本的中央处理器是一种设备，其中包含一些名为寄存器的存储单元和一些名为算术逻辑单元（ALU）的计算单元。ALU 执行加法、减法和其他基本数学运算。不过，这些单元只与 CPU 寄存器相连。如果要将两个数字相加，就必须将这两个数字从内存中取出，然后输入中央处理器的两个寄存器。

下面是一些 RISC CPU（如 M1）执行的典型指令示例。

```nasm
load r1, 150
load r2, 200
add  r1, r2
store r1, 310
```

这里的 r1 和 r2 就是上面提到的寄存器。现代 RISC CPU 无法对不在寄存器中的数字进行操作。例如，它无法将 RAM 中两个不同位置的两个数字相加。相反，它必须将这两个数拉到一个单独的寄存器中。这就是我们在这个简单例子中要做的。我们输入 RAM 中内存位置 150 的数字，并将其放入 CPU 中的寄存器 r1。接着，我们将地址 200 的内容放入寄存器 r2。只有这样，才能使用 add r1, r2 指令将这两个数字相加。

{{< image src="https://webp.slightsnow.com/2025/01/0cfbd09674d4f928526e16dfafb3ff49.png" caption="老式机械计算器有两个寄存器：累加器和输入寄存器。现代 CPU 通常有十几个寄存器，而且是电子寄存器而非机械寄存器。"  height="1000" width="500" >}}

寄存器的概念由来已久。例如，在这台老式机械计算器上，寄存器就是用来存放加法的数字的，这可能就是寄存器一词的由来？寄存器是登记输入数字的地方。

## M1 不是一个 CPU！

关于 M1，有一点非常重要：

**M1 不是一个 CPU，它是一个由多个芯片组成完整系统，CPU 只是其中的一个芯片。**

从根本上说，M1 是一个芯片上的完整计算机。M1 包含 CPU、图形处理单元 (GPU)、内存、输入和输出控制器，以及构成整台计算机的其他许多部件。这就是我们所说的片上系统（SoC）。

{{< image src="https://webp.slightsnow.com/2025/01/3d3edf6d04cb172f24fbc00e364baa72.png" caption="M1 是芯片上的系统。也就是说，组成计算机的所有部件都放在一个硅芯片上。"  height="1000" width="500" >}}

如今，无论是 Intel 还是 AMD，只要购买芯片，就等于在一个封装中购买了多个微处理器。过去，电脑主板上会有多个物理上独立的芯片。

{{< image src="https://webp.slightsnow.com/2025/01/679e5600656fb37b4516920742ae2357.png" caption="计算机主板示例。内存、CPU、图形卡、IO 控制器、网卡和许多其他组件都可以连接到主板上，以便相互通信。"  height="1000" width="500" >}}

由于我们今天能够在硅芯片上放置如此多的晶体管，因此 Intel 和 AMD 等公司开始将多个微处理器放在一个芯片上。今天，我们将这些芯片称为 CPU 内核。一个内核基本上是一个完全独立的芯片，可以从内存中读取指令并执行计算。

{{< image src="https://webp.slightsnow.com/2025/01/74a6405ed00952ae547664000f2a4a65.png" caption="具有多个 CPU 内核的微芯片"  height="1000" width="500" >}}

长期以来，这种在一个芯片中塞更多通用 CPU 内核的方式，一直都是提高性能的流行方案。但是现在，CPU 市场中有一个参与者另辟了一条蹊径。

### Apple 不那么秘密的异构计算战略

Apple 没有添加更多的通用 CPU 内核，而是走了另一条路：他们开始添加越来越专业的芯片来执行一些专项任务。这样做的好处是，与通用 CPU 内核相比，专用芯片往往能够使用更少的电流以更快的速度显着完成任务。

这并不是什么新概念，多年来 Nvidia 和 AMD 显卡中已经安装了图形处理单元 （GPU） 等专用芯片，它们执行与图形相关的操作的速度比通用 CPU 快得多。

而 Apple 在这条路上进行了更彻底的推进，M1 不仅具有通用内核和内存，还包含各种专用芯片：

- CPU：SoC 的大脑，运行操作系统和应用程序的大部分代码
- GPU：处理与图形相关的任务，例如可视化应用程序的 UI、2D/3D 游戏
- 图像处理单元（ISP）：加快一些图像处理应用程序的日常任务
- 数字信号处理器（DSP）：处理数学密集型更难，比如解压缩音乐文件
- 神经处理单元（NPU）：加速 AI 任务，包括语音识别、摄像头处理等
- 视频编解码器：处理视频编解码
- 安全隔离：加密、身份验证、安全性
- 统一内存：允许 CPU、GPU 和其他内核快速交换信息

这就是使用 M1 Mac 处理图像和视频编辑任务的用户感到速度提升的其中一部分原因：许多任务可以**直接在专用硬件上运行**。

这就是为什么便宜的 M1 Mac Mini 可以轻松编解码大视频的原因（而更贵的 Intel 架构的 Mac 的所有风扇都开足马力都赶不上）。

### Apple 的统一内存架构有什么特别之处？

{{< image src="https://webp.slightsnow.com/2025/01/f633fb78a5ef6babd22a41db0e395b35.png" caption="蓝色部分可以看到多个 CPU 内核访问内存，绿色部分则显示大量 GPU 内核访问内存。"  height="1000" width="500" >}}

很长时间以来，廉价的入门电脑一直把 CPU 和 GPU 集成到同一块芯片上，而大家的对这种电脑的印象都是卡顿、慢。基本上过去大家提到“集成显卡”的时候的隐含的意思都是“慢”。

一方面，CPU 和 GPU 分别使用不同的内存区域。如果 CPU 想让 GPU 使用某块数据，CPU 必须明确地将整块数据复制到 GPU 控制的内存区域。CPU 生产数据的速度比较慢，而 GPU 消费数据的速度飞快，因为它是并行的，因为需求和特性非常不同，把 CPU 和 GPU 放在同一块芯片上并不是什么好主意。

另一方面，GPU 会产生大量热量，独立的高性能显卡往往体积都相当巨大，携带了好几个夸张的风扇来降温，而且它们有自己的特殊的专用内存，可以为贪婪的 GPU 提供大量数据。

{{< image src="https://webp.slightsnow.com/2025/01/9972b6aa7f8fcfdd4481eaf24b780355.png" caption="GeForce RTX 3080  GeForce RTX 3080 显卡"  height="1000" width="500" >}}

但是独立显卡有一个严重的问题，每当它们必须从 CPU 使用的内存中获取数据时，就必须经过主板上的 PCIe 总线，这条传输管道的吞吐量是很低的。

Apple 的统一内存架构试图解决所有这些问题，而不会有老式共享内存的缺点。他们通过以下方式实现此目的：

1. 没有专门为 CPU 或 GPU 保留的特殊区域，内存分配给两个处理器，它们可以直接使用相同内存，无需复制
2. 使用同时拥有低延迟和高吞吐的性能的内存，因此不需要操作不同的内存
3. 提升 GPU 的能耗，降低发热量。另外 ARM 芯片产生的热量更低，所以相对于 Intel 和 AMD 的芯片，GPU 可以使用的热量配额更高

有人会说，统一内存并非全新事物。的确，过去不同的系统都有过统一内存。但那时的内存需求差异可能没有这么大。其次，Nvidia 所谓的统一内存其实并不是一回事。在 Nvidia 的世界里，统一内存仅仅意味着有软件和硬件负责在独立的 CPU 和 GPU 内存之间自动来回复制数据。因此，从程序员的角度来看， Apple 和 Nvidia 的统一内存可能看起来一样，但从物理意义上讲并不相同。

当然，这种策略也是有代价的。获得这种高带宽内存（大容量）需要完全集成，这意味着你将剥夺用户升级内存的机会。但 Apple 试图尽量降低这个问题的影响（maybe…），也就是使用高速的固态硬盘，利用 Swap 能力直接将硬盘当成和老式内存性能差不太多的的扩展内存使用。

{{< image src="https://webp.slightsnow.com/2025/01/168dde851c453c44e99a31175a7414c6.png" caption="Mac 在使用统一内存之前是如何使用 GPU 的。甚至还可以使用 Thunderbolt 3 线在电脑外安装显卡。"  height="1000" width="500" >}}

### 为什么 SoC 这么强，为什么 Intel 和 AMD 不这么干？

这个问题没错，而且确实，他们早就在尝试这么干了。

AMD 也开始在部分芯片上采用更强大的 GPU，并逐步转向某种形式的 SoC，其中包括加速处理单元（APU），APU 基本上是将 CPU 内核和 GPU 内核置于同一硅片上。

{{< image src="https://webp.slightsnow.com/2025/01/88f8178272c59e530c7ab478e31d4274.png" caption="AMD Ryzen 加速处理单元 (APU)，将 CPU 和 GPU（Radeon Vega）集成在一个芯片上。但不包含其他协处理器、IO 控制器或统一内存。"  height="1000" width="500" >}}

然而，它们做不到是有重要原因的。SoC 本质上是将整台计算机集成在一个芯片上，因此它更适合惠普和戴尔等真正的 PC 制造商。用一个比喻来说就是：如果你的商业模式是制造和销售汽车发动机，那么开始制造和销售整车将是一个巨大的变化。

但是对 ARM 来说，这不是什么问题。惠普和戴尔可以简单地授权、购买、使用各种芯片技术（包括 ARM）和各种专用硬件，并把它们完成的设计送到代工厂进行生产，例如 GlobalFoundries 和台积电。

{{< image src="https://webp.slightsnow.com/2025/01/7588ed6accdb79c1009620ffda10a46f.png" caption="台积电在台湾的半导体代工。台积电为 AMD、Apple、Nvidia 和 Qualcomm 等其他公司制造芯片。"  height="1000" width="500" >}}

这里就产生了一个大问题，Intel 和 AMD 商业模式基于销售通用 CPU，计算机厂商需要从不同供应商购买主板、内存、CPU 和显卡，并把它们集成到一个解决方案里面。但是在新的 SoC 世界，不再需要组装来自不同供应商的物理元件，而是需要组装不同供应商的 IP（知识产权）。从不同的供应商那里购买图形卡、CPU、调制解调器、IO 控制器和其他东西的设计，并利用这些设计在内部设计 SoC，然后由代工厂进行生产。

但是，Intel、AMD、Nvidia 都不会把他们的 IP 许可给戴尔和惠普，让他们给自己的机器制造 SoC。

当然，Intel 和 AMD 可能只是开始销售完整的 SoC 成品。但是，这些产品应该包含哪些内容呢？PC 制造商可能对它们应该包含的内容有不同的看法。Intel、AMD、微软和 PC 制造商之间可能会就应该包含什么样的专用芯片发生冲突，因为这些芯片需要软件支持。

对于 Apple 来说，这很简单，他们控制着整个工具链。例如，他们提供 Core ML 库，供开发人员编写机器学习内容。至于 Core ML 是在 Apple 的 CPU 上运行，还是在神经引擎上运行，这都是开发人员不必关心的实现细节。

### 让 CPU 快速运行的根本挑战

异构计算是部分原因，但不是唯一原因。

M1 上名为 Firestorm 的快速通用 CPU 内核速度非常快。这与过去的 ARM CPU 内核大相径庭，因为与 AMD 和 Intel 内核相比，ARM CPU 内核往往非常弱。

相比之下，Firestorm 超越了大多数 Intel 内核，几乎超越了最快的 AMD Ryzen 内核。传统观念认为这是不可能的。

在讨论 Firestorm 快速的原因之前，我们先来了解一下制造快速 CPU 的核心理念到底是什么。原则上，可以通过两种策略的组合来实现：

1. 在一个序列中更快地执行更多指令
2. 并行执行大量指令

在过去，这很容易，只要提高时钟频率，指令就能更快完成。每个时钟周期，计算机都会做一些事情。但这个动作可能很小。一条指令可能需要多个时钟周期才能完成，因为它是由多个较小的任务组成的。

然而如今，提高时钟频率几乎是不可能的，这就是人们十多年来一直喋喋不休的 "摩尔定律的终结"。

因此，真正的问题在于尽可能多地并行执行指令。

### 多核或者乱序处理器？

有两种方法可以实现这个目标：

- 加更多的内核，每个内核独立且并行
- 让每个 CPU 内核并行执行多条指令

对软件开发工程师来说，添加内核就像加线程，每个 CPU 内核就像一个硬件线程。

处理器可以只有一个内核，但是却能运行多个线程。在这种情况下，它只需暂停一个线程并存储当前进度，然后再切换到另一个线程，之后再切换回来。除非线程本身确实需要频繁暂停，否则这并不会提高多少整体性能。一些需要频繁暂停的场景例如：

- 等待用户输入
- 从缓慢的网络连接中获取数据等

我们称这些为软件线程，而硬件线程意味着你可以使用实际的物理 CPU 内核来加快速度。

{{< image src="https://webp.slightsnow.com/2025/01/c3b294803fbd16d7788b7d0164cd5c83.png" caption="image "  height="1000" width="500" >}}

线程的问题在于，软件开发人员必须编写所谓的多线程代码，这通常很困难。在过去，这是一些最难编写的代码。然而，服务器软件的多线程化往往很容易。只需在单独的线程上处理每个用户请求即可。因此，在这种情况下，拥有大量内核是一个明显的优势，特别是对于云服务而言。

{{< image src="https://webp.slightsnow.com/2025/01/c35fc8b5bc62d057ec9fc7b4cbee0178.png" caption="Ampere Altra Max ARM CPU 有 128 个内核，专为云计算而设计，大量的硬件线程对云计算大有裨益。"  height="1000" width="500" >}}

正因为如此，Ampere 等 ARM CPU 制造商才会制造出像 Altra Max 这样拥有 128 个内核的 CPU。这种芯片专门为云计算而生。因为在云计算中，每瓦特要有尽可能多的线程，以处理尽可能多的并发用户，所以你不需要很强的单核性能。

而 Apple 则完全相反，他们制造的是单用户设备，线程过多并不是优势。他们的设备用于游戏、视频编辑、开发等场景，他们需要具有漂亮的响应式图形和动画的桌面。桌面软件一般不会使用大量内核。例如，电脑游戏可能会从 8 个内核中受益，但 128 个内核就完全是浪费了。这种场景下你需要更少但更强大的内核。

### 乱序执行是如何工作的

要使内核功能更强大，我们需要它能并行执行更多指令。乱序执行（OoOE）是一种并行执行更多指令的方法，但不需要以多线程的形式暴露这种能力。

开发者不必为利用 OoOE 而专门编写软件代码。从开发者的角度来看，它只是看起来每个内核运行得更快。

要了解 OoOE 如何工作，需要了解一些关于内存的知识：在一个特定的内存位置请求数据是很慢的，但 CPU 能够同时获取多个字节。因此，在内存中获取 1 个特定字节所需的时间不会少于在内存中获取该字节之后的 100 个字节所需的时间。

{{< image src="https://webp.slightsnow.com/2025/01/9359b414300688d35b39bdd645b16974.png" caption="挪威网上商店 [Komplett.no](http://komplett.no/) 仓库中的机器人拣选机"  height="1000" width="500" >}}

这里有一个类比：想想仓库里的拣货员，可以是上图中的红色小机器人。小机器人移动到分布在各处的多个地点需要时间，但从相邻的插槽中拾取物品却很快。计算机内存也非常类似，你可以快速获取相邻内存单元的内容。

数据是通过我们所说的数据总线发送的，你可以把它想象成内存和 CPU 不同部分之间的道路或管道，数据就是在这里被传送的。实际上，它只是一些导电的铜轨。如果数据总线足够宽，就可以同时获得多个字节。

因此，CPU 一次可以执行一整块指令。但是，这些指令在编写时是一条接一条执行的。现代微处理器执行的是我们所说的 "乱序执行"（OoOE）。

这意味着它们能够快速分析指令缓冲区，并找出哪些指令依赖于哪些指令。看下面这个简单的例子：

```nasm
01: mul r1, r2, r3    // r1 ← r2 × r3
02: add r4, r1, 5     // r4 ← r1 + 5
03: add r6, r2, 1     // r6 ← r2 + 1
```

乘法往往是一个缓慢的过程，它需要多个时钟周期来执行。因为第二条指令的计算依赖放入 r1 寄存器的结果，所以第二条指令将不得不等待。

然而，位于第 03 行的第三条指令并不依赖于前几条指令的计算结果。因此，乱序处理器可以开始并行计算这条指令。

在更加现实的场景下，CPU 能够找出几百几千条指令之间的所有依赖关系：它通过查看每条指令的输入来分析指令。输入是否依赖于一条或多条其他指令的输出？输入和输出指的是包含先前计算结果的寄存器。

例如，`add r4, r1, 5` 指令依赖于 r1 的输入，而 r1 的输入是由 `mul r1, r2, r3` 产生的。我们可以将这些关系串联起来，形成 CPU 可以处理的复杂长图，图中的节点是指令，边是连接指令的寄存器。

CPU 可以分析这样的节点图，确定哪些指令可以并行执行，哪些指令需要等待多个相关计算的结果后才能继续执行。许多指令会提前完成，但是我们不能马上提交它们，否则就会以错误的顺序提供结果。在外部看来，这些指令必须按照它们发出时的顺序执行。就像堆栈一样，CPU 会不断从顶层弹出已完成的指令，直到弹出一条未完成的指令。

总体来看，并行有两种形式：一种是开发者在编写代码时必须明确处理的，另一种是对上层完全透明的。当然，后者需要 CPU 上有大量晶体管专门用于乱序执行。对于晶体管数量很少的小型 CPU 来说，这不是一个可行的解决方案。

正是“乱序执行”让 M1 上的 Firestorm 内核大显身手，名声大噪。

### ISA 指令与微操作

在此之前，我们略过了一些关于乱序执行（OoOE）工作原理的细节。

加载到内存中的程序是由为特定指令集架构（ISA）（如 x86、ARM、PowerPC、68K、MIPS、AVR 等）设计的机器码指令组成的。

例如，将一个数字从内存位置 24 取到寄存器中的 x86 指令，你可以写成：

```nasm
MOV ax, 24
```

x86 的寄存器名为 ax、bx、cx 和 dx，而 ARM 的等效指令是这样的

```nasm
LDR r0, 24
```

AMD 和 Intel 处理器理解 x86 ISA，而 M1 等 Apple Silicon 芯片则理解 ARM 指令集架构 (ISA)。

然而，在 CPU 内部，程序员看不到完全不同的指令集，我们称之为微操作（micro-ops 或 μops），这些就是乱序硬件所使用的指令。

但为什么 OoOE 硬件不能使用普通机器码指令呢？因为 CPU 需要为指令附加大量不同的信息，以便并行运行这些指令。因此，普通的 ARM 指令可能是 32 位（32 位 0 和 1），而微操作指令可能更长。它包含指令顺序信息。

```nasm
01: mul r1, r2, r3    // r1 ← r2 × r3
02: add r4, r1, 5     // r4 ← r1 + 5
03: add r1, r2, 1     // r1 ← r2 + 1
```

假设我们并行运行指令 `01: mul 和 03: add`。这两条指令都将结果存储在寄存器 r1 中。如果我们在 `01: mul` 之前写入指令 `03: add` 的结果，那么指令 `02: add` 就会得到错误的输入。因此，跟踪指令顺序非常重要。指令顺序存储在每个微操作中。例如，指令 `02: add` 取决于 `01: mul` 的输出。

这就是我们不能使用微操作编写程序的原因，它们包含了每个微处理器内部特有的大量细节，两个 ARM 处理器的内部微操作可能完全不同。

此外，对于 CPU 而言，微操作通常更容易处理。为什么？因为它们各自只完成一个简单而有限的任务。常规的 ISA 指令可能更复杂，会导致很多事情发生，因此经常转化为多个微操作。因此，"micro "这个名称来自于它们执行的小任务，而不是内存中指令的长度。

对于 CISC CPU 而言，通常别无选择，只能使用 micro-ops，否则大型复杂的 CISC 指令将使流水线和 OoOE 几乎无法实现。RISC CPU 可以选择，例如较小的 ARM CPU 根本不使用 micro-ops，但这也意味着它们无法实现 OoOE 等功能。

### 为什么 AMD 和 Intel 的失序执行不如 M1？

快速运行的能力取决于你能以多快的速度填满微操作缓冲区。如果缓冲区很大，那么 OoOE 硬件就更容易找到两个或更多可以并行运行的指令。但是，如果在指令被选中并执行后，不能以足够快的速度重新填满指令缓冲区，那么指令缓冲区再大也没有意义。

指令缓冲区的快速填充能力取决于将机器码指令快速切分成微操作的能力，实现这一功能的硬件单元称为解码器。

最后，我们来看看 M1 的杀手锏：

- 最强大的 Intel 和 AMD 微处理器有四个解码器，用来忙于将机器码指令切割成微操作。
- 但 M1 的解码器数量是多少？八个！比业内任何其他公司都要多得多。这意味着它可以更快地填满指令缓冲区。
- 此外，M1 还配备了一个指令缓冲器，其容量是业内正常值的 3 倍。

### 为什么 Intel 和 AMD 不能增加更多的指令解码器？

在这里，我们终于看到了 RISC 的复仇，也看到了 M1 Firestorm 内核采用 ARM RISC 架构的重要性。

x86 指令的长度为 1-15 字节，RISC 指令的长度是固定的，每条 ARM 指令都有 4 个字节长。如果每条指令的长度相同，那么将字节流分割成指令并行输入 8 个不同的解码器就很容易了。然而，在 x86 CPU 上，解码器根本不知道下一条指令从哪里开始。它必须实际分析每条指令，才能知道它有多长。Intel 和 AMD 处理这个问题的方法，就是简单暴力地尝试在每个可能的起点对指令进行解码。这意味着 x86 芯片必须处理大量错误的猜测和错误，而这些猜测和错误必须被舍弃。这就造成了解码器阶段的错综复杂，以至于很难增加更多的解码器。但对于 Apple 来说，增加解码器是非常简单的。

实际上，增加解码器也会带来许多其他问题，因此 AMD 自己认为 4 个解码器基本上就是他们的上限了。

正因如此，在相同的时钟频率下，M1 Firestorm 内核的指令处理量基本上是 AMD 和 Intel  CPU 的两倍。

但可能有人会反驳说，CISC 指令可以转化为更多的微操作。例如，如果每条 x86 指令产生 2 个 micro-op，而每条 ARM 指令产生 1 个 micro-op，那么 4 个 x86 解码器在每个时钟周期产生的 micro-op 数量与具有 8 个解码器的 ARM CPU 相同。

但实际情况并非如此。高度优化的 x86 代码很少使用复杂的 CISC 指令，而复杂的 CISC 指令会转化为许多微操作。实际上大多数情况下只能转化为 1 个微操作。

然而，所有这些简单的 x86 指令并不能帮助 Intel 或 AMD。因为即使这些 15 字节长的指令很少见，也必须制造解码器来处理它们。这就造成了复杂性，阻碍了 AMD 和 Intel 增加更多的解码器。

### 但是 AMDs Zen3 内核们仍然很快不是吗？

凭我的印象，AMD 当时最新的 CPU 内核（即 Zen3 内核）比 Firestorm 内核稍快一些。但问题是：这只是因为 Zen3 内核的主频为 5 GHz，而 Firestorm 内核的主频为 3.2GHz。尽管 Zen3 的时钟频率比 Firestorm 高出近 60%，但也只是勉强超过 Firestorm。

那么， Apple 为什么不提高时钟频率呢？因为更高的时钟频率会使芯片的运行温度更高。而更低的温度是 Apple 的关键卖点之一：与 Intel 和 AMD 的产品不同，他们的电脑几乎不需要散热。

从本质上讲，可以说 Firestorm 内核确实优于 Zen3 内核，Zen3 只能通过消耗更多的电流和更高的温度来保持性能，而这正是 Apple 所不愿意做的。

如果 Apple 希望获得更高的性能，他们只需增加更多的内核。这样既能降低功耗，又能提供更高的性能。

### 未来

AMD 和 Intel 似乎在两个方面把自己逼入了绝境：

- 它们的商业模式不便于追求异构计算和 SoC 设计。
- 它们的传统 x86 CISC 指令集又开始困扰它们，使其难以提高 OoO 性能。

### x86 的反击

这并不意味着游戏已经结束了。他们可以提高时钟频率，使用更多散热装置，增加内核，加强 CPU 缓存等。对抗 RISC 解码器优势的最明显方法是使用微操作缓存（[micro-op caches](https://en.wikipedia.org/wiki/CPU_cache#Micro-operation_(%CE%BCop_or_uop)_cache)）。这是一种克服 CISC 处理器解码变长指令复杂性的特殊策略。在解码新指令之前，CPU 可以检查相同指令是否已被解码。大多数程序往往会大量重复某些指令（循环），这意味着这种方法非常有效。因此，只要你运行的是紧凑的循环，它们就能消除 M1 的优势。

因此，游戏还没有结束，但这也表明 AMD 和 Intel 必须想出更多巧妙的招数，来应对因指令集架构（ISA）老化而人为产生的问题。

因此，游戏还远未结束，但 Intel 和 AMD 在玩 CPU 的游戏时已经戴上了手铐。它们可以通过投入更多资金和提高产量来解决问题，从而保持领先地位。但从长远来看，当你面对比世界上任何其他公司都拥有更多利润和大量现金的 Apple 公司时，这样做的效果如何还有待观察。

---

本文为译文阅读笔记，原文来自 [What Makes Apple Silicon So Fast?](https://medium.com/swlh/what-does-risc-and-cisc-mean-in-2020-7b4d42c9a9de)