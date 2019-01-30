---
title: I/O的buffered缓冲机制
copyright: true
date: 2019-01-30 13:30:09
tags:
- Buffered I/O
- Docker
categories:
- 基础知识/技能
---

# Buffered I/O

最近在查证一个生产环境上Pod数据打点没有被记录到ES的问题，起初怀疑是Docker容器的输出缓冲区问题导致打点输出还没有写入日志文件上，所以查了很多关于python输出缓冲、标准输入输出缓冲、容器日志缓冲相关的知识。尽管最后问题定位到了并不是因为输出缓冲引起的，但是还是在此记录下经过一些测试以及资料阅读了解到的Linux下I/O的buffer机制。不想看验证过程的老铁们可以查看[结论](#结论)。

<!-- more -->

## 三种缓冲模式

- unbuffered: 顾名思义，不缓冲输入输出
- fully-buffered: 当缓冲区被填满时，字符将被发出或读入
- line-buffered: 当产生新行或者当缓冲区满时，缓冲区字符将被发出或读入

那每种模式对应哪些场景呢？接下来我们用python程序做一些验证。

## 一些测试

### 与终端相关联的`stdin/stdout`

[什么是终端？](https://www.zhihu.com/question/65280843)。简单来说可以是本地打开terminal/xTerm
，或者ssh连接远程主机。

有下面一小段代码，执行后会发生什么呢？

```python
import sys
import time

while True:
    sys.stdout.write(".")
    time.sleep(1)
```

执行`python test1.py`，可以发现，终端半天没有输出一个`.`。而如果改为`.\n`或者改为`print(".")`，会每隔1s输出一个`.`，但是如果改为`print(".", end="")`，则不会输出`.`。所以推断，此时缓冲模式为*line-buffered*。

### 不与终端相关联的`stdin/stdout`

什么是不与终端相关联呢？例如pipe，redirect，fopen 打开的文件。

同样是上面一段代码，如果执行`python test1.py > test1.log`，在另一个终端查看文件，并没有发现test1.log随着时间增大。如果将代码改为如下：

```python
import sys
import time

while True:
    sys.stdout.write(".")
    sys.stdout.flush()
    time.sleep(1)
```

可以看到文件随着时间增大，所以此处`flush`用途与C语言的`fflush`相同，即将缓冲区输出。推断此时缓冲模式为*fully-buffered*。

### stderr

## 结论

## 参考资料
