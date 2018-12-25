---
title: 零基础学习kubernetes(四)：利用闲置主机搭建并暴露本地k8s集群
copyright: true
date: 2018-12-25 21:24:10
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/kubernetes_tutorials.png
tags:
- k8s cluster
- NAT
categories:
- kubernetes
---

前三章的学习，笔者经历了从使用ECS的k8s集群到本地的Minikube，说白了，还是穷，买不起高配置的ECS，而当资源(cpu/memory)不足时，要想充分发挥k8s的强大功能可以说是难上加难。

恰巧笔者有一台尘封已久的笔记本，很早之前折腾过一阵`archlinux`系统，如果我们能用它在内网搭建一个k8s集群，然后通过某种方式暴露在公网上供使用，是不是就很nice了呢？

如果你也有类似的烦恼，想利用闲置的主机搭建一个经济实惠的k8s集群，那么希望本篇文章能带给你一些帮助。下面我们就一步步完成这个伟(diao)大(si)的理想吧！

<!-- more -->

## 内网穿透，”免费“的ECS

对于没有公网IP的内网用户来说，远程管理或在外网访问内网机器上的服务是一个问题。通常解决方案就是用内网穿透工具将内网的服务穿透到公网中，便于远程管理和在外部访问。

[`FRP`](https://github.com/fatedier/frp) (Fast Reverse Proxy)，一个使用Go语言开发的高性能反向代理工具，可以通过简单的配置实现内网穿透。`FRP`支持TCP、UDP、HTTP、HTTPS等协议类型，并且支持Web服务根据域名进行路由转发。

### frps

frp的服务端，即我们的ECS服务器，可以将公网的请求(TCP/HTTP...)转发到内网上。

#### 安装

首先去frp的release页面查看最新的版本以及ECS处理器架构对应的安装包。

如何知道处理器架构，执行

```shell
uname -a
Linux izuf6bp8e6ra9rqb1vneypz 3.10.0-862.11.6.el7.x86_64 #1 SMP Tue Aug 14 21:49:04 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux
```

如果输出中含有*.x86_64则需要下载带`linux_amd64`的压缩包。

这里笔者选择的是`x86_64`架构，本文撰写时frp最新版本是`0.22.0`

```shell
wget https://github.com/fatedier/frp/releases/download/v0.22.0/frp_0.22.0_linux_amd64.tar.gz
tar -zxvf frp_0.22.0_linux_amd64.tar.gz
cd frp_0.22.0_linux_amd64/
```

尝试运行frps

```
./frps --help
```

正常情况下会输出一堆帮助信息，说明你下载了正确架构的版本，反之如果输出`Exec format error`，就说明版本下载错了。

拷贝可执行文件以及配置文件

```shell
cp frps /usr/bin
mkdir -p ~/.frp
cp frps_full.ini ~/.frp
```

#### 配置

下面的配置仅为作者使用到的一些基本配置及说明，如需研究完整配置说明请看`~/.frp/frps_full.ini`，以及参考[frp官方文档](https://github.com/fatedier/frp/blob/master/README_zh.md)

```toml
# 下面这句开头必须要有，表示配置的开始
[common]

# frp 服务端端口（必须）
bind_port = 7000

# frp 服务端密码（必须）
token = xxxxxx

# 仪表盘端口，只有设置了才能使用仪表盘（即后台）
dashboard_port = 7500

# 仪表盘访问的用户名密码，如果不设置，则默认都是 admin
dashboard_user = admin
dashboard_pwd = admin

# 如果你想要用 frp 穿透访问内网中的网站（例如路由器设置页面）
# 则必须要设置以下两个监听端口，不设置则不会开启这项功能
vhost_http_port = 80
vhost_https_port = 443

# 此设置需要配合客户端设置，仅在穿透到内网中的 http 或 https 时有用（可选）
# 假设此项设置为 example.com，客户端配置 http 时将 subdomain 设置为 test，
# 则你将 test.example.com 解析到服务端后，可以使用此域名来访问客户端对应的 http
subdomain_host = example.com
```

将上述配置写入`~/.frp/frps.ini`中，然后执行

```shell
frps -c ~/.frp/frps.ini
```

如果没有出现错误提示就说明配置没有问题，可以正常使用

然后`Ctrl + C`终止进程

#### 启动

直接使用前面的命令行来运行是不行的，因为在关掉ssh窗口后程序frps就会停止运行，因此要使用nohup [command] &这种操作来使其在后台运行

```shell
nohup frps -c ~/.frp/frps.ini &
```

如果想停止，可以执行`pkill frps`

*加入开机自启动*

编辑`/etc/rc.local`，将启动那句命令加到`exit 0`语句之前（如果有）

### frpc

frp的客户端，即为内网机器，接收frpc转发的请求，并作出响应。

#### 安装

同frps的安装，不过要注意此处需要下载内网机器处理器架构对应的压缩包。

#### 配置

下面的配置仅为作者使用到的一些基本配置及说明，如需研究完整配置说明请看`~/.frp/frpc_full.ini`，以及参考[frp官方文档](https://github.com/fatedier/frp/blob/master/README_zh.md)

*基本配置*

```toml
# frp 服务端地址，可以填ip或者域名
server_addr = 0.0.0.0
# frp 服务端端口，即填写服务端配置中的 bind_port
server_port = 7000
# 填写 frp 服务端密码
token = 12345678
```

*TCP/UDP*

以转发ssh为例

```toml
# 自定义一个配置名称，格式为“[名称]”，放在开头
[ssh]
# 连接类型，填 tcp 或 udp
type = tcp

# 本地ip，填你需要转发到的目的ip
# 如果是转发到frp客户端所在本机（比如路由器）则填 127.0.0.1
# 否则填对应机器的内网ip
local_ip = 127.0.0.1
# 需要转发到的端口，比如 ssh 端口是 22
local_port = 22
```

*HTTP/HTTPS*

```toml
# 自定义一个配置名称，格式为“[名称]”，放在开头
[router-web]
# 连接类型，填 http 或 https
type = http

local_ip = 127.0.0.1
local_port = 80

# http 可以考虑加密和压缩一下
use_encryption = true
use_compression = true

# 自定义访问网站的用户名和密码，如果不定义的话谁都可以访问，会不安全
# 有些路由器如果从内部访问web是不需要用户名密码的，因此需要在这里加一层密码保护
# 如果你发现不加这个密码保护，路由器配置页面原本的用户认证能正常生效的话，可以不加
http_user = admin
http_pwd = admin

# 还记得我们在服务端配置的 subdomain_host = example.com 吗
# 假设这里我们填 web01，那么你将 web01.example.com 解析到服务端ip后
# 你就可以使用 域名:端口 来访问你的 http 了
# 这个域名的作用是用来区分不同的 http，因为你可以配置多个这样的配置
subdomain = web01

# 自定义域名，这个不同于 subdomain，你可以设置与 subdomain_host 无关的其他域名
# subdomain 与 custom_domains 中至少有一个必须要设置
custom_domains = web02.yourdomain.com

# 匹配路径，可以设置多个，用逗号分隔，比如你设置 locations 为以下这个，
# 那么所有 http://xxx/abc 和 http://xxx/def 都会被转发到 http://xxx/
# 如果不需要这个功能可以不写这项，就直接该怎么访问就怎么访问
locations = /abc,/def
```

#### 启动

根据你的需求，将配置写入`~/.frp/frpc.ini`中，并执行

```shell
nohup frpc -c ~/.frp/frpc.ini &
```

### 效果

这是笔者frpc部分配置

```toml
[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 10022
[k8s-router]
type = https
local_ip = 127.0.0.1
local_port = 6443
subdomain = k8s-pro
```

此时随意找一台机器试一试能不能通过ECS的ip地址+`10022`这个端口ssh到内网的机器上

```shell
ssh xxx@xx.xx.xx -p 10022
```

如果提示需要输入密码，则表示配置生效，可以通过公网地址链接到内网机器上。

> PS: k8s的https路由我们会在下面使用到。

## 使用kubeadm在本地搭建cluster

### 安装kubelet、kubeadm

### 启动集群

### 使用kubectl在公网上操作内网cluster

### 效果

## 使用效果

## 参考文章

https://lolico.moe/tutorial/frp.html
