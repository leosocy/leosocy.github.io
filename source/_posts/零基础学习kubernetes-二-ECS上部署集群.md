---
title: '零基础学习kubernetes(二): 在ECS上部署集群'
copyright: false
date: 2018-09-22 02:02:30
photos:
- images/Kubernetes_logo.svg
tags:
- k8s
categories:
- kubernetes
---

kubernetes官网提供了不同场景下的集群搭建解决方案，包括本地/托管方案等等。如果你的集群是基于单节点搭建，可以选择[Minikube](https://kubernetes.io/docs/setup/minikube/)/[Kubeadm-dind](https://github.com/kubernetes-sigs/kubeadm-dind-cluster)等.

尽管这些现成的解决方案可以帮助你很快的在本地搭建一个k8s集群。但是为了更深入了解k8s集群的组成、原理，本篇文章笔者会从头开始创建自定义集群。阅读完本篇文章，你将会学到：

- 集群master节点和node节点包含的主要组件
- 各个组件的用途
- 如何引导启动集群

<!-- more -->

# 准备

## 笔者的环境

- 1 ECS(1vCPU+2GRAM, OS:CentOS 7)

## 基础环境

### 配置yum源

默认的yum源在安装软件时往往会非常慢甚至超时，所以这里我们使用阿里云的yum源

```shell
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum makecache
```

### 安装docker

因为CentOS7自带的docker版本可能过低，所以需要重新安装docker

卸载原有docker

```shell
sudo yum remove docker  docker-common docker-selinux docker-engine
```

添加仓库

```shell
sudo wget -O /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache
```

安装docker

```shell
sudo yum install docker-ce -y
```

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180925232655.png)

运行`docker --version`查看docker版本

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180925232755.png)

启动docker并设置开机启动

```shell
sudo systemctl start docker && sudo systemctl enable docker
```

验证安装成功

```shell
docker run hello-world
```

有如下输出表示安装docker成功

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180925233635.png)

### 关闭swap

kubelet要求必须关闭内存交换，执行`swapoff -a`可以临时关闭，重启失效；编辑`/etc/fstab`，注释掉`swap`哪一行，重启可以永久关闭。

```shell
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=20ca01ff-c5eb-47bc-99a0-6527b8cb246e /boot                   xfs     defaults        0 0
# /dev/mapper/centos-swap swap
```

`htop`验证是否关闭成功

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180926000333.png)

## k8s相关环境

根据[官方文档](https://kubernetes.io/docs/setup/independent/install-kubeadm/)，准备k8s集群部署相关的软件、环境设置等。

### 关闭SELinux

```shell
sudo setenforce 0
```

通过运行`setenforce 0`来禁用SELinux来允许容器访问主机文件系统，这是pod网络所需要的。

### 配置k8s的yum源

由于官方yum源在天朝无法使用，所以这里我们还是使用阿里云的k8s源

```shell
sudo vim /etc/yum.repos.d/kubernetes.repo

加入如下内容

[kubernetes]

name=Kubernetes

baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64

enabled=1

gpgcheck=0

repo_gpgcheck=0

gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg

        http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
```

### 安装k8s组件

```shell
sudo yum install -y kubelet kubeadm kubectl
```

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180926002139.png)

开机启动

```shell
sudo systemctl enable kubelet && sudo systemctl start kubelet
```

### 配置kubelet使用的cgroup drive

查看docker的cgroup driver

```shell
docker info | grep 'Cgroup Driver'
```

如果**不是**`cgroupfs`，而是`systemd`，需要更改`kubelet`配置，在`/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`文件中加入

