---
title: '零基础学习kubernetes(一): 基础知识'
copyright: false
date: 2018-09-11 12:00:12
photos:
- images/Kubernetes_logo.svg
tags:
- k8s
categories:
- kubernetes
---

Kubernetes是用于自动部署，扩展和管理容器化应用程序的开源系统。它将组成应用程序的容器组合成逻辑单元，以便于管理和服务发现。

本文介绍了如何使用[`minikube`](https://github.com/kubernetes/minikube)，在本机搭建一个k8s集群，并在其上部署应用程序，理解k8s基本的概念和操作。

<!-- more -->

## 使用minikube创建一个集群

### kubernetes集群

Kubernetes协调一个高度可用的计算机集群，这些计算机集群作为一个单元连接到一起工作。

Kubernetes集群由两种类型的资源组成:

1. `Master`协调集群
1. `Nodes`是运行应用程序的wokers

![](https://d33wubrfki0l68.cloudfront.net/99d9808dcbf2880a996ed50d308a186b5900cec9/40b94/docs/tutorials/kubernetes-basics/public/images/module_01_cluster.svg)

**主服务器负责管理集群**。主协调集群中的所有活动，例如调度应用程序、维护应用程序所需的状态、扩展应用程序和推出新更新。

**Node是作为Kubernetes集群中的工作机器的VM或物理计算机。**每个节点都有一个Kubelet，它是管理节点和与Kubernetes主机通信的代理。节点还应该有处理容器操作的工具，比如Docker或rkt。处理生产流量的Kubernetes集群至少应该有三个节点。

当在Kubernetes上部署应用程序时，主程序调度容器在集群的节点上运行。节点使用Kubernetes API与主节点通信，主节点公开了该API。最终用户还可以直接使用Kubernetes API与集群交互。

### cmd

1. install minikube
    - macOS: `brew cask install minikube`
    - Linux: `curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo cp minikube /usr/local/bin/ && rm minikube`
1. 启动集群: `minikube start`，minikube会在本地启动一个虚拟机，然后在虚拟机中运行k8s集群。
1. 查看集群信息: `kubectl cluster-info`
1. 查看所有节点: `kubectl get nodes`

## 使用`kubectl`创建发布应用

### k8s部署

有了k8s集群，我们就可以在其上部署容器化应用了。首先，需要创建一个Kubernetes部署配置。部署指示Kubernetes如何创建和更新应用程序实例。

一旦创建了应用程序实例，Kubernetes部署控制器就会持续监视这些实例。如果承载实例的节点宕机或被删除，部署控制器将替换它。这提供了一个自愈机制来处理机器故障。

![](https://d33wubrfki0l68.cloudfront.net/152c845f25df8e69dd24dd7b0836a289747e258a/4a1d2/docs/tutorials/kubernetes-basics/public/images/module_02_first_app.svg)

### cmd

通过`kubectl run`发布应用程序。我们需要提供发布的`name`和镜像地址(如果镜像不是来自docker hub，则需要完成的url链接)。

下面我们将部署一个Node.js服务

1. 发布应用: `kubectl run kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 --port=8080`。这个命令中，k8s帮我们干了三件事情:
    1. 搜索可以运行应用程序实例的合适Node
    1. 调度应用程序在该节点上运行
    1. 配置集群以在需要时在新节点上重新调度实例
1. 查看发布的应用: `kubectl get deployments`

## 查看Pods和Nodes

### Pods

在上一节中创建部署时，我们创建了一个Pod来托管应用程序实例。Pod是一个k8s抽象，它表示一组一个或多个应用程序容器(如Docker或rkt)，以及这些容器的一些共享资源。这些资源包括:

- 共享存储，作为卷
- 网络，作为唯一的集群IP地址
- 共享如何运行每个容器的信息，例如容器映像版本或要使用的特定端口

Pod对特定于应用程序的“逻辑主机”进行建模，并可以包含相对紧密耦合的不同应用程序容器。例如，Pod可能包含一个web服务容器，一个数据库服务容器，一个后端rpc服务容器。Pod中的容器共享一个IP地址和端口空间，它们总是一起定位和调度，并在同一个节点的共享上下文中运行。

Pods是k8s中的原子单位，每个Pod被绑定到预定的节点上，并一直保留到终止(根据重启策略)或删除。如果节点出现故障，则在集群中的其他可用节点上调度相同的pod。

![](https://d33wubrfki0l68.cloudfront.net/fe03f68d8ede9815184852ca2a4fd30325e5d15a/98064/docs/tutorials/kubernetes-basics/public/images/module_03_pods.svg)

### Nodes

一个Pod运行在一个Node上。Node可以是VM或者物理机器。每一个Node都由master管理。一个Node可以包含多个pods，并且master会自动地在集群中的节点上调度pod。master的调度调度考虑到每个节点上的可用资源。

每个Node至少运行了：

1. kubelet: 负责Kubernetes主机和节点之间通信的进程;它管理机器上运行的Pods和容器。
1. 一个容器运行时(如Docker, rkt)负责从注册表中提取容器映像，解包容器，并运行应用程序。如果容器是紧密耦合的，并且需要共享磁盘等资源，那么它们应该被安排在一个单独的Pod中。

![](https://d33wubrfki0l68.cloudfront.net/5cb72d407cbe2755e581b6de757e0d81760d5b86/a9df9/docs/tutorials/kubernetes-basics/public/images/module_03_nodes.svg)


### 使用常见的kubectl命令进行故障排除

- **kubectl get**: 获取指定资源的列表
- **kubectl describe**: 获取一个资源的详细信息
- **kubectl logs**: 打印一个pod的一个容器中的日志
- **kubectl exec**: 在一个pod的一个容器中执行命令

k8s的资源(resource)类型

- node
- pod
- deployment
- replicaset
- service
- daemonset
- secret
- role
- rolebinding

# 参考文章

https://kubernetes.io/docs/tutorials/