---
title: I/O的buffered缓冲机制
copyright: true
date: 2019-01-30 13:30:09
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/stdout_stdin_stderr.jpg
tags:
- Buffered I/O
- Docker
categories:
- 基础知识/技能
---

# Buffered I/O

最近在查证一个生产环境上Pod数据打点没有被记录到ES的问题，起初怀疑是Docker容器的输出缓冲区问题导致打点输出还没有写入日志文件上，所以查了很多关于python输出缓冲、标准输入输出缓冲、容器日志缓冲相关的知识。尽管最后问题定位到了并不是因为输出缓冲引起的，但是还是在此记录下经过一些测试以及资料阅读了解到的Linux下I/O的buffer机制。不想看验证过程的老铁们可以查看[结论](#结论)。

<!-- more -->

## Linux下的三种缓冲模式

- unbuffered: 顾名思义，不缓冲输入输出，有多少读写多少
- fully-buffered: 当缓冲区被填满时，发生一次flush
- line-buffered: 遇到换行(一般就是'\n')或者当缓冲区满时，发生一次flush

那每种模式对应哪些场景呢？接下来我们用python程序做一些验证。

## 不同缓冲模式下的一些测试

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

执行`python test1.py`，可以发现，终端半天没有输出一个`.`。而如果改为`.\n`或者改为`print(".")`，会每隔1s输出一个`.`，但是如果改为`print(".", end="")`，则不会输出`.`。所以推断，此时缓冲模式为`line-buffered`。

### 不与终端相关联的`stdin/stdout`

什么是不与终端相关联呢？例如pipe，redirect，fopen 打开的文件。

同样是上面一段代码，如果执行`python test2.py > test2.log`(redirect模式)，在另一个终端查看文件，并没有发现test2.log随着时间增大。如果将代码改为如下：

```python
import sys
import time

while True:
    sys.stdout.write(".")
    sys.stdout.flush()
    # or
    # print(".", flush=True)
    time.sleep(1)
```

可以看到文件随着时间增大，所以此处`flush`用途与C语言的`fflush`相同，即将缓冲区输出。推断此时缓冲模式为`fully-buffered`。

### stderr的缓冲模式

在Linux上，stderr通常是`unbuffered`的，这是为了可以及时输出错误的信息。

但是stderr可能在python2/3上有不同的表现，例如下面一段代码

```python
import sys
import time

while True:
    sys.stderr.write(".")
    time.sleep(1)
```

首先执行`python3 test3.py`，发现并没有立即看到输出，而加上换行后又可以看到输出，所以在python3的实现中，stderr为`line-buffered`。

然后执行`python2.7 test3.py`，可以立即看到输出，所以stderr在python2中为`unbuffered`。

### 看一个跟pipe相关的问题

logfile有如下内容

```txt
foo
bar
```

当我们执行`tail -f logfile | grep "foo" | awk '{print $1}'`，并没有看到期望的输出。

tail的stdout buffer默认会做fully-buffered，由于加上了-f，表示会对输出流进行flush，所以tail -f这部分没什么问题。awk的stdout buffer跟终端相关联，所以默认是line-buffered。关键在grep的stdout buffer，它是fully-buffered，要等该buffer满了之后awk才会接收到数据。怎么解决这个问题呢？其实grep提供了`--line-buffered`。

除了grep，sed也有对应的`-u(–unbuffered)`，awk有`-W`选项，tcpdump有`-l选项来将fully-buffered变成line-buffered或者unbuffered。

## Docker日志相关知识

上面一节我们介绍了不同流的缓冲机制，那你有没有想过，当执行`docker logs`时，输出是如何显示的？是否能立刻看到容器内进程的stdout呢？容器是否也有有它自己的缓存呢？我们通过下面一段代码验证

```python
cat test.py

import sys
import time
import datetime

while True:
    sys.stdout.write(datetime.datetime.now().isoformat())
    sys.stdout.flush()
    time.sleep(1)
```

执行`docker run -d --rm -v $(pwd):/app -w /app --lo
g-driver json-file --name test_logs python python test.py`

按照我们上面说到的知识，我们预期此时执行`docker logs -f test_logs`可以每隔1s看到一次时间输出。但是如果你执行这个命令会发现并没有预期的输出。

***所以我们推断，容器本身也有它的输出缓冲区***，那么`docker logs`显示的数据到底是从何而来的呢？

### docker logs机制

### 何时写入json-file？

https://github.com/moby/moby/blob/master/daemon/logger/copier.go#L99

## 结论

## 参考资料
