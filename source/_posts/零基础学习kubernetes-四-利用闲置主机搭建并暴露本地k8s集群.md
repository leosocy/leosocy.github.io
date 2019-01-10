---
title: '零基础学习kubernetes(四): 利用闲置主机搭建并暴露本地k8s集群'
copyright: true
date: 2018-12-25 21:24:10
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/kubernetes_tutorials.png
tags:
- k8s
- NAT
categories:
- kubernetes
---

前三章的学习，笔者经历了从使用ECS的k8s集群到本地的Minikube，说白了，还是穷，买不起高配置的ECS，而当资源(cpu/memory)不足时，要想充分发挥k8s的强大功能可以说是难上加难。

恰巧笔者有一台尘封已久的笔记本，很早之前折腾过一阵`archlinux`系统，如果我们能用它在内网搭建一个k8s集群，然后通过某种方式暴露在公网上供使用，是不是就很nice了呢？

如果你也有类似的烦恼，想利用闲置的主机搭建一个经济实惠的k8s集群，那么希望本篇文章能带给你一些帮助。下面我们就一步步完成这个伟(diao)大(si)的理想吧！

<!-- more -->

## 内网穿透，”免费“的ECS

对于没有公网IP的内网用户来说，远程管理或在外网访问内网机器上的服务是一个问题。通常解决方案就是用内网穿透工具将内网的服务穿透到公网中，便于远程管理和在外部访问。

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

*基本配置*

- 安装docker
- 关闭swap
- 关闭SELinux
- 确认cgroup drive

以上具体配置可以参考[零基础学习 kubernetes(二): 在 ECS 上部署集群](./零基础学习kubernetes-二-ECS上部署集群.md)

### 安装kubelet、kubeadm、kubectl

您需要在每台机器上都安装以下的软件包：

- `kubeadm`: 用来初始化集群的指令
- `kubelet`: 在集群中的每个节点上用来启动pod和container等
- `kubectl`: 用来与集群通信的命令行工具

*安装CNI插件*

```shell
CNI_VERSION="v0.6.0"
mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz
```

*安装crictl(kubeadm/Kubelet的容器运行时接口(CRI)要求)*

```shell
CRICTL_VERSION="v1.11.1"
mkdir -p /opt/bin
curl -L "https://github.com/kubernetes-incubator/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | tar -C /opt/bin -xz
```

*安装`kubeadm`,`kubelet`,`kubectl`并且添加一个`kubelet`systemd服务*

```shell
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"

mkdir -p /opt/bin
cd /opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

*启用并启动`kubelet`*

```shell
systemctl enable kubelet && systemctl start kubelet
```

kubelet 现在每隔几秒就会重启，因为它陷入了一个等待 kubeadm 指令的死循环。

### 启动集群

```
kubeadm init --kubernetes-version=v1.13.1 --image-repository=bluenet13 --apiserver-advertise-address=0.0.0.0 --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans=k8s-pro.leosocy.top
```

*Options*

- `--kubernetes-version`: 截止笔者撰写此博客时，最新的stable版本为1.13.1
- `--image-repository`: 配置指定的docker registry，避免默认的`k8s.gcr.io`由于被墙导致的镜像拉取失败
- `--apiserver-advertise-address`: 指定“0.0.0.0”来使用默认网络接口的地址
- `--apiserver-cert-extra-sans`: 用于apiserver服务证书的可选额外SANs，可以是IP地址和DNS名称。还记得我们在上面配置的frpc的`k8s-router`的https路由规则，以笔者的配置为例，当外网用户配置好了`kubectl`的cluster、签名用户、以及context后，请求操作apiserver `https://k8s-pro.leosocy.top`时，阿里云DNS解析首先将请求根据域名解析到配置的ECS公网IP上，然后frps根据客户端配置，将请求路由到指定的内网端口上(即内网k8s apiserver)，apiserver根据Host判断是否在证书的SANs中，如果在则执行响应操作并响应。所以外界根本感知不到是在操作一个内网的k8s集群
- `--pod-network-cidr`: 选择pod网络对应的cidr(笔者这里选择的是flannel)

稍等几分钟之后，cluster master就安装成功了，启动成功之后还要创建pod网络、设置工作节点等等，具体可以参考[零基础学习kubernetes(二): 在ECS上部署集群](./零基础学习kubernetes-二-ECS上部署集群.md)

### 使用kubectl在公网上操作内网cluster

上面我们已经成功的在内网搭建了一个k8s集群(虽然只有一个master节点)，现在如果我们想通过公网的ip/域名操作这个集群该怎么办呢？

