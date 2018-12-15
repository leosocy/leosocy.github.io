---
title: Pipenv——它是Python包管理的大救星
copyright: false
date: 2018-12-10 11:40:04
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/intro_to_pipenv.jpg
tags:
- Python
- Tool
categories:
- Python Development
---

`Pipenv`是Python的一个打包工具，它使用`pip`、`virtualenv`和旧式的`requirements.txt`解决了与典型工作流相关的一些常见问题。

除了解决一些常见问题之外，它还将开发过程合并并简化为单个命令行工具。

本指南将介绍Pipenv解决了哪些问题，以及如何管理与Pipenv的Python依赖关系。此外，它还将介绍如何从以前的requirements.txt转为使用Pipenv管理包。

<!-- more -->

## Pipenv为何而生

要理解Pipenv的好处，了解Python中打包和依赖管理的当前方法是很重要的。

让我们从处理第三方包的典型情况开始。然后，我们将构建部署完整Python应用程序的方法。

### 使用`requirements.txt`进行依赖管理

假设你正在处理一个使用flask等第三方包的Python项目。您需要指定该需求，以便其他开发人员和自动化系统能够运行您的应用程序。

你决定在requirements.txt中包含flask的依赖

```txt
flask
```

很好，一切都在本地运行良好，在对应用程序进行了一段时间的黑客攻击之后，您决定将其转移到生产环境中。可怕的事情开始了。。。

上面的requirements.txt并没有指定flask的版本。这种情况下，`pip install -r requirements.txt`将默认安装最新的版本。

对于这个例子，我们假设已经发布了flask的一个新版本。但是，它与开发期间使用的版本不向后兼容。

现在，假设您将应用程序部署到生产环境中，并执行`pip install -r requirements.txt`，pip得到了最新的、不向后兼容的flask版本，就像这样，您的应用程序在生产过程中崩溃了。

> 程序员小哥内心OS：这在我本地跑的好好地，怎么一发生产就崩了呢，我***

现在，您知道在开发过程中使用的flask版本运行良好。因此，为了修复问题，您需要在requirements.txt中更加具体一些。你指定了一个flask的版本。这也称为固定依赖项:

```txt
flask==0.12.1
```

固定flask的版本确保了`pip install -r requirements.txt`可以安装flask的精确版本。但是这就万事大吉了吗？

请记住，flask本身也有依赖项(pip会自动安装这些依赖项)。但是，flask本身并没有为它的依赖项指定精确的版本。例如，它允许任何版本的Werkzeug>=0.14。

同样，为了这个例子，我们假设发布了一个新的Werkzeug版本，但是它给您的应用程序引入了一个停止显示的bug。

当你执行`pip install -r requirements.txt`，你将会安装`flask==0.12.1`因为你已经固定了该版本。然而，不幸的是，您将得到最新的、有bug的Werkzeug版本。同样，产品在生产过程中出现故障。

这里真正的问题是构建不是确定性的。我的意思是，给定相同的输入(requirements.txt文件)，pip并不总是生成相同的环境。目前，您无法轻松复制开发的环境到生产上去。

这个问题的典型解决方案是使用`pip freeze`。该命令允许您获得当前安装的所有第三方库的准确版本，包括自动安装的子依赖项pip。因此，您可以冻结开发中的所有内容，以确保在生产环境中拥有相同的环境。

执行`pip freeze`会得到固定的依赖关系

```txt
click==6.7
Flask==0.12.1
itsdangerous==0.24
Jinja2==2.10
MarkupSafe==1.0
Werkzeug==0.14.1
```

有了这些固定的依赖项，您可以确保安装在生产环境中的包与开发环境中的包完全匹配，这样您的产品就不会意外地损坏。不幸的是，这种“解决方案”会导致一系列全新的问题。

