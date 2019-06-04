---
title: 深入剖析Linux和Docker容器的buffered机制
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

当我们执行`tail -f logfile | grep "foo" | awk '{print $1}'`，并没有看到期望的输出。这是为何？

tail的stdout buffer默认会做`fully-buffered`，由于加上了-f，表示会对输出流进行flush，所以tail -f这部分没什么问题。awk的stdout buffer跟终端相关联，所以默认是`line-buffered`。关键在grep的stdout buffer，它是`fully-buffered`，要等该buffer满了之后awk才会接收到数据。怎么解决这个问题呢？其实grep提供了`--line-buffered`。

除了grep，sed也有对应的`-u(–unbuffered)`，awk有`-W`选项，tcpdump有`-l`选项来将fully-buffered变成line-buffered或者unbuffered。

## Docker日志相关知识

上面一节我们介绍了不同流的缓冲机制，那你有没有想过，当执行`docker logs`时，输出是如何显示的？是否能立刻看到容器内进程的stdout呢？容器的stream是否也有有它自己的缓存呢？我们通过下面一段代码验证

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

按照我们上面说到的知识，我们预期此时执行`docker logs -f test_logs`可以每隔1s看到一次时间输出。但是如果你执行这个命令会发现并没有预期的输出。但是我们attach到容器却可以发现时间输出。

***所以我们推断，`docker logs`本身也有它的输出缓冲区***，那么`docker logs`显示的数据到底是从何而来的呢？

### docker logs机制

我们先来看一段[官网](https://docs.docker.com/config/containers/logging/)上对`docker logs`的解释

The `docker logs` command batch-retrieves logs present at the time of execution.

意思是：`docker logs`命令批量检索执行时出现的日志。

那我不禁要问了，这个日志是哪来的呢？别急我们继续看，官网上罗列了一些支持的[logging drivers](https://docs.docker.com/config/containers/logging/configure/)，默认使用的是`json-file` driver。并且除了`json-file`和`journald`之外，`docker logs`命令对其他驱driver不可用。

所以如果使用了json-file driver，Docker daemon会在container启动的时候创建一个`container.ID-json.log`文件，用于写入此container相关进程的STDOUT，见下面一段源码

```go
switch cfg.Type {
case jsonfilelog.Name:
    info.LogPath, err = container.GetRootResourcePath(fmt.Sprintf("%s-json.log", container.ID))
    if err != nil {
        return nil, err
    }

    container.LogPath = info.LogPath
```

[这篇文章](https://cloud.tencent.com/developer/article/1140079)有对logging-driver更详细的源码级分析。

下面一些截图是对上面文章的实践分析

`ps -ef`查看container内进程与`docker daemon`的关系，可以发现容器内的进程是fork的docker守护进程。

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/buffered_io_docker_process.png)

docker daemon进程的fd，可以发现容器进程的stdout和stderr映射到了daemon进程的文件描述符。

![](	https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/buffered_io_docker_d_fd.png)

> Tips: 根据[源码](https://github.com/moby/moby/blob/master/container/container.go#L619)，只有容器启动进程的输出才会被写入日志，也就是上图的\*init-\*。换个角度说，docker exec进入容器再创建别的线程(e.g `sh -c "while true; do echo test; sleep 1; done"`)的输出，是*不会*被写入日志的。

### docker logs怎么读入文件

由于笔者也没使用过go语言，所以只能通过源码看个大概，下面我们通过源码一步步剖析这条语句是怎么从`*-json.log`中读入日志并显示的。

```go
file: daemon/logs.go

func (daemon *Daemon) ContainerLogs(ctx context.Context, containerName string, config *types.ContainerLogsOptions) (messages <-chan *backend.LogMessage, isTTY bool, retErr error) {
        ...
        cLog, cLogCreated, err := daemon.getLogger(container) // 会获取container的LogDriver(在container初始化的时候定义了一个默认的json-file logger)
        ...
        logReader, ok := cLog.(logger.LogReader)    //这里LogReader是一个interface，如果container的log driver没有实现这个接口，则会报错ErrReadLogsNotSupported
        ...
        logs := logReader.ReadLogs(readConfig)  //默认会调用JSONFileLogger的ReadLogs方法
}

file: daemon/logger/jsonfilelog/read.go

func (l *JSONFileLogger) readLogs(watcher *logger.LogWatcher, config logger.ReadConfig) {
        ...
        l.writer.ReadLogs(config, watcher)  // writer是在logger注册的时候初始化的，下面会解释
        ...
}

file: daemon/logger/jsonfilelog/jsonfilelog.go

func init() {
        if err := logger.RegisterLogDriver(Name, New); err != nil {
                logrus.Fatal(err)
        }   // 注册到工厂，container StartLogger的时候会调用New方法
        if err := logger.RegisterLogOptValidator(Name, ValidateLogOpt); err != nil {
                logrus.Fatal(err)
        }
}

func New(info logger.Info) (logger.Logger, error) {
        ...
        writer, err := loggerutils.NewLogFile(info.LogPath, capval, maxFiles, compress, marshalFunc, decodeFunc, 0640, getTailReader)   // 这里的LogPath就是上面生成的路径
        if err != nil {
                return nil, err
        }

        return &JSONFileLogger{
                writer:  writer,
                readers: make(map[*logger.LogWatcher]struct{}),
                tag:     tag,
        }, nil
}

file: daemon/logger/loggerutils/logfile.go

func (w *LogFile) ReadLogs(config logger.ReadConfig, watcher *logger.LogWatcher) {
        ...
}   // 上面l.writer.ReadLogs实际调用的就是这个方法
```

### 何时写入json-file？

上一节我们从源码级别剖析了`docker logs`的traceback，那回到本节刚开始的问题，为什么没有看到任何输出？而cat该进程的stdout文件描述符却能看到输出？通过上面一部分我们可以推断一定是输出没有被写入到json-file中，我们如法炮制，看看源码吧

我们看到copier.go文件的[第21行](https://github.com/moby/moby/blob/master/daemon/logger/copier.go#L21), [第99行](https://github.com/moby/moby/blob/master/daemon/logger/copier.go#L99)和[第133行](https://github.com/moby/moby/blob/master/daemon/logger/copier.go#L133)，有如下发现

1. 每个容器都为stdout/stderr分配了一个16K的日志读缓冲区
1. 遇到换行会将缓冲区换行前的数据格式化并写入日志文件
1. 缓冲区满会将数据格式化并写入日志文件

读到这终于恍然大悟了，由于本节开始的那一段代码并没有输出换行，所以copier要等到缓冲区满之后才会将输出写入日志文件。如果在输出时间后加一句`sys.stdout.write("\n")`，就会实时的看到输出啦！

## 结论

*Linux下Buffered IO规则：*

1. stdin/stdout stream如果不与终端相关联，比如pipe/redirect，则是`fully-buffered`；反之为`line-buffered`。
1. stderr是unbuffered。

*Python 2和3对于sys.stderr的处理不同，2是`unbuffered`，3是`line-buffered`*

*`docker logs`显示的数据是一定已经写入json-file了*

*`docker daemon`将stream的输出写入日志文件有如下两种情况*

1. 遇到换行
1. 16K stream buffer写满

## 参考资料

- https://stackoverflow.com/questions/39536212/what-are-the-rules-of-automatic-flushing-stdout-buffer-in-c
- http://jaseywang.me/2015/04/01/stdio-%E7%9A%84-buffer-%E9%97%AE%E9%A2%98/
- https://docs.docker.com/config/containers/logging/configure/
- https://github.com/moby/moby