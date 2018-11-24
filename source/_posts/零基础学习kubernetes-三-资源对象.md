---
title: '零基础学习kubernetes(三): 资源对象'
copyright: false
date: 2018-11-12 22:34:07
tags:
- k8s
categories:
- kubernetes
---

在学习使用k8s的过程中，我们不免看到许许多多的名词，包括`deploy`、`svc`、`rs`等等，它们通常代表着k8s中不同的资源对象。本文会介绍这些资源，同时会给出部署的yml文件，供实战部署，加深对这些名词的理解。

<!-- more -->

## Autoscaling

Horizontal Pod Autoscaling (HPA) 可以根据 CPU 使用率或应用自定义 metrics 自动扩展 Pod 数量（支持 replication controller、deployment 和 replica set ）。
- 控制管理器每隔 30s（可以通过 --horizontal-pod-autoscaler-sync-period 修改）查询 metrics 的资源使用情况
- 支持三种 metrics 类型
  - 预定义 metrics（比如 Pod 的 CPU）以利用率的方式计算
  - 自定义的 Pod metrics，以原始值（raw value）的方式计算
  - 自定义的 object metrics
- 支持两种 metrics 查询方式：Heapster 和自定义的 REST API
- 支持多 metrics

## ConfigMap

ConfigMap 用于保存配置数据的键值对，可以用来保存单个属性，也可以用来保存配置文件。ConfigMap 跟 secret 很类似，但它可以更方便地处理不包含敏感信息的字符串。

### 从yaml文件创建

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
  namespace: default
data:
  env: "testing"
  port: "80"
```

### ConfigMap使用

三种分别方式为：

1. 设置环境变量
1. 设置容器命令行参数
1. 在 Volume 中直接挂载文件或目录。

> Tips
>  - ConfigMap 必须在 Pod 引用它之前创建
>  - 使用`envFrom`时，将会自动忽略无效的键
>  - Pod 只能使用同一个命名空间内的 ConfigMap

首先创建 ConfigMap：

```shell
kubectl create configmap special-config --from-literal=special.how=very --from-literal=special.type=charm
kubectl create configmap env-config --from-literal=log_level=INFO
```

#### 用作环境变量

```yml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: ["/bin/sh", "-c", "env"]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.how
        - name: SPECIAL_TYPE_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.type
      envFrom:
        - configMapRef:
            name: env-config
  restartPolicy: Never
```

当 Pod 结束后会输出

```shell
SPECIAL_LEVEL_KEY=very
SPECIAL_TYPE_KEY=charm
log_level=INFO
```

#### 使用 volume 将 ConfigMap 作为文件或目录直接挂载

将创建的 ConfigMap 直接挂载至 Pod 的 / etc/config 目录下，其中每一个 key-value 键值对都会生成一个文件，key 为文件名，value 为内容

```yml
apiVersion: v1
kind: Pod
metadata:
  name: vol-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: ["/bin/sh", "-c", "cat /etc/config/special.how"]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: special-config
  restartPolicy: Never
```

当 Pod 结束后会输出

```shell
very
```

## CronJob

CronJob 即定时任务，就类似于 Linux 系统的 crontab，在指定的时间周期运行指定的任务。

CronJob Spec

- `.spec.schedule`指定任务运行周期，格式同[Cron](https://en.wikipedia.org/wiki/Cron)
- `.spec.jobTemplate`指定需要运行的任务，格式同Job
- `.spec.startingDeadlineSeconds`指定任务开始的截止期限
- `.spec.concurrencyPolicy`指定任务的并发策略，支持Allow、Forbid和Replace三个选项

## DaemonSet

DaemonSet保证在每个Node上都运行一个容器副本，常用来部署一些集群的日志、监控或者其他系统管理应用。典型的应用包括：

- 日志收集：logstash，fluentd
- 系统监控：Prometheus
- 系统程序：kube-proxy，glusterd

### Fluentd示例

```yml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: gcr.io/google-containers/fluentd-elasticsearch:1.20
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

### 滚动更新

通过`spec.updateStrategy.type`设置更新策略。目前支持两种策略

- OnDelete：默认策略，更新模板后，只有手动删除了旧的Pod后才会创建新的Pod
- RollingUpdate: 更新DaemonSet模板后，自动删除旧的Pod并创建新的Pod

在使用RollingUpdate策略时，还可以设置

- spec.updateStrategy.rollingUpdate.maxUnavailable，默认1
- spec.minReadySeconds，默认0

### 指定Node节点