```shell
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"

sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

### 修改kubeadm使用的默认镜像仓储

由于执行`kubeadm init`会默认访问谷歌服务器，所以会出现失败的情况，这里我们需要将kubeadm使用的默认docker镜像从另外的仓库中全部下载下来，然后批量打标签成需要的镜像名。

> 参考：[Google Container Registry(gcr.io) 中国可用镜像(长期维护)](https://anjia0532.github.io/2017/11/15/gcr-io-image-mirror/)

在执行`kubeadm init`时，会报错

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180927002610.png)

我们将需要下载的镜像记录到`img.txt`中

```txt
k8s.gcr.io/kube-apiserver-amd64:v1.11.0
k8s.gcr.io/kube-controller-manager-amd64:v1.11.0
k8s.gcr.io/kube-scheduler-amd64:v1.11.0
k8s.gcr.io/kube-proxy-amd64:v1.11.0
k8s.gcr.io/etcd-amd64:3.2.18
k8s.gcr.io/coredns:1.1.3
```

创建批量下载并打标签镜像的脚本`batch_get_images.sh`

```bash
# replace gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 to real image
# this will convert gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# to anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 and pull it
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.{image}/{tag}

images=$(cat img.txt)
#or
#images=$(cat <<EOF
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
#EOF
#)

eval $(echo ${images}|
        sed 's/k8s\.gcr\.io/anjia0532\/google-containers/g;s/gcr\.io/anjia0532/g;s/\//\./g;s/ /\n/g;s/anjia0532\./anjia0532\//g' |
        uniq |
        awk '{print "docker pull "$1";"}'
       )

# this code will retag all of anjia0532's image from local  e.g. anjia0532/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1
# to gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
# k8s.gcr.io/{image}/{tag} <==> gcr.io/google-containers/{image}/{tag} <==> anjia0532/google-containers.{image}/{tag}

for img in $(docker images --format "{{.Repository}}:{{.Tag}}"| grep "anjia0532"); do
    n=$(echo ${img}| awk -F'[/.:]' '{printf "gcr.io/%s",$2}')
    image=$(echo ${img}| awk -F'[/.:]' '{printf "/%s",$3}')
    tag=$(echo ${img}| awk -F'[:]' '{printf ":%s",$2}')
    docker tag $img "${n}${image}${tag}"
    [[ ${n} == "gcr.io/google-containers"  ]] && docker tag $img "k8s.gcr.io${image}${tag}"