现在您已经指定了每个第三方包的确切版本，您负责使这些版本保持最新，即使它们是flask的子依赖项。如果在Werkzeug==0.14.1中发现了一个安全漏洞，包维护人员立即在Werkzeug==0.14.2中修补了这个漏洞，该怎么办?您确实需要更新到Werkzeug==0.14.2，以避免由早期未打补丁的Werkzeug版本引起的任何安全问题。

首先，您需要意识到您的版本有问题。然后，在有人利用安全漏洞之前，您需要在生产环境中获得新版本。所以，你必须改变requirements.txt手动指定新版本Werkzeug==0.14.2。正如您在这种情况下所看到的，保持必要更新的责任落在了您的身上。

事实是，只要不破坏您的代码，您实际上并不关心安装了什么版本的Werkzeug。事实上，您可能希望最新的版本能够确保您得到了bug修复、安全补丁、新特性、更多优化等等。

真正的问题是:“如何在不承担更新子依赖项版本的责任的情况下为Python项目提供确定性构建?”

### 开发具有不同依赖关系的项目

让我们稍微转换一下话题，讨论在处理多个项目时出现的另一个常见问题。假设ProjectA需要django==1.9，但是ProjectB需要django==1.10。

默认情况下，Python试图将所有第三方包存储在系统范围内的位置。这意味着每次在ProjectA和ProjectB之间切换时，都必须确保安装了正确的django版本。这使得在项目之间切换非常痛苦，因为您必须卸载和重新安装包来满足每个项目的需求。

