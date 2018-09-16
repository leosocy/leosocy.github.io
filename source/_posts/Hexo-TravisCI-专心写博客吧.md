---
title: 'Hexo+TravisCI: 专心写博客吧'
copyright: true
date: 2018-09-11 00:03:51
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/hexo-header.png
tags:
- Hexo
- CI
categories:
- CI
---

相信大家都有自己的博客，也都体会过那几天折腾博客的成就感。利用`Github Pages` + `Hexo`可以很容易的搭建一个属于自己的个性化博客主页。同时，你只需要关心自己文章的内容，以及基本的markdown排版即可，`Hexo`可以解析md生成对应的html，进而展示在你的博客主页。

发布博客的步骤不算繁琐，但是重复性较高，而且需要安装相关环境(`npm`、`hexo-cli`...)，当我们需要在不同的电脑上发布博客的时候，是不是会觉得很麻烦呢？很多小伙伴只想关心如何写文章的内容，希望写完之后，只需要`git push`一下就可以在主页上看到新发布的文章。

本文介绍了如何通过`Travis CI`简化发布流程，让大家可以专心的写自己的博客！

Let's go~

<!-- more -->

> 偷懒是创造力的源泉

# 事前准备

## Github

1. 上传博客源码到github仓库。笔者这里是直接把博客源码推到Github Pages项目的`blog`分支了，这样做的好处是可以集中管理一个项目。同时把`*.github.io`项目的默认分支设置成`blog`，这样可以在项目主页上显示README。
![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/006tNc79gy1fvbjmen5zoj30l004jmxk.jpg)
2. 生成[`access token`](https://github.com/settings/tokens/new)。为了TravisCI可以读写我们的项目，这里token的权限只选择控制repo就好。
![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/006tNc79gy1fvbk2r34mxj30l6069diu.jpg)

## Travis-CI

1. 开启[TravisCI](https://travis-ci.org/profile)，打开刚才托管的博客源码仓库同步开关（采用不同分支管理，则开启`*.github.io`项目；采用不同项目管理，则开启对应的项目）
![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180916205509.png)
2. 设置`Environment Variables`，将上一步在Github生成的access token保存到环境变量中，便于之后在脚本中使用。同时可以设置`hexo deploy`时使用的git用户名和邮箱。
![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180916210526.png)

# CI yaml配置

`.travis.yml`是一个指示ci触发后如何进行构建的配置文件。

进入项目根目录，执行

```yaml
cd leosocy.github.io
touch .travis.yml
```

具体配置如下（部分配置需要根据个人情况修改）

```yaml
language: node_js
node_js:
- 6.14.3
sudo: required
cache:
  directories:
  - node_modules  # npm install will still run on every build and will update/install any new packages added to your package.json file.

branches:
only:
- blog  # 只有blog分支的提交才会触发ci。如果是不同项目管理的博客则不需要此配置

before_install:
- export TZ='Asia/Shanghai'   # 设置时区，用于提交到github pages的master分支时显示准确的commit时间
- npm install hexo-cli -g --save
- npm install hexo --save

install:
- npm install
- npm install hexo-deployer-git --save


# 清除缓存，重新生成部署文件
script:
- hexo clean
- hexo generate

after_script:
- git config user.name ${GIT_USER_NAME}
- git config user.email ${GIT_USER_EMAIL}
- sed -i "s/GITHUB_TOKEN/${GITHUB_TOKEN}/g" _config.yml   # 替换hexo配置文件中的deploy配置`
```

`_config.yml`中的deploy设置如下

```yaml
deploy:
  type: git
  repo: https://GITHUB_TOKEN@github.com/yourname/your_github_pages.git
  branch: master
```

[我的travis-ci配置](https://github.com/Leosocy/leosocy.github.io/blob/blog/.travis.yml)

将`.travis.yml`和`_config.yml`的变更push到独立的分支或者项目中去，我们就能在travis-ci上看到对应的构建了

# 效果

![](https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/20180916224800.png)

CI成功之后，刷新一下你的博客主页，就能看到刚刚写的文章喽(*^▽^*)

