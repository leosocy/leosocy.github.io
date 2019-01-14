---
title: '零基础学习kubernetes(五): ServiceMesh--微服务的最后一块拼图'
copyright: true
date: 2019-01-14 21:43:28
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/service-mesh-1680.png
tags:
- k8s
- ServiceMesh
categories:
- kubernetes
---

[上一节](./零基础学习kubernetes-四-利用闲置主机搭建并暴露本地k8s集群.md)，笔者介绍了如何通过frp暴露内网的k8s集群，并在公网操作集群。通过frp我们可以将来自公网的请求路由到内网的指定端口，这种方法可以结合service的NodePort部署方式来简单的暴露集群中的服务，甚至可以基于frp的location路由功能，将请求根据不同路径路由到不同的svc上。想想目前的功能可以cover住基本的需求，但是如果仅仅这样我们就无法利用k8s的强大特性了(服务发现/负载均衡/限流等等)。

本篇文章会将Istio引入集群，并通过示例展示如何将https请求路由到内部的服务中去。

<!-- more -->