DaemonSet 会忽略 Node 的 unschedulable 状态，有两种方式来指定 Pod 只运行在指定的 Node 节点上：

- nodeSelector：只调度到匹配指定 label 的 Node 上
- nodeAffinity：功能更丰富的 Node 选择器，比如支持集合操作
- podAffinity：调度到满足条件的 Pod 所在的 Node 上

## Deployment

有如下一些功能：

- 使用Deployment来创建ReplicaSet。ReplicaSet在后台创建Pod。检查启动状态，看它是成功还是失败。
- 更新Deployment的PodTemplateSpec字段来声明Pod的新状态。这会创建一个新的ReplicaSet，Deployment会按照控制的速率将Pod从旧的ReplicaSet移动到新的ReplicaSet中。
- 如果当前状态不稳定，回滚到之前的Deployment revision。每次回滚都会更新Deployment的revision。
- scale/autoscale
- 暂停Deployment来应用PodTemplateSpec的多个修复，然后恢复上线
- 清除旧的不必要的ReplicaSet

### 示例

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```

功能对应的cmd

- 扩容：`kubectl scale deployment nginx-deployment --replicas 10`
- 自动扩容：`kubectl autoscale deployment nginx-deployment --min=10 --max=15 --cpu-percent=80`
- 更新镜像：`kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1`
- 回滚：`kubectl rollout undo deployment/nginx-deployment --to-revision=1`

## Ingress

在本篇文章中你将会看到一些在其他地方被交叉使用的术语，为了防止产生歧义，我们首先来澄清下

- 节点（Node）：k8s集群中的服务器
- 集群（Cluster）：k8s管理的一组服务器集合
- 边界路由器：为局域网和Internet路由数据包的路由器，执行防火墙保护局域网络
- 集群网络：遵循k8s网络模型实现集群内的通信的具体实现，比如flannel和OVS
- 服务：k8s的服务是使用标签选择器标识的一组Pod Service。

### 什么是Ingress

通常情况下，service 和 pod 的 IP 仅可在集群内部访问。集群外部的请求需要通过负载均衡转发到 service 在 Node 上暴露的 NodePort 上，然后再由 kube-proxy 通过边缘路由器 (edge router) 将其转发给相关的 Pod 或者丢弃。

Ingress 可以给 service 提供集群外部访问的 URL、负载均衡、SSL 终止、HTTP 路由等。

### Ingress格式

```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
spec:
  rules:
  - http:
      paths:
      - path: /testpath
        backend:
          serviceName: test
          servicePort: 80
```

每个 Ingress 都需要配置 rules，目前 Kubernetes **仅支持** http 规则。上面的示例表示请求 /testpath 时转发到服务 test 的 80 端口。

### Ingress类型

#### 单服务Ingress

单服务 Ingress 即该 Ingress 仅指定一个没有任何规则的后端服务。

```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
spec:
  backend:
    serviceName: testsvc
    servicePort: 80
```

#### 多服务的Ingress

路由到多服务的Ingress，即根据请求路径的不同转发到不同的后端服务上，比如

```txt
foo.bar.com -> 178.91.123.132 -> / foo    s1:80
                                 / bar    s2:80
```

可以通过下面的 Ingress 来定义：

```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - path: /foo
        backend:
          serviceName: s1
          servicePort: 80
      - path: /bar
        backend:
          serviceName: s2
          servicePort: 80
```

#### 虚拟主机Ingress

虚拟主机 Ingress 即根据名字的不同转发到不同的后端服务上，而他们共用同一个的 IP 地址，如下所示

```txt
foo.bar.com --|                 |-> foo.bar.com s1:80
              | 178.91.123.132  |
bar.foo.com --|                 |-> bar.foo.com s2:80
```

下面是一个基于 Host header 路由请求的 Ingress：

```yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - backend:
          serviceName: s1
          servicePort: 80
  - host: bar.foo.com
    http:
      paths:
      - backend:
          serviceName: s2
          servicePort: 80
