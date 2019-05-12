---
title: some traps when using kingshard + peewee
copyright: true
date: 2019-05-11 16:41:55
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/peewee3-logo.png
tags:
- MySQL
- Shard
categories:
- Database
---

当产品用户量、日活与日俱增，后端数据库的负载通常也会越来越大，此时单纯的增加索引已经无法解决亿级数据的CRUD操作了。通常我们会选择分库+分表来解决数据库的瓶颈。使用proxy可以做到对业务层透明，业务无需关心数据库如何shard，SQL如何分发数据如何聚合。我们自己的业务使用的是[kingshard](https://github.com/flike/kingshard)这个用Go实现的开源数据库代理，然后ORM一直使用的是[peewee](http://docs.peewee-orm.com/en/latest/)。在使用的过程中遇到了一些稀奇古怪的问题，这里记录一下排查的过程，以及其中的具体原因，最后给出可行的解决方案。

<!-- more -->

## 准备

根据kingshard[官方文档](https://github.com/flike/kingshard/blob/master/doc/KingDoc/how_to_use_kingshard.md#2-%E5%AE%89%E8%A3%85%E5%92%8C%E5%90%AF%E5%8A%A8%E8%AF%B4%E6%98%8E)，在本地搭建具有两个Node的数据库‘集群’。同时创建好`test_shard_hash`分表，这里我们以`user_id`作为shard_key。

```shell
mysql root@localhost:ks1> show create table test_shard_hash_0001;
+----------------------+-------------------------------------------+
| Table                | Create Table                              |
+----------------------+-------------------------------------------+
| test_shard_hash_0001 | CREATE TABLE `test_shard_hash_0001` (     |
|                      |   `id` bigint(64) unsigned NOT NULL,      |
|                      |   `user_id` bigint(64) unsigned NOT NULL, |
|                      |   `name` varchar(255) NOT NULL,           |
|                      |   `age` smallint(6) NOT NULL,             |
|                      |   PRIMARY KEY (`user_id`,`id`)            |
|                      | ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4   |
+----------------------+-------------------------------------------+
```

pip安装playhouse, peewee, pymysql等package。ipython启动并链接kingshard。

```python
In [1]: import peewee as pw
In [2]: from playhouse import db_url
In [3]: db = db_url.connect("mysql://127.0.0.1", port=9696, user="root", password="root", database="ks1")
In [4]: db.get_tables()
Out[4]:
['test_shard_hash_0000',
 'test_shard_hash_0001',
 'test_shard_hash_0002',
 'test_shard_hash_0003',
 'test_shard_range_0000',
 'test_shard_range_0001',
 'test_shard_range_0002',
 'test_shard_range_0003']
```

创建对应表结构的model，并绑定到db实例。

```python
In [6]: class UserInfo(pw.Model):
   ...:     id = pw.BigIntegerField()
   ...:     user_id = pw.BigIntegerField()
   ...:     name = pw.CharField(max_length=255)
   ...:     age = pw.SmallIntegerField()
   ...:     class Meta:
   ...:         primary_key = pw.CompositeKey("user_id", "id")
   ...:         table_name = "test_shard_hash"
In [7]: UserInfo.bind(db)
Out[7]: True
```

## 复现

下面我们打开kingshard sql日志，试一下CRUD等操作。

create

```python
In [10]: UserInfo.create(user_id=1, id=1, name="", age=0)
Out[10]: <UserInfo: (1, 1)>

kingshard日志
OK - 1.0ms - 127.0.0.1:59593->127.0.0.1:3306:insert  into test_shard_hash_0001(id, user_id, name, age) values (1, 1, '', 0)

测试一下插入冲突
In [11]: UserInfo.create(user_id=1, id=1, name="", age=0)   # IntegrityError: (1062, "Duplicate entry '1-1' for key 'PRIMARY'")
In [12]: UserInfo.create(user_id=5, id=1, name="", age=0)   # InternalError: (1105, 'transaction in multi node')
我们发现kingshard报错了，原因是一个事务跨node了，但是我们这里并没有显式开启事务，这是为什么呢？我们下面会分析。
```

select

```python
In [18]: u = UserInfo.select().where(UserInfo.user_id == 1).first()
In [19]: u.user_id
Out[19]: 1

OK - 0.9ms - 127.0.0.1:59593->127.0.0.1:3306:select t1.id, t1.user_id, t1.name, t1.age from test_shard_hash_0001 as t1 where (t1.user_id = 1) limit 1

跨node的select
In [43]: UserInfo.select() # InternalError: (1105, 'transaction in multi node')
发生了跟之前一样的问题。
```

count

```python
UserInfo.select().where(UserInfo.user_id == 1).count()  # ProgrammingError: (1146, "Table 'ks1.test_shard_hash' doesn't exist")

ERROR - 15.1ms - 127.0.0.1:59593->127.0.0.1:3306:SELECT COUNT(1) FROM (SELECT 1 FROM `test_shard_hash` AS `t1` WHERE (`t1`.`user_id` = 2)) AS `_wrapped`
这说明这种count方法kingshard没办法根据shard_key计算出发往哪张表。我们换一种方法试试：
----------------------------------------------
In [35]: UserInfo.select(pw.fn.COUNT('*')).where(UserInfo.user_id == 1).scalar()
Out[35]: 1

OK - 1.2ms - 127.0.0.1:59593->127.0.0.1:3306:select count('*') from test_shard_hash_0001 as t1 where (t1.user_id = 1)
看来这种写法可行，我们测试一下跨node的count
In [47]: UserInfo.select(pw.fn.COUNT('*')).scalar() # InternalError: (1105, 'transaction in multi node')
还是不行，看来kingshard的跨node基本的操作在peewee里都搞不起来，下面我们会一步步揭开它的神秘面纱。
```

update

```python
In [50]: UserInfo.update(age=10).where(UserInfo.user_id == 1).execute()
Out[50]: 1

测试一下kingshard支持的跨node更新
In [56]: UserInfo.update(age=10).where(UserInfo.user_id.in_((1,5))).execute()   # InternalError: (1105, 'transaction in multi node')
```

通过这些例子我们发现，kingshard支持的一些跨node的操作

- 范围select
- 批量update
- count/sum
- order by

在peewee中都会报`transaction in multi node`的错误。

同时，如果上一条insert/update语句插入冲突报错，再次执行一条分发到另一个node的语句，同样也会报事务跨node的错误。

## 原因

kingshard报`transaction in multi node`的错误，本质上是因为我们显式或隐式的开启了一个事务，然后执行的SQL经过kingshard计算发现会操作不同的node，进而产生的报错。

### kingshard如何判断当前是否处于一个事务下

我们简单的分析一下kingshard如何判断事务跨node的

1. [dispatch](https://github.com/flike/kingshard/blob/master/proxy/server/conn.go#L306)： 循环接收处理client请求
2. [handleQuery](https://github.com/flike/kingshard/blob/master/proxy/server/conn.go#L336)：处理CRUD操作，这里我们拿`select`来说，会走到[handleSelecte](https://github.com/flike/kingshard/blob/master/proxy/server/conn_select.go#L99)。
3. [buildSelectPlan](https://github.com/flike/kingshard/blob/master/proxy/router/router.go#L306)根据SQL构建执行计划，决定要发到哪些node哪些表。
4. [getShardConns](https://github.com/flike/kingshard/blob/master/proxy/server/conn_select.go#L112)中，*如果in transaction*则会根据以下规则判断是否返回`transaction in multi node`错误
   1. 一条执行计划中路由到node的数大于1
   2. 当前为事务下执行的第二条SQL，且未与上一条SQL分发到一个node上

下面我们来重点关注一下如何判断in transaction

1. [isInTransaction](https://github.com/flike/kingshard/blob/master/proxy/server/conn_tx.go#L22)会先根据status按位计算如果大于0则表示in trans，这一位是在[handleBegin](https://github.com/flike/kingshard/blob/master/proxy/server/conn_tx.go#L31)置上的，也就是显式begin一个事务。
2. 然后如果上一个条件不满足，会根据`autocommit`的值来判断，如果autocommit=0，也算是在事务中。这一位是在[handleSetAutoCommit](https://github.com/flike/kingshard/blob/master/proxy/server/conn_set.go#L78)置上的，也就是客户端执行`SET AUTOCOMMIT=x`。默认值[`c.status = mysql.SERVER_STATUS_AUTOCOMMIT`](https://github.com/flike/kingshard/blob/master/proxy/server/server.go#L342)，即autocommit=1

也就是说如果client执行了`begin`，或者`set autocommit=0`，kingshard就会认为当前执行的sql在事务下。

根据上一节的例子，我们并没有显式的开启一个事务，所以一定是peewee建立数据库连接后设置了`set autocommit=0`，我们继续来看一下peewee在建立连接时做了什么。

### peewee建立连接时做了什么

首先为了验证上一节的猜想，我们用wireshark抓包看一下client建立数据库连接后是不是主动设置了`SET AUTOCOMMIT=0`

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20190512222627.png)

通过上图我们发现，在建立会话后的第一条SQL命令之前，client主动发送了`SET AUTOCOMMIT=0`来禁用自动提交模式。

下面是执行了`UserInfo.select().where(UserInfo.user_id == 1).get()`的抓包结果，我们发现在client在select成功之后，又主动执行了commit语句。这也不难理解，毕竟当前session被设置成了autocommit=0，所以需要执行commit来提交当前事务，并开启下一个事务。

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20190512224121.png)

关于autocommit，截取了官网的说明

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20190512224716.png)

综上，我们推断出两点

1. peewee（准确的说是peewee使用的db driver）在创建数据库连接后，默认会设置session的autocommit=0
2. 如果不是显式的开启事务，默认情况下每执行一条SQL，会自动commit。

下面我们通过peewee的源码分析一下

执行一条SQL最主要的入口可以从Database这个基类开始看

```python
class Database(_callable_context_manager):
    ...
    def execute_sql(self, sql, params=None, commit=SENTINEL):
        logger.debug((sql, params))
        if commit is SENTINEL:
            if self.in_transaction():
                commit = False
            elif self.commit_select:
                commit = True
            else:
                commit = not sql[:6].lower().startswith('select')

        with __exception_wrapper__:
            cursor = self.cursor(commit)
            try:
                cursor.execute(sql, params or ())
            except Exception:
                if self.autorollback and not self.in_transaction():
                    self.rollback()
                raise
            else:
                if commit and not self.in_transaction():
                    self.commit()
        return cursor
```

通过上面一段代码，我们可以得出以下结论

1. 有以下两种情况peewee不会帮我们自动commit
   1. 使用`db.atomic`等函数显式的开启一个事务
   2. commit_select为False(MySQLDatabase设置为True)，并且当前执行的SQL是以`select`开头的
2. 如果MySQL Server执行SQL时抛错(Duplicate/Deadlock/kingshard一些报错)，并且没有设置`autorollback`，则*当前事务不会提交*，这也是为什么如果插入一条数据失败，再使用当前连接执行一个shard到不同node的SQL，同样也会报`transaction in multi node`。

接着看到`cursor = self.cursor(commit)`这一行，这个函数内部调用了`_connect`方法，而这个方法是不同的派生类有不同的实现，我们以MySQL举例，实现代码如下

```python
mysql_passwd = False
try:
    import pymysql as mysql
except ImportError:
    try:
        import MySQLdb as mysql
        mysql_passwd = True
    except ImportError:
        mysql = None
...
def _connect(self):
    if mysql is None:
        raise ImproperlyConfigured('MySQL driver not installed!')
    return mysql.connect(db=self.database, **self.connect_params)
```

其实是使用的对应的包提供的方法，我们看一下pymsql的`connect`方法

```python
def Connect(*args, **kwargs):
    """
    Connect to the database; see connections.Connection.__init__() for
    more information.
    """
    from .connections import Connection
    return Connection(*args, **kwargs)
...
connect = Connection = Connect
...
class Connection(object):
    def __init__(self, ..., autocommit=False, ...):
        ...
        # specified autocommit mode. None means use server default.
        self.autocommit_mode = autocommit
        ...
        self.connect()

    def connect(self, sock=None):
        ...
        if self.autocommit_mode is not None:
            self.autocommit(self.autocommit_mode)
        ...

    def autocommit(self, value):
        self.autocommit_mode = bool(value)
        current = self.get_autocommit()
        if value != current:
            self._send_autocommit_mode()

    def _send_autocommit_mode(self):
        """Set whether or not to commit after every execute()"""
        self._execute_command(COMMAND.COM_QUERY, "SET AUTOCOMMIT = %s" %
                              self.escape(self.autocommit_mode))
        self._read_ok_packet()
```

终于找到了`SET AUTOCOMMIT=0`的来源了，由于peewee去除了autocommit参数，所以这段逻辑默认是一定会走到的。

### 确认

我们已经看过了源码，这里可以设置autocommit=1，以支持kingshard支持的一些跨node SQL

```python
In [1]: db.connect_params.update(autocommit=True)
In [2]: db.close()
Out[2]: True
In [3]: db.connect()
Out[3]: True
In [4]: UserInfo.bind(db)
Out[4]: False
In [5]: UserInfo.select(pw.fn.COUNT('*')).scalar()
Out[5]: 5
```

## 总结

kingshard报错`transaction in multi node`，有一个前提，就是当前session*显式的开启一个事务begin/start transaction*或者*设置了`autocommit=0`*。

peewee默认情况下做了如下操作

1. 设置session`autocommit = 0`
2. 不显式开启事务(`with db.atomic()`)的情况下，每条SQL*执行成功后*都会执行`commit`

MySQL的autocommit有如下机制

1. 如果开启，MySQL将在每个SQL语句执行成功之后执行提交；如果执行失败，到底是提交还是回滚[取决于error类型](https://dev.mysql.com/doc/refman/5.7/en/innodb-autocommit-commit-rollback.html)；如果想在一个事务下执行多条SQL，则需显式的begin/start transaction
2. 如果禁用，则会话始终会打开一个事务，COMMIT或ROLLBACK语句结束当前事务，并启动一个新的事务。如果禁用自动提交的会话在没有显式提交最终事务的情况下结束，MySQL将回滚该事务

综合以上结论，也就不难得出[复现](#%E5%A4%8D%E7%8E%B0)那一节种种报错的原因了。

那知道了原因，我们如何解决呢？

简单点处理的话，可以实现一个`PooledKingshardDatabase`类，继承`PooledMySQLDatabase`类，并重写`_connect`方法，传入`autocommit=True`，设置kingshard的autocommit，这样做使用起来是不会出什么问题的，因为

1. 常见的select是快照读，本来就不需要加锁，在不在事务下无所谓
2. 指定shard_key的update/delete操作，由kingshard计算发往指定node，kingshard会将指定后端数据库连接设置成`autocommit=1`，这样这条语句的执行逻辑与peewee并无差异。
   1. kingshard在和node建立连接时是根据MySQL在Response OK返回的Server Status判断对应的连接是否是autocommit，[对应代码](https://github.com/flike/kingshard/blob/master/backend/backend_conn.go#L183)
   2. 如果不是autocommit，kingshard会主动执行`set autocommit = 1`，[对应代码](https://github.com/flike/kingshard/blob/master/backend/backend_conn.go#L115)
   3. 不过这里mysql server有一个bug，即使启动时指定了`autocommit=0`，Server Status返回的autocommit对应位也是1，所以kingshard的机制在这里并不生效。[对应issue](https://bugs.mysql.com/bug.php?id=66884)，我自己抓包试了一下确实还是存在这个问题。所以还是使用server默认的autocommit=1这个配置吧。
3. 跨节点的select/update/delete/count/sum/orderby等操作都可以支持，不过count操作要重新实现以下。
4. 显式的开启事务逻辑与peewee的无异，只不过多了条限制就是不能跨node。