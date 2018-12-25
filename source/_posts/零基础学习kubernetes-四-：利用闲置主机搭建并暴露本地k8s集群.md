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