```

### Ingress Controller

Ingress 正常工作需要集群中运行 Ingress Controller。Ingress Controller 与其他作为 kube-controller-manager 中的在集群创建时自动启动的 controller 成员不同，需要用户选择最适合自己集群的 Ingress Controller，或者自己实现一个。

## Job

Job 负责批量处理短暂的一次性任务 (short lived one-off tasks)，即仅执行一次的任务，它保证批处理任务的一个或多个 Pod 成功结束。

### 类型

Kubernetes 支持以下几种 Job：

- 非并行Job：通常创建一个Pod直至其成功结束
- 固定结束册数的Job：设置`.spec.completions`，创建多个Pod，知道`.spec.completions`个Pod成功结束
- 带有工作队列的并行Job：设置`.spec.parallelism`但不设置`.spec.completions`，当所有Pod结束并且至少一个成功时，Job就认为是成功

根据`.spec.completions`和`.spec.parallelism`的设置，可以将Job划分为以下几种pattern

|Job类型|使用示例|行为|completions|parallelism|
|:----:|:-----:|:-:|:---------:|:---------:|
|一次性Job|数据库迁移|创建一个Pod直至其成功结束|1|1|
|固定结束次数的Job|处理工作队列的Pod|依次创建一个Pod运行直至completions个成功结束|2+|1|
|固定结束次数的并行Job|多个Pod同时处理工作队列|依次创建多个Pod运行直至completions个成功结束|2+|2+|
|并行Job|多个Job同时处理工作队列|创建一个或多个Pod直至有一个成功结束|1|2+|

### Job Spec格式

- spec.template格式同Pod
- RestartPolicy仅支持Never或OnFailure
- 单个Pod时，默认Pod成功运行后Job即结束
- `.spec.completions`标志Job结束需要成功运行的Pod个数，默认为1
- `.spec.parallelism`标志并行运行的Pod的个数，默认为1
- `.spec.activeDeadlineSeconds`标志失败Pod的重试最大时间，超过这个时间不会继续重试

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

### Init Container

Init容器在所有容器运行之前执行，常用来初始化配置。如果为一个Pod指定了多个Init容器，那些容器会顺序一次运行一个。每个Init容器必须运行成功，下一个才能够运行。当所有Init同期运行完成时，k8s初始化Pod并像平常一样运行应用容器。

### 容器声明周期钩子

容器声明周期钩子监听容器生命周期的特定时间，并在事件发生时执行已注册的回调函数。支持两种钩子：

  - postStart: 容器创建后立即执行，注意由于是异步执行，它无法保证一定在`ENTRYPOINT`之前运行。
  - preStop: 容器终止前执行，常用于资源清理。如果失败，容器同样也会被杀死

而钩子的回调函数支持两种方式：
  - exec
  - httpGet

### 自定义hosts

可以通过`pod.spec.hostAliases`来增加hosts内容，如

```yml
apiVersion: v1
kind: Pod
metadata:
  name: hostaliases-pod
spec:
  hostAliases:
  - ip: "10.1.2.3"
    hostnames:
    - "foo.remote"
    - "bar.remote"
  containers:
  - name: cat-hosts
    image: busybox
    command:
    - cat
    args:
    - "/etc/hosts"
```

### Pod时区

很多容器都是配置了UTC时区，与国内集群的Node所在时区有可能不一致，可以通过HostPath存储插件给容器配置与Node一样的时区：

```yml
apiVersion: v1
kind: Pod
metadata:
  name: pod-tz
spec:
  containers:
  - image: alpine
    name: pod-tz
    stdin: true
    tty: true
    volumeMounts:
    - mountPath: /etc/localtime
      name: time
      readOnly: true
  volumes:
  - name: time
    hostPath:
      path: /etc/localtime
      type: ""
```

## Service

Service是对一组提供相同功能的Pods的抽象，并为它们提供一个统一的入口。

四种类型

- ClusterIP: 默认类型，自动分配一个仅cluster内部可以访问的虚拟IP
- NodePort: 在ClusterIP基础上为Service在每台机器上绑定一个端口，这样就可以通过`<NodeIP>:NodePort`来访问该服务
- LoadBalancer: 在NodePort的基础上，借助cloud provider创建一个外部的负载均衡器，并将请求转发到`<NodeIP>:NodePort`
- ExternalName: 将服务通过DNS CNAME记录方式转发到指定的域名。

### 示例

Service 的定义也是通过`yaml`或`json`，比如下面定义了一个名为`nginx`的服务，将服务的`80`端口转发到`default namespace`中带有标签`app=nginx,tier=ingress`的Pod的80端口

```yml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: nginx
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
    tier: ingress
  sessionAffinity: None
  type: ClusterIP
