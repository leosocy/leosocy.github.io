---
layout: post
title: 设计模式Python实现
date: 2018-05-28
copyright: true
photos:
  - images/design-pattern.jpg
tags:
  - Python
  - 设计模式
categories:
  - 编码技能
---

> 最近找到了一篇容易理解的关于设计模式的文章，比较深刻地讲解了设计模式 [史上最全设计模式导学目录（完整版）](https://blog.csdn.net/lovelion/article/details/17517213)。 为了加深自己对设计模式的理解，同时熟悉Python面向对象编程的技巧，遂写下此篇文章，记录每种设计模式对应的一个练习题，并附上Python代码实现。

<!-- more -->

## 简单工厂模式-Simple Factory Pattern

#### 问题背景

XX软件公司欲基于Python语言开发一套图表库，该图表库可以为应用系统提供各种不同外观的图表，例如柱状图、饼状图、折线图等。XX软件公司图表库设计人员希望为应用系统开发人员提供一套灵活易用的图表库，而且可以较为方便地对图表库进行扩展，以便能够在将来增加一些新类型的图表。

#### 改进前

```Python
class Chart(object):

    def __init__(self, type):
        self._type = type
        if type.lower() == "histogram":
            print("初始化柱状图")
        elif type.lower() == "pie":
            print("初始化饼状图")
        elif type.lower() == "line":
            print("初始化折线图")

    def display(self):
        if self._type.lower() == "histogram":
            print("显示柱状图")
        elif self._type.lower() == "pie":
            print("显示化饼状图")
        elif self._type.lower() == "line":
            print("显示化折线图")

if __name__ == '__main__':
    histogram = Chart("histogram")
    histogram.display()
```

此实现存在以下几个问题：

1. `init`函数和`display`函数中进行了大量的`if...else...`判断，并且均为重复代码
1. Chart类既负责了所有种类图标的初始化，又负责了显示功能，违背了"单一职责原则"
1. 如果需要新增一种图标的类型，需要修改Chart类的源码，违反了"开闭原则"

#### 改进后

```Python
from abc import abstractmethod, ABCMeta

class Chart(metaclass=ABCMeta):
    """
    """

    @abstractmethod
    def __init__(self):
        pass
        
    @abstractmethod
    def display(self):
        pass


class HistogramChart(Chart):
    """
    """

    def __init__(self):
        print("初始化柱状图")

    def display(self):
        print("显示柱状图")


class PieChart(Chart):
    """
    """

    def __init__(self):
        print("初始化饼状图")

    def display(self):
        print("显示饼状图")


class LineChart(Chart):
    """
    """

    def __init__(self):
        print("初始化折线图")

    def display(self):
        print("显示折线图")

class ChartFactory(object):
    
    @staticmethod
    def create(chart_type):
        for sc in Chart.__subclasses__():
            if sc.__name__ == chart_type:
                return sc()
        return None


if __name__ == '__main__':
    chart = ChartFactory.create("HistogramChart")
    if chart:
        chart.display()
```

此实现有以下优点：

1. 不同种类的图标各司其职
1. 利用Python的特性，省略了在工厂类中`if...else...`的判断，但是可能会增加使用复杂度，因为客户端要输入具体的类名
1. 新增一种图表，不需要修改原有的代码

## 工厂方法模式-Factory Method Pattern

#### 问题背景

# 问题描述

XX软件公司欲开发一个系统运行日志记录器(Logger)，该记录器可以通过多种途径保存系统的运行日志，如通过文件记录或数据库记录，用户可以通过修改配置文件灵活地更换日志记录方式。在设计各类日志记录器时，Sunny公司的开发人员发现需要对日志记录器进行一些初始化工作，初始化参数的设置过程较为复杂，而且某些参数的设置有严格的先后次序，否则可能会发生记录失败。如何封装记录器的初始化过程并保证多种记录器切换的灵活性是XX公司开发人员面临的一个难题。

XX公司的开发人员通过对该需求进行分析，发现该日志记录器有两个设计要点：

- 需要封装日志记录器的初始化过程，这些初始化工作较为复杂，例如需要初始化其他相关的类，还有可能需要读取配置文件（例如连接数据库或创建文件），导致代码较长，如果将它们都写在构造函数中，会导致构造函数庞大，不利于代码的修改和维护；
- 用户可能需要更换日志记录方式，在客户端代码中需要提供一种灵活的方式来选择日志记录器，尽量在不修改源代码的基础上更换或者增加日志记录方式。

#### 改进前

#### 改进后

## 抽象工厂模式-Abstract Factory Pattern

## 单例模式-Singleton Pattern

## 原型模式-Prototype Pattern

## 建造者模式-Builder Pattern

## 适配器模式-Adapter Pattern

## 桥接模式-Bridge Pattern

## 组合模式-Composite Pattern

## 装饰模式-Decorator Pattern

## 外观模式-Facade Pattern

## 享元模式-Flyweight Pattern

## 代理模式-Proxy Pattern