---
title: epoll深入学习
copyright: true
date: 2019-03-19 00:28:31
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20190319010209.png
tags:
- epoll
- 并发连接
- socket
categories:
- 基础知识/技能
---

# epoll释疑

**封面图转自[这里](https://blog.csdn.net/dog250/article/details/80837278)**

以前就一直听说事件模型中，epoll比select的效率高出一个量级，epoll的一些优点网上也有很多的文章阐述解释。但是至于为什么epoll如此高效？内核是怎么实现的？我并没有深入研究，所以为了更加深入的了解epoll，近期一直在研究epoll的内核源码（头一次读内核源码还是有些吃力）。大致弄懂了实现原理后才发现，网上的一些解释有的并不是很准确。本篇文章概括了epoll的实现机制，并引出epoll中的惊群问题以及一些解决方法。

<!-- more -->

## Linux epoll实现机制

对于具体实现分析网上已经有很多文章阐述了，我就不再这里赘述。这里贴一篇[文章](https://blog.csdn.net/dog250/article/details/80837278)，我觉得说的很清楚并且是按照源码分析的。

简单来说epoll的实现主要有以下几个逻辑

1. `epoll_create`: 创建epollevent结构体并初始化相关数据结构。创建fd并绑定到epoll对象上。
2. `epoll_ctl`: **从用户空间拷贝**event到内核空间，创建`epitem`并初始化，将要监听的fd绑定到epitem
3. 通过监听fd的poll回调，设置等待队列的entry调用函数为`ep_poll_callback`，并将entry插入到监听fd的“睡眠队列”上。
4. `epoll_ctl`的最后将epitem插入到第一步创建的epollevent的红黑树中。
5. `epoll_wait`: 如果ep的就绪链表为空，根据当前进程初始化一个等待entry并插入到ep的等待队列中。设置当前进程为`TASK_INTERRUPTIBLE`即可被中断唤醒，然后进入”睡眠”状态，让出CPU。
6. 当监听的fd有对应事件发生，则唤醒相关文件句柄睡眠队列的entry，并调用其回调，即`ep_poll_callback`
7. 将发生事件的epitem加入到ep的“就绪链表”中，唤醒阻塞在epoll_wait系统调用的task去处理。
8. `epoll_wait`被调度继续执行，判断就绪链表中有就绪的item，会调用`ep_send_events`向用户态上报事件，即那些epoll_wait返回后能获取的事件。
9. `ep_send_events`会调用传入的`ep_send_events_proc`函数，真正执行将就绪事件从内核空间拷贝到用户空间的操作。
10. 拷贝后会判断对应事件是`ET`还是`LT`模式，如果是LT则无论如何都会将epi重新加回到“就绪链表”，等待下次`epoll_wait`重新再调用监听fd的poll以确认是否仍然有未处理的事件。
11. `ep_send_events_proc`返回后，在`ep_send_events`中会判断，如果“就绪链表”上仍有未处理的epi，且有进程阻塞在epoll句柄的睡眠队列，则唤醒它！(**这就是LT惊群的根源**)，详情可见[源码此处](https://code.woboq.org/linux/linux/fs/eventpoll.c.html#733)。

## LT，ET以及惊群问题

上一节我们提到了LT（水平触发）和ET（边缘触发），简单解释下就是：

1. `LT水平触发`：如果监听的事件发生了，不管一次性发生了几个，只要仍然有未处理的事件，epoll_wait就会**一直返回**给你。
1. `ET`边沿触发：如果监听的事件发生了，不管一次性发生了几个，epoll_wait只会**返回一次**，除非下一个事件到来，否则epoll_wait将不会阻塞。

### 惊群模式有什么危害

1. 不必要的内存拷贝，将事件从内核空间拷贝到用户空间。
1. 增加CPU负载，唤醒进程后accept返回EAGAIN。

### LT模式惊群效应示例

```C
set_socket_nonblock(listen_fd);
int epfd = epoll_create(1);
event.data.fd = listen_fd;
epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &event);
while (keep_running) {
    ...
    int nfds = epoll_wait(epfd, rd_events, 10, timeout_ms);
    ...
    for (int i = 0; i < nfds; ++i) {
        if ((rd_events[i].events & EPOLLIN)
            && (rd_events[i].data.fd == listen_fd)) {
            // 这里如果有多个进程共享同一个epfd并调用epoll_wait，那么它们也将被唤醒！
            // 1. 如果accept队列中有n个请求，则仅有n个进程能成功，其他将全部返回EAGAIN
            // 2. 如果并发连接进一步增大，虽然返回EAGAIN的比例会降低，但这些进程也并不一定取到epoll_wait返回的当下的那个预期的请求
            int conn_fd = accept(listen_fd, (struct sockaddr*)&client_addr, &addrlen);
            ...
        }
    }
}
```

我们来看一个场景举例。假设LT模式下有4个进程共享同一个epoll fd，此时来了一个请求client进入到accept队列，进程唤醒过程如下：

1. 进程A的epoll_wait首先被ep_poll_callback唤醒，内核拷贝event到用户空间，然后将epi重新加回就绪链表，内核发现就绪链表上仍有就绪的epi，则继续唤醒进程B。
1. 进程B在处理`ep_scan_ready_list`时发现依然满足上述条件，于是继续唤醒进程C。
1. 上面1、2两个过程会一直持续到某个进程完成accept，此时下一个被唤醒的进程在`ep_scan_ready_list`中的`ep_item_poll`调用中将得不到任何时间，也就不会再将epi将会就绪链表了。
1. LT水平触发就此结束。

### ET模式下面临的新问题

上一节我们解释了为什么LT模式下会造成惊群问题，究其原因就是内核重新将epi加回到了就绪链表。ET模式下不会将已经上报的事件epi重新加回就绪链表，所以也就不会有惊群的问题。那是不是我们将事件设置成ET模式就万事大吉了呢？我们来接着看

ep_poll_callback所做的事情仅仅是将该epi自身加入到epoll句柄的“就绪链表”，同时唤醒在epoll句柄睡眠队列上的task，所以这里并不对事件的细节进行计数，比如说，如果ep_poll_callback在将一个epi加入“就绪链表”之前发现它已经在“就绪链表”了，那么就不会再次添加，因此可以说，一个epi可能pending了多个事件。

这个在LT模式下没有任何问题，因为获取事件的epi总是会被重新添加回“就绪链表”，那么如果还有事件，在下次epoll_wait的时候总会取到。然而对于ET模式，仅仅将epi从“就绪链表”删除并将事件本身上报后就返回了，因此如果该epi里还有事件，则**只能等待再次发生事件**，进而调用ep_poll_callback时将该epi加入“就绪队列”。

所以当使用ET模式时，epoll_wait的调用进程必须自己在获取到事件后将其处理干净才可再次调用epoll_wait，否则epoll_wait不会返回，而是必须等到下次产生事件的时候方可返回。依然以accept为例，必须这样做：

```c
set_socket_nonblock(listen_fd);
int epfd = epoll_create(1);
event.data.fd = listen_fd;
epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &event);
while (keep_running) {
    ...
    int nfds = epoll_wait(epfd, rd_events, 10, timeout_ms);
    ...
    for (int i = 0; i < nfds; ++i) {
        if ((rd_events[i].events & EPOLLIN)
            && (rd_events[i].data.fd == listen_fd)) {
            int conn_fd;
            while ((conn_fd = accept(listen_fd, (struct sockaddr*)&client_addr, &addrlen) > 0) {
                ...
            }
            ...
        }
    }
}
```

## 来点Demo

下面我们来几个Demo以及测试来巩固一下上面提到的理论。

具体[源码](https://github.com/Leosocy/epoll-example)可以见我的github，这里就不贴具体代码了，只根据不同配置给出测试的结果及结论。其中测试socket链接使用的是[webbench](https://www.cnblogs.com/zhunl/articles/7543318.html)工具。

测试参数统一配置为`webbench -c 10 -t 5 http://localhost:6250/`。这里我们只测试了socket链接，然后直接close了，所以看bench的结果好像不太准确，这里我们通过统计log来看socket连接成功数以及进程惊群数。

- accept数：`cat log | grep accept | wc -l`
- 惊群次数：`cat log | grep thunder | wc -l`

|                           命令                           |                                           解释                                            |            结果统计            |                              结果说明                              |
| :------------------------------------------------------: | :---------------------------------------------------------------------------------------: | :----------------------------: | :----------------------------------------------------------------: |
|          `./server --mode 0 --port 6250 > log`           |                                        LT模式惊群                                         | accept数：95139  惊群次数：733 |                可以发现进程被”惊群“效应唤起了很多次                |
|        `./server --mode 0 --port 6250 --et > log`        |                                      ET模式丢失事件                                       |  accept数：37159  惊群次数：0  | 可以发现虽然没有发生”惊群“现象，但是socket连接事件丢失现象也很严重 |
|   `./server --mode 0 --port 6250 --et --sleep 1 > log`   | ET模式在epoll_wait和accept之间增加sleep操作，这样可以在调用accept之前积累更多的未处理事件 |   accept数：17  惊群次数：0    |        可以发现只有十几个连接建立成功了，事件丢失的相当严重        |
| `./server --mode 0 --port 6250 --et --loop-accept > log` |                                     ET模式循环accept                                      |  accept数：96120  惊群次数：0  |                     可以发事件丢失现象已经解决                     |

## 3.9内核中的socket reuse port

上面一节总结了Linux下基于epoll事件的网络变成”惊群“现象。曾经，为了发挥多核的优势，可以hold住更高的并发连接，出现了两种常见的网络编程模型

1. 单进程创建socket，并进行listen和accept，接收到连接后创建进程和线程处理连接
1. 单进程创建socket，并进行listen，预先创建好多个工作进程或线程accept()在同一个服务器套接字

但是以上两种模型均存在以下问题：

1. 单一listener工作线程在高速的连接接入处理时会成为瓶颈
1. 很难做到CPU之间的负载均衡
1. 随着核数的扩展，性能并没有随着提升

于是为了解决上面的问题，Linux Kernel在3.9引入了`SO_REUSEPORT`特性，主要提供了以下功能：

1. 允许多个套接字 bind()/listen() 同一个TCP/UDP端口，这样每个进程都拥有了自己的服务器套接字
1. 内核层面实现负载均衡

在reuseport机制下，惊群问题就不攻自破了。因为监听同一个ip:port的多个socket本身在socket层就是相互隔离的，在它们之间的事件分发是内核于TCP/IP协议栈完成的，所以不会再有惊群发生。

## 结论

- 服务器内核大于3.9，支持`SO_REUSEPORT`：选择LT模式，不会有惊群效应，代码逻辑简单
- 服务器内核小于3.9，不支持`SO_REUSEPORT`
    - 并发连接数较小，CPU负载不高：选择LT模式，代码逻辑简单，不会遗漏事件
    - 并发连接数较大，CPU负载较高：选择ET模式，提升epoll效率

## 参考文章

- https://blog.csdn.net/dog250/article/details/80837278
- https://blog.csdn.net/dog250/article/details/50528373
- https://www.cnblogs.com/Anker/p/7076537.html