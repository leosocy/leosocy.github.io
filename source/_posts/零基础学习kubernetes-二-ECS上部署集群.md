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
- 各个组件如何安装
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

根据[官方文档](https://kubernetes.io/docs/setup/independent/install-kubeadm/)，准备k8s集群部署相关的软件、环境设置等。

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

# master/node 组件

# 安装、配置各个组件

# 启动引导集群