标准的解决方案是使用具有自己的Python可执行文件和第三方包存储的[`virtual environment`](https://realpython.com/python-virtual-environments-a-primer/)。这样，ProjectA和ProjectB就可以充分分离。现在您可以轻松地在项目之间切换，因为它们不共享相同的包存储位置。PackageA可以在它自己的环境中拥有它需要的django的任何版本，而PackageB可以完全独立拥有它需要的任何版本。一个非常常用的工具是virtualenv(或Python 3中的venv)。

### 依赖解析

依赖性解析是什么意思?假设你有一个requirements.txt文件看起来像这样:

```txt
package_a
package_b
```

假设package_a有一个子依赖项package_c, package_a需要这个包的特定版本:package_c>=1.0。反过来，package_b具有相同的子依赖关系，但需要package_c<=2.0。

理想情况下，当您尝试安装package_a和package_b时，安装工具将查看package_c的需求(>=1.0和<=2.0)并选择满足这些需求的版本。您希望该工具能够解决依赖关系，以便您的程序最终能够工作。这就是我所说的“依赖解析”。

不幸的是，pip本身目前还没有真正的依赖性解决方案。pip处理上述情况的方法如下:

1. 它安装package_a并寻找满足第一个需求的package_c版本(package_c>=1.0)。
1. 然后，pip安装package_c的最新版本来满足这个需求。假设package_c的最新版本是3.1。

这就是麻烦开始的地方。

如果pip选择的package_c版本不符合未来的需求(例如package_b需要package_c<=2.0)，则安装将失败。

这个问题的“解决方案”是在requirements.txt中指定子依赖项(package_c)所需的范围。这样，pip就可以解决这个冲突，并安装一个满足这些要求的包:

```txt
package_c>=1.0,<=2.0
package_a
package_b
```

就像以前一样，您现在直接关注子依赖项(package_c)。这样做的问题是，如果package_a在您不知道的情况下更改了它们的需求，那么您指定的需求(package_c>=1.0，<=2.0)可能不再可以接受，并且安装可能再次失败……真正的问题是，您要再次负责满足子依赖项的需求。

理想情况下，您的安装工具足够智能，可以安装满足所有需求的包，而无需显式指定子依赖项版本。

## Pipenv介绍

让我们看看Pipenv如何解决它们。

首先，安装Pipenv

```shell
pip install pipenv
```

一旦你这样做了，你就丢点pip了，因为Pipenv实际上是一个替代品。它还引入了两个新文件，Pipfile(用于替代requirements.txt)和Pipfile.lock(支持确定性构建)。

Pipenv在底层使用pip和virtualenv，但通过一个命令行接口简化了它们的使用。

#### 使用示例

让我们从头开始创建您出色的Python应用程序。首先，在virtual env中衍生一个shell，隔离这个app的开发:

```shell
pipenv shell
```

如果一个环境还不存在的话将创建一个虚拟环境。您可以使用参数--two/--three强制创建Python2或3环境。否则，Pipenv将使用virtualenv找到的任何默认值。

现在你可以安装你需要的第三方软件包flask。但是你知道你需要的是0.12.1版本，而不是最新的版本，所以请具体说明:

```shell
pipenv install flask==0.12.1
```

您应该在终端中看到如下内容:

```shell
Adding flask==0.12.1 to Pipfile's [packages]...
Pipfile.lock not found, creating...
```

您会注意到创建了两个文件，一个`Pipfile`和`Pipfile.lock`。我们稍后会更仔细地看这些。让我们安装另一个第三方软件包numpy来处理一些数据。你不需要一个特定的版本，所以不要指定一个:

```shell
pipenv install numpy
```

你也可以从Github上安装某些依赖，例如安装`requests`库

```shell
pipenv install -e git+https://github.com/requests/requests.git#egg=requests
```

假设您还为这个出色的应用程序进行了一些单元测试，您希望使用pytest来运行它们。在生产环境中不需要pytest，因此可以指定这个依赖关系只用于开发，使用—dev参数:

```shell
pipenv install pytest --dev
```

提供——dev参数将把依赖项放在Pipfile中一个特殊的[dev-package]位置。只有在使用pipenv install指定—dev参数时，才会安装这些开发包。

不同的部分将仅用于开发的依赖项与用于基本代码实际工作的依赖项分开。通常，这可以通过附加的requirements文件(如dev-requirements.txt或test-requirements.txt)来完成。现在，在不同的部分中，所有内容都被合并到一个Pipfile中。

好了，假设您已经在本地开发环境中完成了所有工作，并且准备将其投入生产。要做到这一点，您需要锁定您的环境，以便确保在生产中拥有相同的环境:

```shell
pipenv lock
```

这将创建/更新您的Pipfile.lock，您永远不需要(也永远不打算)手动编辑。您应该始终使用生成的文件。

现在，在生产环境中获得了代码和Pipfile.lock，您应该安装最后成功记录的环境:

```shell
pipenv install --ignore-pipfile
```

这告诉Pipenv在安装时忽略Pipfile，而使用Pipfile.lock中的内容。根据Pipfile.lock，Pipenv将创建与运行`pipenv lock`时完全相同的环境，子依赖项等等。

锁文件通过获取环境中包的所有版本的快照(类似于pip freeze结果)来支持确定性构建。

现在，假设另一个开发人员希望对您的代码进行一些添加。在这种情况下，他们会得到代码，包括Pipfile，并使用这个命令:

```shell
pipenv install --dev
```

这将安装开发所需的所有依赖项，包括常规依赖项和安装期间使用`--dev`参数指定的依赖项。

当Pipfile中没有指定确切的版本时，install命令为依赖项(和子依赖项)提供了更新它们的版本的机会。

这是一个重要的注意事项，因为它解决了前面讨论的一些问题。为了演示，假设您的某个依赖项的新版本可用。因为不需要这个依赖项的特定版本，所以不需要在Pipfile中指定确切的版本。当您安装pipenv时，依赖项的新版本将安装在您的开发环境中。

现在，您对代码进行了更改，并运行了一些测试，以验证一切都按预期工作。(你有单元测试，对吧?)现在，和以前一样，使用`pipenv lock`锁定环境。Pipfile.lock将与依赖项的新版本一起生成。与以前一样，您可以在生产环境中使用锁文件复制这个新环境。

正如您从这个场景中看到的，您不再需要强制执行您并不真正需要的确切版本，以确保开发和生产环境是相同的。你也不需要时刻关注你“不关心”的子依赖关系的更新。Pipenv的这个工作流，结合您出色的测试，解决了手工执行所有依赖管理的问题。

### Pipenv的依赖性解决方法

Pipenv将尝试安装满足核心依赖项所有需求的子依赖项。但是，如果存在相互冲突的依赖关系(package_a需要package_c>=1.0, package_b需要package_c<1.0)， Pipenv将无法创建锁文件，并将输出如下错误:

```shell
Warning: Your dependencies could not be resolved. You likely have a mismatch in your sub-dependencies.
  You can use $ pipenv install --skip-lock to bypass this mechanism, then run $ pipenv graph to inspect the situation.
Could not find a version that matches package_c>=1.0,package_c<1.0
```

正如警告所说，您还可以显示一个依赖关系图来理解顶级依赖关系及其子依赖关系:

```shell
pipenv graph
```

这个命令将打印出一个树状结构，显示您的依赖项。这里有一个例子:

```shell
Flask==0.12.1
  - click [required: >=2.0, installed: 6.7]
  - itsdangerous [required: >=0.21, installed: 0.24]
  - Jinja2 [required: >=2.4, installed: 2.10]
    - MarkupSafe [required: >=0.23, installed: 1.0]
  - Werkzeug [required: >=0.7, installed: 0.14.1]
numpy==1.14.1
pytest==3.4.1
  - attrs [required: >=17.2.0, installed: 17.4.0]
  - funcsigs [required: Any, installed: 1.0.2]
  - pluggy [required: <0.7,>=0.5, installed: 0.6.0]
  - py [required: >=1.5.0, installed: 1.5.2]
  - setuptools [required: Any, installed: 38.5.1]
  - six [required: >=1.10.0, installed: 1.11.0]
requests==2.18.4
  - certifi [required: >=2017.4.17, installed: 2018.1.18]
  - chardet [required: >=3.0.2,<3.1.0, installed: 3.0.4]
  - idna [required: >=2.5,<2.7, installed: 2.6]
  - urllib3 [required: <1.23,>=1.21.1, installed: 1.22]
```

从`pipenv graph`的输出中，您可以看到我们之前安装的顶级依赖项(Flask、numpy、pytest和请求)，在下面您可以看到它们所依赖的包。

另外，您可以反转树来显示与需要它的父类的子依赖关系:

```shell
pipenv graph --reverse
```

当您试图找出相互冲突的子依赖关系时，此反向树可能更有用。

### Pipfile

Pipfile出现的意图是替代`requirements.txt`。Pipenv是目前使用Pipfile的参考实现。pip本身似乎很可能能够处理这些文件。此外，值得注意的是，Pipenv甚至是Python本身推荐的官方包管理工具。

Pipfile的语法是[TOML](https://github.com/toml-lang/toml)，文件分为几个部分。[dev-packages]只用于开发包，[package]用于最低需求的包，[require]用于其他需求，如Python的特定版本。请看下面的示例文件:

```toml
[[source]]
url = "https://pypi.python.org/simple"
verify_ssl = true
name = "pypi"

[dev-packages]
pytest = "*"

[packages]
flask = "==0.12.1"
numpy = "*"
requests = {git = "https://github.com/requests/requests.git", editable = true}

[requires]
python_version = "3.6"
```

理想情况下，在Pipfile中不应该有任何子依赖项。我的意思是您应该只包含您实际导入和使用的包。不需要仅仅因为`chardet`是请求的子依赖项就将它保存在Pipfile中。(Pipenv会自动安装。)Pipfile应该传递包所需的顶级依赖项。

### Pipfile.lock

该文件通过指定复制环境的确切需求来支持确定性构建。它包含包和散列的精确版本，以支持更安全的验证，pip本身现在也支持这种验证。示例文件可能如下所示。注意这个文件的语法是JSON，我用…排除了部分文件:

```json
{
    "_meta": {
        ...
    },
    "default": {
        "flask": {
            "hashes": [
                "sha256:6c3130c8927109a08225993e4e503de4ac4f2678678ae211b33b519c622a7242",
                "sha256:9dce4b6bfbb5b062181d3f7da8f727ff70c1156cbb4024351eafd426deb5fb88"
            ],
            "version": "==0.12.1"
        },
        "requests": {
            "editable": true,
            "git": "https://github.com/requests/requests.git",
            "ref": "4ea09e49f7d518d365e7c6f7ff6ed9ca70d6ec2e"
        },
        "werkzeug": {
            "hashes": [
                "sha256:d5da73735293558eb1651ee2fddc4d0dedcfa06538b8813a2e20011583c9e49b",
                "sha256:c3fd7a7d41976d9f44db327260e263132466836cef6f91512889ed60ad26557c"
            ],
            "version": "==0.14.1"
        }
        ...
    },
    "develop": {
        "pytest": {
            "hashes": [
                "sha256:8970e25181e15ab14ae895599a0a0e0ade7d1f1c4c8ca1072ce16f25526a184d",
                "sha256:9ddcb879c8cc859d2540204b5399011f842e5e8823674bf429f70ada281b3cc6"
            ],
            "version": "==3.4.1"
        },
        ...
    }
}
```

请注意为每个依赖项指定的确切版本。甚至像werkzeug这样不在Pipfile中的子依赖项也会出现在这个Pipfile.lock中。散列用于确保检索的包与在开发中检索的包相同。

值得再次注意的是，永远不要手工更改此文件。它是用`pipenv lock`生成的。

### Pipenv额外特性

使用以下命令在默认编辑器中打开第三方包:

```shell
pipenv open flask
```

这将在默认编辑器中打开flask包，或者您可以使用编辑器环境变量指定程序。

---

您可以在虚拟环境中运行命令，而无需启动shell:

```shell
pipenv run <insert command here>
```

---

现在，假设您不再需要一个包。你可以卸载它:

```shell
pipenv uninstall numpy
```

另外，假设您希望从虚拟环境中完全删除所有已安装的包:

```shell
pipenv uninstall --all
```

您可以用`--all-dev`替换`--dev`来删除所有开发包。

---

当顶级目录中存在.env文件时，Pipenv支持自动加载环境变量。这样，当您pipenv shell打开虚拟环境时，它将从文件中加载环境变量。env文件只包含键-值对:

```txt
SOME_ENV_CONFIG=some_value
SOME_OTHER_ENV_CONFIG=some_other_value
```

---

## 如何从`requirements.txt`转为Pipfile

如果您运行pipenv安装，它应该自动检测requirements.txt并将其转换为Pipfile，输出如下所示:

```txt
requirements.txt found, instead of Pipfile! Converting…
Warning: Your Pipfile now contains pinned versions, if your requirements.txt did.
We recommend updating your Pipfile to specify the "*" version, instead.
```

如果您已经在您的需求中固定了精确的版本。您可能希望将Pipfile更改为仅指定您真正需要的确切版本。这会让你从转变中获得真正的好处。例如，假设您拥有以下内容，但实际上并不需要精确的numpy版本:

```toml
[packages]
numpy = "==1.14.1"
```

如果您对依赖项没有任何特定的版本需求，您可以使用通配符*告诉Pipenv任何版本都可以安装:

```toml
[packages]
numpy = "*"
```

如果您对允许任何带有*的版本感到紧张，通常可以安全地指定大于或等于您已经使用的版本，这样您仍然可以利用新版本:

```toml
[packages]
numpy = ">=1.14.1"
```

---

您还可以使用-r参数从requirement文件中安装:

```shell
pipenv install -r requirements.txt
```

如果您有`dev-requirements.txt`或类似的东西，您也可以将它们添加到Pipfile。只要添加--dev参数，它就会被放到正确的部分:

```shell
pipenv install -r dev-requirements.txt --dev
```

## 引用

[Pipenv: A Guide to the New Python Packaging Tool](https://realpython.com/pipenv-guide/#dependency-resolution)