```

### 协议

Service、Endpoints 和 Pod 支持三种类型的协议：

- TCP（Transmission Control Protocol，传输控制协议）是一种面向连接的、可靠的、基于字节流的传输层通信协议。
- UDP（User Datagram Protocol，用户数据报协议）是一种无连接的传输层协议，用于不可靠信息传送服务。
- SCTP（Stream Control Transmission Protocol，流控制传输协议），用于通过IP网传输SCN（Signaling Communication Network，信令通信网）窄带信令消息。

### Headless服务

Headless 服务即不需要 Cluster IP 的服务，即在创建服务的时候指定 spec.clusterIP=None。包括两种类型

- 不指定 Selectors，但设置 externalName，即上面的（2），通过 CNAME 记录处理
- 指定 Selectors，通过 DNS A 记录设置后端 endpoint 列表，DNS格式为`serviceName.namespace.svc.cluster.local`

因为没有ClusterIP，kube-proxy 并不处理此类服务，因为没有load balancing或 proxy 代理设置，在访问服务的时候回返回后端的全部的Pods IP地址，主要用于开发者自己根据pods进行负载均衡器的开发(设置了selector)。

### 工作原理

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/service-flow.png)

> 图片来源：https://feisky.gitbooks.io/kubernetes/content/concepts/service.html

## ReplicaSet

ReplicaSet用来确保容器应用的副本数始终保持在用户定义的副本数，即如果有容器异常退出，会自动创建新的Pod来替代。虽然ReplicaSet可以独立使用，但建议使用Deployment来自动管理ReplicaSet，这样就无需担心跟其他机制的不兼容问题（比如ReplicaSet不支持rolling-update但Deployment支持），并且还支持版本记录、回滚、暂停升级等高级特性。


## StatefulSet

StatefulSet是为了解决有状态服务的问题，应用场景包括

- 持久化存储，即Pod重新调度后还是能访问到相同的持久化数据，基于`PVC`实现
- 稳定的网络标志，即Pod重新调度后其PodName和HostName不变，基于`Headless Service`来实现
- 有序部署，有序扩展，即Pod是有顺序的，在部署或者扩展的时候要一句定义的顺序依次进行，基于`init containers`来实现
- 有序收缩，有序删除

从上面的场景可以发现，StatefulSet 由以下几个部分组成：

- 用于定义网络标志（DNS domain）的 `Headless Service`
- 用于创建 PersistentVolumes 的 `volumeClaimTemplates`
- 定义具体应用的 `StatefulSet`

StatefulSet中每个Pod的DNS格式为`statefulSetName-{0..N-1}.serviceName.namespace.svc.cluster.local`，其中

- `statefulSetName`为StatefulSet 的名字
- `0..N-1`为Pod所在的序号，从 0 开始到 N-1
- `serviceName`为Headless Service的名字
- `namespace`为服务所在的 namespace，Headless Service 和 StatefulSet 必须在相同的 namespace
- `.cluster.local`为 Cluster Domain

### 简单示例

以一个简单的nginx服务为例

```yml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
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
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

进行操作

```shell
# 扩容
$ kubectl scale statefulset web --replicas=5  # 可以看出Pod是按照次序创建的

# 缩容
$ kubectl patch statefulset web -p '{"spec":{"replicas":3}}'

# 镜像更新（目前还不支持直接更新 image，需要 patch 来间接实现）
$ kubectl patch statefulset web --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"gcr.io/google_containers/nginx-slim:0.7"}]'

# 删除 StatefulSet 和 Headless Service
$ kubectl delete statefulset web
$ kubectl delete service nginx

# StatefulSet 删除后 PVC 还会保留着，数据不再使用的话也需要删除
$ kubectl delete pvc www-web-0 www-web-1
```

### 更新StatefulSet

通过`.spec.updateStrategy`设置更新策略。目前支持两种策略

- OnDelete：当`.spec.template`更新时，并不立即删除旧的Pod，而是等待用户手动删除这些旧Pod后自动创建新Pod。
- RollingUpdate：当`.spec.template`更新时，自动删除旧的Pod并创建新Pod替换。在更新时，这些Pod是按逆序的方式进行，依次删除、创建并等待Pod变成Ready状态才进行下一个Pod的更新。

### Pod管理策略

通过`.spec.podManagementPolicy`设置Pod管理策略，支持两种方式

- OrderedReady：默认的策略，按照Pod的次序依次创建每个Pod并等待Ready之后才创建后面的Pod
- Parallel：并行创建或删除Pod

### Zookeeper示例

[官网示例](https://kubernetes.io/zh/docs/tutorials/stateful-application/zookeeper/)

## Node

## Namespace

## Resource Quotas

## Volumes

## PV/PVC/StorageClass

## Secret

## Service Account

## Security Context

## Network Policy

## PodPreset
