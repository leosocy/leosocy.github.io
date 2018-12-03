---
title: 深入理解MySQL——MDL
copyright: true
date: 2018-12-02 01:22:40
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/mysql-graphic.png
tags:
- MySQL
categories:
- Database
---

在MySQL使用过程中，不免有对表进行更改的`DDL`操作(alter/drop table)。有的时候我们会发现，一条简单的对表增加字段的操作，会执行很长时间，甚至导致整个数据库挂掉。这是为什么呢？本篇文章就来揭开其中奥秘。

<!-- more -->

## 引子

试想有如下2个session

|session1|session2|
|:------:|:------:|
|BEGIN||
|SELECT * FROM XXX||
||DROP TABLE XXX|
|SELECT * FROM XXX||

如果DROP TABLE成功执行了，那会话1的第二个select会出错，这明显不是我们想要的结果。所以为了避免此类问题，MySQL5.5版本加入了MDL(Metadata Lock)，当对一个表做CRUD操作的时候，加MDL读锁；当要对表做结构变更操作的时候，加MDL写锁。

- 读锁之间不互斥，因此可以有多个线程同时对一张表增删改查。
- 读写锁之间、写锁之间互斥，用来保证变更结构操作的安全性。因此，如果有两个线程要同时给一个表加字段，其中一个要等另一个执行完才能开始执行。

## 采坑实战

虽然MDL锁是MySQL Server层默认加的，但是却不能忽略这个机制。下面这个例子，我们将会看到MDL锁的威力

|session1|session2|session3|session4|
|:------:|:------:|:------:|:------:|
|begin||||
|select * from user limit 1||||
||select * from user limit 1|||
|||alter table user add address varchar(32)||
||||select * from user limit 1|

session1启动，这里我们显示的启动事务，select语句会对user表加MDL读锁。而session2需要的也是MDL读锁，所以可以正常执行。

之后session3需要对表进行DDL操作，请求MDL写锁，但是session1的事务还没有提交，MDL读锁并没有释放，所以被阻塞。

最可怕的是，在session3之后的读请求都会被阻塞，也就是说user表现在完全不可以读写了。你们可能会问，session3也并没有拿到写锁啊，为什么会阻塞后面的读请求呢？这里读者猜想，应该是MySQL内部维护了一个MDL队列，避免MDL写锁一致请求不到。

如果某个表上的查询语句频繁，而且客户端有重试机制，也就是说超时后会再起一个新session再请求的话，这个库的线程很快就会爆满。

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20181203221423.png)

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20181203221700.png)

## 另一个坑

上一节我们知道，如果一个事务没有提交，会阻塞后面的DDL操作。那么，是不是我们执行`select * from information_schema.innodb_trx`查询不到正在执行的事务，就不会出现MDL阻塞的情况了呢?

我们来看下面的例子，查询一个不存在的列

|session1|session2|
|:------:|:------:|
|begin;||
|select unknown from user;||
||alter table user add column address varchar(20)|

我们发现，session2阻塞，等待获取MDL写锁。查看正在运行的事务，发现并没有事务在运行。

```SQL
mysql> mysql> select * from information_schema.innodb_trx\G;
Empty set (0.00 sec)
```

因为`information_schema.innodb_trx`中**不会记录**执行失败的事务，但是在这个执行失败的事务回滚前，它依然持有MDL，所以DDL操作依然会被阻塞。

这个时候我们可以通过查找`performance_schema.events_statements_current`表来找到相关的语句和会话信息

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20181203220937.png)

## 如何解决

当我们对一张表指定DDL操作时，如果执行时间过长，我们就需要警惕了，此时很有可能这张表上出现了长事务或者没有提交的事务。我们可以通过以下步骤依次排查解决

|操作|SQL|原因|处理|
|:-:|:-:|:--:|:-:|
|查看当前是否有正在执行的长事务或者未提交的事务|select * from information_schema.innodb_trx\G|显示(begin;)或者隐式(set autocommit=0)开启事务后未提交或回滚，MDL读锁未释放|暂停DDL或者kill掉事务|
|查看是否有执行失败的事务|select * from performance_schema.events_statements_current\G  select * from performance_schema.threads where thread_id=xx\G|表上有失败的查询事务，比如查询不存在的列，语句失败返回，但是事务没有提交|kill掉|

## 如何预防

上一节讲到了如何解决MDL写锁等待超长的情况。我们知道DDL阻塞会影响后面正常的读写操作，这对一些业务场景来说是完全不可以接受的。所以有些时候我们在执行DDL操作之前，可以执行以下操作检查

1. 检查是否有长事务或者失败的事务未提交，如果有可以等待一段时间再执行
1. 通过设置session的`lock_wait_timeout`，指定MDL锁等待时间，如果在这个指定的等待时间里面拿到MDL写锁最好，拿不到也不要阻塞后面的业务语句，先放弃。

## 总结

1. 长事务危害多多，业务中尽量少用。
1. 即使没有显示的启动事务，也需要检查一下autocommit的值。
1. DDL操作之前先检查innodb_trx
1. 通过`set lock_wait_timeout`设置session的MDL等待时间。