#### 创建用户凭证

集群启动后，k8s帮我们创建了一个master账号，拥有操作集群的超级权限，很显然如果想在外部网络操作集群，是不可能配置这个账号的。所以，我们要按需创建用户账号(即RBAC)，并赋予相关权限。

1. 为用户创建私钥。在这个例子中，我们将命名文件`employee.key`:
    ```shell
    openssl genrsa -out employee.key 2048
    ```
1. 创建证书签名请求`employee.csr`使用刚刚创建的私钥`employee.key`。确保在`-subj`部分中指定了用户名(CN是用户名)
    ```shell
    openssl req -new -key employee.key -out employee.csr -subj "/CN=employee"
    ```
1. 使用集群证书颁发机构(CA)给employee.csr签发证书，ca根证书一般在集群master的`/etc/kubernetes/pki/`下
    ```shell
    openssl x509 -req -in employee.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out employee.crt -days 3650
    ```
1. 将`ca.crt`, `employee.key`, `employee.crt`保存到需要操作集群的机器上(例如你的ECS)的一个目录下，例如`~/.kube/crts`
1. 设置cluster、credentials以及context
    ```shell
    k config set-cluster `your-cluster-name` --server=`your-cluster-domain` --certificate-authority=~/.kube/crts/cluster/ca.key
    k config set-credentials employee --client-certificate=~/.kube/crts/user/employee.crt --client-key=~/.kube/crts/user/employee.key
    k config set-context employee-context --cluster=`your-cluster-name` --user=employee
    ```

现在，在使用带有此配置文件的kubectl CLI时，应该会出现访问拒绝错误。这是预期的，因为我们还没有为该用户定义任何允许的操作。

#### 根据需求创建RoleBinding/ClusterRoleBinding

1. 创建一个名为`office`的命名空间
    ```shell
    k create ns office
    ```

1. 创建一个`role-deployment-manager.yml`文件包含以下内容。在这个yaml文件中，我们创建了一个规则，允许用户在`Deployment`、`Pod`和`ReplicaSets`(创建Deployment所必需的)上执行一些操作，这些操作属于核心(在yaml文件中以“”表示)、应用程序和扩展API组:
    ```yaml
    kind: Role
    apiVersion: rbac.authorization.k8s.io/v1beta1
    metadata:
    namespace: office
    name: deployment-manager
    rules:
    - apiGroups: ["", "extensions", "apps"]
    resources: ["deployments", "replicasets", "pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
    ```
    ```shell
    k apply -f role-deployment-manager.yml
    ```

1. 绑定角色到employee用户，创建一个`rolebinding-deployment-manager.yml`文件包含以下内容。在这个文件中，我们将`deployment-manager`角色绑定到office名称空间中的用户帐户employee:
    ```yaml
    kind: RoleBinding
    apiVersion: rbac.authorization.k8s.io/v1beta1
    metadata:
      name: deployment-manager-binding
      namespace: office
    subjects:
    - kind: User
      name: employee
      apiGroup: ""
    roleRef:
      kind: Role
      name: deployment-manager
      apiGroup: ""
    ```
    ```shell
    k apply -f rolebinding-deployment-manager.yaml
    ```

1. 测试RBAC角色，可以看到employee用户已经有了相应的操作资源的权限了
    ```shell
    k config use-context employee-context   # 切换context
    k run --image nginx mynginx
    ```

### 效果

搭建一个nginx service试试

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: office
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: office
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  type: ClusterIP
  clusterIP: None
```

然后`port-forward`将服务的端口映射到本地端口

```shell
k port-forward svc/nginx-service 8080:80
```

curl下看看

```shell
curl localhost:8080
```

可以看到如下输出

```txt
...
Welcome to nginx!
If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.
...
```

## 使用效果

通过上面的一顿操作，我们在内网的机器上部署了k8s集群，然后通过`frp`工具，将来自外网的请求通过具有公网ip的ECS转发到了内网，从而实现了调用内网k8s apiserver。

现在你就可以丢掉资源受限的ECS k8s了，将家里闲置的笔记本电脑(例如笔者已经服役五年依旧坚挺的Dell)重新利用起来，搭建一个真正意义上的k8s集群，并在其上部署/监控你的应用吧！

## What's next?

部署Ingress，让外部请求(HTTP/HTTPS)通过ECS上的frps转发到内网的指定端口，同时Ingress根据host、path等，将请求路由到对应的svc，然后通过kube-proxy负载均衡到后端Pod中。

## 参考文章

https://lolico.moe/tutorial/frp.html
https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/