done
```

执行如下命令

```shell
chmod u+x batch_get_images.sh
./batch_get_images.sh
```

会下载`img.txt`中的镜像，成功后可以看到，`kubeadm init`需要的镜像已经全部下载并打标签成`gcr.io/*`

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180927022744.png)

# master/node 组件

## kube-master「控制节点」

kube master主要包含以下组件

- api server
- scheduler
- controller manager

各个组件之间的工作配合方式如下

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/kube-master.png)

1. Kubecfg将特定的请求，比如创建Pod，发送给Kubernetes Client。
1. Kubernetes Client将请求发送给API server。
1. API Server根据请求的类型，比如创建Pod时storage类型是pods，然后依此选择何种REST Storage API对请求作出处理。
1. REST Storage API对的请求作相应的处理。
1. 将处理的结果存入高可用键值存储系统Etcd中。
1. 在API Server响应Kubecfg的请求后，Scheduler会根据Kubernetes Client获取集群中运行Pod及Minion/Node信息。
1. 依据从Kubernetes Client获取的信息，Scheduler将未分发的Pod分发到可用的Minion/Node节点上。

### api server

`api server`是资源操作的唯一入口，所有其他的组件如果相对集群资源进行操作都必须通过`api server`。

功能：

1. 提供了集群管理的REST API接口(包括认证授权、数据校验以及集群状态变更)
1. 提供其他模块之间的数据交互和通信的枢纽(其他模块通过API Server查询或修改数据，只有API Server才直接操作etcd)
1. 资源配额控制的入口

工作原理图

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/kube-apiserver.png)

### controller manager

Controller Manager作为集群内部的管理控制中心，负责集群内的Node、Pod副本、服务端点（Endpoint）、命名空间（Namespace）、服务账号（ServiceAccount）、资源定额（ResourceQuota）的管理，当某个Node意外宕机时，Controller Manager会及时发现并执行自动化修复流程，确保集群始终处于预期的工作状态。

[Controller Manager详解](https://www.huweihuang.com/article/kubernetes/core-principle/kubernetes-core-principle-controller-manager/)

### scheduler

Scheduler负责Pod调度。在整个系统中起"承上启下"作用，承上：负责接收Controller Manager创建的新的Pod，为其选择一个合适的Node；启下：Node上的kubelet接管Pod的生命周期。

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/kube-scheduler.png)

## kube-node「服务节点」

结构图

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/kube-node.png)

### kubelet

在kubernetes集群中，每个Node节点都会启动kubelet进程，用来处理Master节点下发到本节点的任务，管理Pod和其中的容器。kubelet会在API Server上注册节点信息，定期向Master汇报节点资源使用情况，并通过cAdvisor监控容器和节点资源。可以把kubelet理解成【Server-Agent】架构中的agent，是Node上的pod管家。

功能

1. 负责Node节点上pod的创建、修改、监控、删除等全生命周期的管理
1. 定时上报本Node的状态信息给API Server
1. kubelet是Master API Server和Minion/Node之间的桥梁，接收Master API Server分配给它的commands和work，通过kube-apiserver间接与Etcd集群交互，读取配置信息

### proxy

Proxy是为了解决外部网络能够访问集群中容器提供的应用服务而设计的，Proxy 运行在每个Node上。

Proxy提供TCP/UDP两种Sockets连接方式。每创建一个Service，Proxy就会从Etcd获取Services和Endpoints的配置信息（也可以从 File 获取），然后根据其配置信息在Node上启动一个Proxy的进程并监听相应的服务端口。当外部请求发生时，Proxy会根据`Load Balancer`将请求分发到后端正确的容器处理。

# 启动引导集群

在第一节，我们准备了运行`kubeadm init`之前的一些环境、软件，第二节中，介绍了k8s集群的基本组件，帮助我们理解了集群中的基本组件。

下面我们将使用`kubeadm`来创建并引导一个集群。

## 创建集群

执行

```shell
sudo kubeadm init  --kubernetes-version=v1.11.0 --apiserver-advertise-address=your_master_node_ip --pod-network-cidr=10.244.0.0/16
```

各个参数的含义:

- kubernetes-version: 指定k8s版本，必须与之前导入的镜像版本一致，不然又会去谷歌下载需要的镜像
- apiserver-advertise-address: 指定api server监听的ip地址，这里笔者填的是ECS的外网地址
- pod-network-cidr: 根据`https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/`，官方提供了很多可以选择的节点网络类型，这里笔者填写`10.244.0.0/16`表示使用`flannel`网络，同时需要执行`sudo sysctl net.bridge.bridge-nf-call-iptables=1`。

执行成功结果

```shell
[init] using Kubernetes version: v1.11.0
[preflight] running pre-flight checks
I0927 23:50:58.769986   27134 kernel_validator.go:81] Validating kernel version
I0927 23:50:58.770090   27134 kernel_validator.go:96] Validating kernel config
        [WARNING SystemVerification]: docker version is greater than the most recently validated version. Docker version: 18.06.1-ce. Max validated version: 17.03
[preflight/images] Pulling images required for setting up a Kubernetes cluster
[preflight/images] This might take a minute or two, depending on the speed of your internet connection
[preflight/images] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[preflight] Activating the kubelet service
[certificates] Generated ca certificate and key.
[certificates] Generated apiserver certificate and key.
[certificates] apiserver serving cert is signed for DNS names [leosocy-ecs1 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 101.xx.xx.124]
[certificates] Generated apiserver-kubelet-client certificate and key.
[certificates] Generated sa key and public key.
[certificates] Generated front-proxy-ca certificate and key.
[certificates] Generated front-proxy-client certificate and key.
[certificates] Generated etcd/ca certificate and key.
[certificates] Generated etcd/server certificate and key.
[certificates] etcd/server serving cert is signed for DNS names [leosocy-ecs1 localhost] and IPs [127.0.0.1 ::1]
[certificates] Generated etcd/peer certificate and key.
[certificates] etcd/peer serving cert is signed for DNS names [leosocy-ecs1 localhost] and IPs [101.xx.xx.124 127.0.0.1 ::1]
[certificates] Generated etcd/healthcheck-client certificate and key.
[certificates] Generated apiserver-etcd-client certificate and key.
[certificates] valid certificates and keys now exist in "/etc/kubernetes/pki"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/admin.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/kubelet.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/controller-manager.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/scheduler.conf"
[controlplane] wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
[controlplane] wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
[controlplane] wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
[etcd] Wrote Static Pod manifest for a local etcd instance to "/etc/kubernetes/manifests/etcd.yaml"
[init] waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests"
[init] this might take a minute or longer if the control plane images have to be pulled
[apiclient] All control plane components are healthy after 45.005438 seconds
[uploadconfig] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.11" in namespace kube-system with the configuration for the kubelets in the cluster
[markmaster] Marking the node leosocy-ecs1 as master by adding the label "node-role.kubernetes.io/master=''"
[markmaster] Marking the node leosocy-ecs1 as master by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[patchnode] Uploading the CRI Socket information "/var/run/dockershim.sock" to the Node API object "leosocy-ecs1" as an annotation
[bootstraptoken] using token: 3yl852.cgnsfybbkj01qtbp
[bootstraptoken] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstraptoken] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstraptoken] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstraptoken] creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 101.xx.xx.124:6443 --token 3yl852.cgnsfybbkj01qtbp --discovery-token-ca-cert-hash sha256:7e4636f999545ccd6468d913565341b22e228922acc999dba825726f710e45a5
```

这里有一个大坑，由于笔者用的是阿里云的ECS，又没有配置入方向的安全组，导致`6443端口`无法访问，一致卡在`[init] this might take a minute or longer if the control plane images have to be pulled`这个阶段。解决办法就是去阿里云控制台，配置ECS的6443端口安全组。

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180927020134.png)

## 创建kubectl config

如果本机之前没有其他k8s集群的配置，既`$HOME/.kube/config`不存在，则执行如下命令:

```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

如果本机还有其他集群的配置，则需要合并/etc/kubernetes/admin.conf到现有配置上，执行如下命令:

```shell
export KUBECONFIG=$HOME/.kube/config:/etc/kubernetes/admin.conf
sudo chown $(id -u):$(id -g) /etc/kubernetes/admin.conf
kubectl config view --flatten > $HOME/.kube/config_new
mv $HOME/.kube/config_new $HOME/.kube/config    # 覆盖旧的配置
export KUBECONFIG=~/.kube/config        # 恢复配置
```

## 配置pod网络

根据`kubeadm init`配置选择的网络类型，创建对应的网络pod，笔者选用的是`flannel`，根据[官网](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/)配置，执行

```shell
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/c5d10c8/Documentation/kube-flannel.yml
```

指定`k get po -n kube-system`，查看运行的pod如下

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180928003155.png)

可以看到，master需要的组件都已经启动成功了

## 集群设置

### 设置master为工作节点

scheduler默认不会将pod调度到master上，可以执行如下操作将master设置成工作节点

```shell
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## 发布一个应用试一试

基于yaml文件创建一个发布

```shell
kubectl apply -f https://k8s.io/examples/application/deployment.yamlk
```

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180928005347.png)

# 总结

本篇介绍了如何基于单节点搭建一个k8s集群，并介绍了master/node的基本组件。

下一篇，我们将会一起学习一些k8s中的名词解释。

# 参考文章

https://www.jianshu.com/p/78a5afd0c597
https://www.huweihuang.com/article/kubernetes/kubernetes-architecture/
https://juejin.im/post/5b63f4506fb9a04f8856f340
