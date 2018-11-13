---
title: '零基础学习kubernetes(三): 资源对象'
copyright: false
date: 2018-11-12 22:34:07
tags:
- k8s
categories:
- kubernetes
---

在学习使用k8s的过程中，我们不免看到许许多多的名词，包括`deploy`、`svc`、`rc`等等，它们通常代表着k8s中不同的资源对象。本文会介绍这些名词，同时会给出部署的yml文件，供实战部署，加深对这些名词的理解。

<!-- more -->

## Pods

### Pod的特征

- 可以直接通过localhost通信
- 共享Volume
- 直接创建的Pod是与Node绑定的，异常退出后不会被重新调度。因此推荐使用Deployment、Daemonset等控制器来容错
- 优雅终止，Pod删除的时候先给其内的进程发送`SIGTERM`(Unlike SIGKILL, this signal can be blocked, handled, and ignored. It is the normal way to politely ask a program to terminate.)，等待一段时间后才会强制停止依然还在运行的进程。

### Pod定义

一个nginx Pod的yaml配置

```yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
    tier: ingress
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
```

> 在生产环境中建议不要直接部署Pod，原因上面已经阐述。

### 使用Volume持久化数据

Volume可以为容器提供持久化存储，比如

```yml
apiVersion: v1
kind: Pod
metadata:
  name: redis
spec:
  containers:
  - name: redis
    image: redis
    volumeMounts:
    - name: redis-storage
      mountPath: /data/redis
  volumes:
  - name: redis-storage
    emptyDir: {}
```

### RestartPolicy

- Always: 只要Pod退出就重启
- OnFailure: Pod异常退出(exit code != 0)时重启
- Never: 退出后不重启

Tips: 重启只会在所在的Node上本地重启，不会重新调度到别的Node

### ImagePullPolicy

- Always: 不管镜像是否存在都会进行一次拉取
- Never: 不贵镜像是否存在都不会进行拉取
- IfNotPresent: 只有镜像不存在时，才会进行镜像拉取

Tips:
  - 默认为`IfNotPresent`，但`:latest`标签的镜像默认为`Always`
  - 拉取竟像是docker会进行校验，如果镜像中的MD5码没有变，则不会拉取镜像数据
  - 生产环境中应该尽量避免使用`:latest`标签，而开发环境中可以借助`:latest`标签自动拉取最新的镜像

### 资源限制

k8s通过`cgroups`限制容器的CPU和内存等计算资源，包括`requests`(请求，调度器保证调度到资源充足的`Node`上，如果无法满足会调度失败)和`limits`(上限)等:
  - `spec.containers[].resources.limits.cpu`: CPU上限，可以短暂超过，容器也不会被停止
  - `spec.containers[].resources.limits.memory`: 内存上限，不可以超过，如果超过，容器可能会被终止或调度到其他资源充足的机器上
  - `spec.containers[].resources.limits.ephemeral-storage`: 临时存储（容器可写层、日志以及EmptyDir等）的上限，超过后Pod会被驱逐
  - `spec.containers[].resources.requests.cpu`: CPU请求，也是调度CPU资源的依据，可以超过
  - `spec.containers[].resources.requests.memory`: 内存请求，也是调度内存资源的一句，可以超过；但是如果超过，容器可能会在Node内存不足时清理
  - `spec.containers[].resources.requests.ephemeral-storage`: 临时存储（容器可写层、日志以及EmptyDir等）的请求，调度容器存储的依据

比如nginx容器请求30%的CPU和56MB的内存，但限制最多只能使用50%的CPU和128MB的内存：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
    tier: ingress
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: 300m
        memory: 56Mi
      limits:
        cpu: 1
        memory: 128Mi
    ports:
    - containerPort: 80
```

Tips:
  - CPU的单位是CPU个数，可以用`millicpu(m)`表示少于1个CPU的情况，例如`500m = 500millicpu = 0.5cpu`
  - 内存的单位包括`E, P, T, G, M, K, Ei, Pi, Ti, Gi, Mi, Ki`等

### 健康检查

为了确保容器在部署后确实处在正常的运行状态，k8s提供了两种探针（Probe）来探测容器的状态：
  - LivenessProbe: 探测应用是否处于健康状态，如果不健康则删除并重新创建容器
  - ReadinessProbe: 探测应用是否启动完成并且处于正常服务状态，如果不正常则不会接收来自k8s的流量

k8s支持三种方式来执行探针：
  - exec: 在容器中执行一个命令，如果命令退出码返回0则表示探测成功，否则失败
  - tcpSocket: 对指定的容器IP及端口执行一个TCP检查，如果端口是开放的则表示探测成功，否则表示失败
  - httpGet: 对指定的容器IP、端口及路径执行一个HTTP Get请求，如果返回的状态码在`[200,400)`之间则表示探测成功，否则表示失败

## Deployment

## Services

## Replication Controller

## ReplicaSets

## DaemonSet

## StatefulSet

## CronJob

## Job

## Node

## Namespace

## Resource Quotas

## Volumes

## PV/PVC/StorageClass

## Secret

## Service Account

## Security Context

## Network Policy

## Ingress

## ThirdpartyResources

## ConfigMap

## PodPreset
