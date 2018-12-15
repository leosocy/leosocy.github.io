---
layout: post
title: CMake语言和语法
subtitle: 整理CMake常用和进阶的使用方法
date: 2018-04-05
copyright: true
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/cmake-logo.png
tags:
- CMake
categories:
- 基础知识/技能
---

# CMake

在项目或者工作中，会不可避免的使用到cmake来构建我们的项目，所以掌握cmake的基本语法，以及常用的和进阶的使用方法是非常重要的。

下面我们将从一个简单的`hello cmake`示例开始，一步步的深入了解cmake的用法。

<!-- more -->

***Let's Go!***

### 初探CMake，hello cmake

#### 准备工作

创建目录 /home/workspace/cmake_practice，我们之后的练习都放到这个目录的子目录下

在cmake_practice目录下创建test1

```shell
cd /home/workspace/cmake_practice
mkdir test1
cd test1
```

创建main.c以及CMakeLists.txt

main.c内容如下

```C
include <stdio.h>

int main(void)
{
    printf("Hello CMake!\n")
    return 0;
}
```

CMakeLists.txt内容如下

```cmake
PROJECT(hello-cmake)
SET(SRC_LIST main.c)
MESSAGE(STATUS "This is BINARY dir" ${PROJECT_BINARY_DIR})
MESSAGE(STATUS "This is SOURCE dir" ${PROJECT_SOURCE_DIR})
ADD_EXECUTABLE(hello-cmake ${SRC_LIST})
```

#### 开始构建

在test1目录下执行`cmake .`(. 代表当前目录)

这时会在当前目录生成`CMakeFiles`、`cmake_install.cmake`、`Makefile`等文件

我们只要关心Makefile就可以了，此时执行`make`，我们就得到了可执行文件`hello-cmake`

运行`./hello-cmake`

得到输出

`Hello CMake!`

#### 示例的语法解释

cmake的函数可以通过`cmake --help-command cmd`来查看具体的语法及使用方法

- PROJECT

    语法：
    ```cmake
    project(<projectname> [languageName1 languageName2 ... ] )
    ```
    设置项目名称并可指定工程支持的语言，支持的语言列表是可以忽略的，默认情况表示支持所有语言。这个指令隐式的定义了两个cmake变量:

        - <projectname>_BINARY_DIR
        - <projectname>_SOURCE_DIR

    因为采用的是内部编译，两个变量目前指的都是工程所在路径/home/workspace/cmake_practice/test1，后面我们会讲到外部编译，两者所指代的内容会有所不同。

    同时 cmake 系统也帮助我们预定义了 `PROJECT_BINARY_DIR` 和 `PROJECT_SOURCE_DIR`
    变量，他们的值分别跟 `<projectname>_BINARY_DIR` 与 `<projectname>_SOURCE_DIR` 一致。

    为了统一起见，建议以后直接使用 `PROJECT_BINARY_DIR`，`PROJECT_SOURCE_DIR`，即
    使修改了工程名称，也不会影响这两个变量。如果使用了
    `<projectname>_SOURCE_DIR`，修改工程名称后，需要同时修改这些变量。

- SET

    语法：
    ```cmake
    SET(<variable> <value>
        [[CACHE <type> <docstring> [FORCE]] | PARENT_SCOPE])
    ```
    在初探阶段，我们只需要知道`SET`命令可以用来显示的定义一个变量。
    比如在这个例子中`SET(SRC_LIST main.c)`，即定义了一个变量`SRC_LIST`，此变量的值为`main.c`。当然如果有多个源文件，可以定义为`SET(SRC_LIST main.c test1.c test2.c)`。

- MESSAGE

    语法：
    ```cmake
    message([STATUS|WARNING|AUTHOR_WARNING|FATAL_ERROR|SEND_ERROR]
            "message to display" ...)
    ```
    可选关键字决定消息的类型：
    - none          = 重要信息
    - STATUS        = 附带信息
    - WARNING       = CMake警告，继续处理
    - AUTHOR_WARNING= CMake警告（dev），继续处理
    - SEND_ERROR    = CMake错误，继续处理，但跳过生成
    - FATAL_ERROR   = CMake错误，停止处理和生成

- ADD_EXECUTABLE

    语法：
    ```cmake
    ADD_EXECUTABLE(<name> [WIN32] [MACOSX_BUNDLE]
                    [EXCLUDE_FROM_ALL]
                    source1 source2 ... sourceN)
    ```
    用于生成可执行的文件，源文件列表为`SRC_LIST`定义的源文件。在本例中我们使用`${}`来引用变量，这个cmake的变量使用方式。

#### 基本语法规则

本例中使用的基本语法规则有：

1. 变量使用`${}`方式取值，但是在`IF`控制语句中是直接使用变量名
1. COMMAND(param1 param2 ...)，参数间用*空格*或者*分号*分隔

    e.g.
    - ADD(hello-cmake main.c func.c)
    - ADD(hello-cmake main.c;func.c)
1. command是大小写无关的，但是参数和变量是大小写敏感的

#### 内部构建与外部构建

在本例中我们使用的是内部构建，即在`CMakeLists.txt`同级的目录下执行`cmake .`。内部构建会在SOURCE_DIR下生成很多临时的中间文件，不方便删除，也影响的源代码的阅读。

所以我们推荐外部构建，所谓外部构建就是在一个单独的文件夹下面执行cmake，生成的中间文件和结果都在此文件夹下。

对于本例，使用外部构建过程如下：

1. 首先清除test1目录下除`main.c`、`CMakeLists.txt`外的所有文件及文件夹，最关键的是CMakeCache.txt，如果不清除cache，还是会构建到之前的构建目录下。
1. 在test1目录下创建build文件夹
1. 进入build文件夹，执行`cmake ..`(`..`代表上一层目录，即CMakeLists所在的文件夹)
1. 运行make，即可在build文件夹下生成对应的可执行文件

上述过程即为out-of-source外部编译。一个最大的好处是，对于原有的工程没有任何影响，所有动作全部发生在编译目录。

通过外部编译进行工程构建，`PROJECT_SOURCE_DIR`仍然指代工程路径，即CMakeLists所在路径，
而`PROJECT_BINARY_DIR`则指代编译路径，即`/home/workspace/cmake_practice/test1/build`。

#### 小结

本结我们通过一个简单的hello cmake示例，介绍了最基本的CMakeLists编写，以及一些基本的语法和命令用法。同时介绍了内部编译和外部编译，及外部编译的好处。

下一节我们将丰富我们的hello cmake示例，使其看起来更像一个项目。

## 更像一个项目的hello cmake

本节的目标是让上一节的hello cmake更像一个项目，我们接下来要做的是:

1. 为工程添加一个子目录，用来放置项目的源代码
1. 添加一个子目录doc，用来工程文档`hello.txt`
1. 在工程目录添加COPYRIGHT和README
1. 在工程目录添加一个run_hello_cmake.sh脚本，用来调用`hello_cmake`可执行文件
1. 将构建的结果放置构建目录的bin子目录
1. 最终安装这些文件，将`hello_cmake`二进制文件以及`run_hello_cmake.sh`安装至`/usr/bin`目录下，将doc目录下的文件以及COPYRIGHT、README安装至`/usr/share/doc/cmake_practice/test1`目录下

#### 准备工作

在`/home/workspace/cmake_practice`目录下建立`test2`目录，将上一节中的`main.c CMakeLists.txt`拷贝到test2目录

#### 添加子目录src

```shell
mkdir src
mv main.c src
```

现在工程中有一个子目录`src`以及`CMakeLists.txt`。进入子目录，添加CMakeList如下

```cmake
ADD_EXECUTABLE(hello_cmake main.c)
```

将test2工程的CMakeLists修改为

```cmake
PROJECT(hello-cmake)
ADD_SUBDIRECTORY(src bin)
```

然后建立build目录，进入build，执行`cmake .. & make`，构建完成后，目标文件hello-cmake位于`build/bin`目录下。

#### 语法解释

- ADD_SUBDIRECTORY

    语法：
    ```cmake
    ADD_SUBDIRECTORY(source_dir [binary_dir]
                    [EXCLUDE_FROM_ALL])
    ```
    用于向当前工程添加存放源文件的子目录，并可以指定中间二进制和目标二进制存放的位置。

    `EXCLUDE_FROM_ALL`参数的含义是将这个目录从编译过程中排除，比如，工程的`example`，可能需要工程构建完成之后，再进入`example`目录单独进行构建。

上面的例子定义了将src子目录加入工程，并指定了编译输出路径为bin目录。如果不指定bin目录，那么编译的结果都将存放在build/src目录

#### 换个地方保存目标二进制

我们可以通过SET指令重新定义`EXECUTABLE_OUTPUT_PATH`和`LIBRARY_OUTPUT_PATH`变量，来指定最终的目标二进制的位置(指最终生成的 hello_cmake或者最终的共享库，不包含编译生成的中间文件)

```cmake
SET(EXECUTABLE_OUTPUT_PATH ${PROJECT_BINARY_PATH}/bin)
SET(LIBRARY_OUTPUT_PATH ${PROJECT_BINARY_PATH}/lib)
```

在第一节我们提到了`<projectname>_BINARY_DIR`和`PROJECT_BINARY_DIR`变量，他们指的编译发生的当前目录，如果是内部编译，就相当于`PROJECT_SOURCE_DIR`也就是工程代码所在目录，如果是外部编译，指的是外部编译所在目录，也就是本例中的`build`目录。

所以，上面两个指令分别定义了：可执行二进制的输出路径为`build/bin`和库的输出路径为`build/lib`。

至于将这两条指令写在工程的CMakeLists中还是src目录下的CMakeList，只需要按照一个原则：在哪里`ADD_EXECUTABLE`或`ADD_LIBRARY`，如果需要改变目标存放的路径，就在其上加入上述定义。

#### 如何安装

安装的需要有两种，一种是从代码编译后直接`make install`安装，一种是打包时的指定目录安装。

那我们的hello_cmake应该怎么进行安装呢？

这里我们要用到一个新的cmake指令`INSTALL`和一个非常有用的变量`CMAKE_INSTALL_PREFIX`

- `CMAKE_INSTALL_PREFIX`变量类似于configure脚本的--prefix，常见的使用方法形如：

    `cmake -DCMAKE_INSTALL_PREFIX=/usr .`
- `INSTALL`指令用于定义安装规则，安装的内容可以包括
    1. 目标二进制
    1. 动态库
    1. 静态库
    1. 文件、目录、脚本

INSTALL指令包含了各种安装类型，我们需要一个个分开解释

- 目标文件的安装

    语法：
    ```cmake
    install(TARGETS targets...
            [[ARCHIVE|LIBRARY|RUNTIME]
            [DESTINATION <dir>]
            [PERMISSIONS permissions...]
            [CONFIGURATIONS [Debug|Release|...]]
            [COMPONENT <component>]
            [OPTIONAL]
            ] [...])
    ```
    参数中的`TARGETS`后面跟的就是我们通过`ADD_EXECUTABLE`或者`ADD_LIBRARY`定义的目标文件，可能是可执行二进制、动态库、静态库。

    目标类型也就相对应的有三种，`ARCHIVE`特指静态库，`LIBRARY`特指动态库，`RUNTIME`特指可执行目标二进制。

    `DESTINATION`定义了安装的路径，如果路径以/开头，那么指的是绝对路径，这时候`CMAKE_INSTALL_PREFIX`其实就无效了。如果你希望使用`CMAKE_INSTALL_PREFIX`来定义安装路径，就要写成相对路径，即不要以/开头，那么安装后的路径就是`${CMAKE_INSTALL_PREFIX}/<DESTINATION 定义的路径>`

    e.g.

    ```cmake
    install(TARGETS myExe mySharedLib myStaticLib
            RUNTIME DESTINATION bin
            LIBRARY DESTINATION lib
            ARCHIVE DESTINATION lib/static)
    ```

    将会把

    `myExe`安装到`${CMAKE_INSTALL_PREFIX}/bin`
    `mySharedLib`安装到`${CMAKE_INSTALL_PREFIX}/lib`
    `myStaticLib`安装到`${CMAKE_INSTALL_PREFIX}/lib/static`

- 普通文件的安装

    语法：
    ```cmake
    install(FILES files... DESTINATION <dir>
            [PERMISSIONS permissions...]
            [CONFIGURATIONS [Debug|Release|...]]
            [COMPONENT <component>]
            [RENAME <name>] [OPTIONAL])
    ```

    可用于安装一般文件，并可以指定访问权限，文件名是此指令所在路径下的相对路径。如果默认不定义权限`PERMISSIONS`，安装后的权限为：

    `OWNER_WRITE`, `OWNER_READ`, `GROUP_READ`,和 `WORLD_READ`，即 644 权限

- 非目标文件的

    语法：
    ```cmake
    install(PROGRAMS files... DESTINATION <dir>
            [PERMISSIONS permissions...]
            [CONFIGURATIONS [Debug|Release|...]]
            [COMPONENT <component>]
            [RENAME <name>] [OPTIONAL])
    ```

    跟上面的 FILES 指令使用方法一样，唯一的不同是安装后权限为:
`OWNER_EXECUTE`, `GROUP_EXECUTE`, 和 `WORLD_EXECUTE`，即 755 权限

- 目录的安装

    语法：
    ```cmake
    install(DIRECTORY dirs... DESTINATION <dir>
            [FILE_PERMISSIONS permissions...]
            [DIRECTORY_PERMISSIONS permissions...]
            [USE_SOURCE_PERMISSIONS] [OPTIONAL]
            [CONFIGURATIONS [Debug|Release|...]]
            [COMPONENT <component>] [FILES_MATCHING]
            [[PATTERN <pattern> | REGEX <regex>]
            [EXCLUDE] [PERMISSIONS permissions...]] [...])
    ```

    这里主要介绍其中的`DIRECTORY`、`PATTERN`、`PERMISSIONS`参数。

    - DIRECTORY：后面链接的是所在source目录的相对路径。但是abc和abc/有很大区别。如果目录名不以/结尾，那么这个目录将被安装为目标路径下的abc；如果目录名以/结尾，代表将这个目录中的内容安装到目标路径，但不包括这个目录本身。
    - PATTERN：用于使用正则表达式进行过滤，`PERMISSIONS`用于指定PATTERN过滤后的文件权限。

    e.g.
    ```cmake
    INSTALL(DIRECTORY icons scripts/ DESTINATION share/myproj
            PATTERN "CVS" EXCLUDE
            PATTERN "scripts/*"
            PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
                GROUP_EXECUTE GROUP_READ)
    ```
    这条指令的执行结果是：
    将`icons `目录安装到`<prefix>/share/myproj`，将`scripts/`中的内容安装到`<prefix>/share/myproj`不包含目录名为 CVS 的目录，对于 `scripts/*`文件指定权限为OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ.

- 安装时CMAKE脚本的执行

    语法：
    ```cmake
    install([[SCRIPT <file>] [CODE <code>]] [...])
    ```

    SCRIPT参数用于在安装时调用cmake脚本文件（`也就是<abc>.cmake`文件）CODE 参数用于执行CMAKE指令，必须以双引号括起来。比如：
    `INSTALL(CODE "MESSAGE(\"Sample install message.\")")`

#### 让我们的hello cmake支持安装

安装本节开始的要求，下面改写各个目录的CMakeLists

1. 安装COPYRIGHT/README，直接修改主工程文件CMakeLists.txt，加入以下指令：`INSTALL(FILES COPYRIGHT README DESTINATION share/doc/cmake_practice/test2)`
1. 安装`hello_cmake`、`run_hello_cmake.sh`，修改主工程文件CMakeLists.txt，加入以下指令：`INSTALL(PROGRAMS run_hello_cmake.sh DESTINATION bin)`；修改src目录下CMakeLists.txt，加入以下命令：`INSTALL(PROGRAMS ${PROJECT_BINARY_DIR}/bin/hello_cmake DESTINATION bin)`
1. 安装doc中的hello.txt，这里有两种方式：一是通过在 doc 目录建立CMakeLists.txt并将`doc`目录通过`ADD_SUBDIRECTORY`加入工程来完成。另一种方法是直接在工程目录通过`INSTALL(DIRECTORY 来完成)`。我们来尝试后者，顺便演示一下`DIRECTORY`的安装。因为`hello.txt`要安装到`/<prefix>/share/doc/cmake_practice/test2`，所以我们不能直接安装整个doc目录，这里采用的方式是安装doc目录中的内容，也就是使用"doc/"在工程文件中添加`INSTALL(DIRECTORY doc/hello.txt DESTINATION share/doc/cmake_practice/test2)`

如果没有定义`CMAKE_INSTALL_PREFIX`，会默认安装到/usr/local下

#### 小结

本小节主要描述了如何在工程中使用多目录、各种安装指令以及`CMAKE_INSTALL_PREFIX`变量。

在下一小节，我们将探讨如何在cmake中构建动态库和静态库，以及如何使用外部头文件和外部共享库。

## 静态库与动态库

静态库与动态库的创建知识点并不多，主要新引入了一个新的命令如下：

```cmake
ADD_LIBRARY(<name> [STATIC | SHARED | MODULE]
            [EXCLUDE_FROM_ALL]
            source1 source2 ... sourceN)
```

类型有三种：

1. `SHARED` : 动态库
1. `STATIC` : 静态库
1. `MODULE` : 在使用dyld的系统有效，如果不支持dyld，则被当作SHARED对待

`EXCLUDE_FROM_ALL`参数的意思是这个库不会被默认构建，除非有其他的组建依赖或者手工构建

#### 名字相同的动态库和静态库同时存在

在同一个CMake中，如果`ADD_LIBRARY`的target名称相同，则后一个目标会覆盖前一个目标。如果我们想让名字相同的静态库和动态库同时存在，需要用到另外一个命令：

```cmake
SET_TARGET_PROPERTIES(target1 target2 ...
                      PROPERTIES prop1 value1
                      prop2 value2 ...)
```

这条指令可以用来设置输出的名称，对于动态库，还可以用来指定`动态库版本`和`API版本`。

只需要在CMakeLists.txt中加如`SET_TARGET_PROPERTIES(hello_static PROPERTIES OUTPUT_NAME "hello")`，就可以同时得到libhello.a/libhello.so两个库了。

#### 动态库版本号

为了实现动态库版本号，我们仍然需要使用`SET_TARGET_PROPERTIES`指令。具体使用方法：`SET_TARGET_PROPERTIES(hello PROPERTIES VERSION 1.2 SOVERSION 1)`

`VERSION`指代动态库版本，`SOVERSION`指代 API 版本。

加如CMakeLists重新构建，在build目录下会生成：

```shell
libhello.so.1.2
libhello.so.1->libhello.so.1.2
libhello.so ->libhello.so.1
```

#### 安装共享库和头文件

利用上一节提到的`INSTALL`指令，我们将动态库以及静态库安装到指定的目录

```cmake
INSTALL(TARGETS hello hello_static
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)
```

#### 小结

本小节，我们谈到了：

1. 如何通过`ADD_LIBRARY`指令构建动态库和静态库。
1. 如何通过`SET_TARGET_PROPERTIES`同时构建同名的动态库和静态库。
1. 如何通过`SET_TARGET_PROPERTIES`控制动态库版本
1. 最终使用上一节谈到的`INSTALL`指令来安装动态、静态库。

## 如何使用外部共享库和头文件

#### 准备

在`/home/workspace/cmake_practice`目录下建立test4目录，按照上一节，编写CMakeLists，生成自己的hello动态库静态库以及头文件，并安装到/usr/local下。

#### 源文件和CMakeLists

重复以前的步骤，建立`src`目录，编写源文件`main.c`，内容如下：

```c
#include <hello.h>
int main()
{
    print_hello();
    return 0;
}
```

编写工程主文件`CMakeLists.txt`

```cmake
PROJECT(NEWHELLO)
ADD_SUBDIRECTORY(src)
```

编写`src/CMakeLists.txt`

```cmake
ADD_EXECUTABLE(main main.c)
```

#### 外部构建

按照习惯，仍然建立 build 目录，使用 cmake ..方式构建。
过程：

```shell
cmake ..
make
```

构建失败，如果需要查看细节，可以用`make VERBOSE=1`来构建

错误输出是：

```txt
/home/workspace/cmake_practice/test4/src/main.c:1:19: fatal error: hello.h: No such file or directory
```

#### 引入头文件搜索路径

hello.h位于`/usr/local/include/hello`目录中，并没有位于系统标准的头文件路径。

为了让我们的工程能够找到`hello.h`头文件，我们需要引入一个新的指令
`INCLUDE_DIRECTORIES`，其完整语法为：

```cmake
include_directories([AFTER|BEFORE] [SYSTEM] dir1 dir2 ...)
```

这条指令可以用来向工程添加多个特定的头文件搜索路径，路径之间用空格分割，如果路径中包含了空格，可以使用双引号将它括起来，默认的行为是追加到当前的头文件搜索路径的后面。

现在我们在`src/CMakeLists.txt`中添加一个头文件搜索路径，方式很简单，加入：`INCLUDE_DIRECTORIES(/usr/local/include/hello)`

进入build目录，重新进行构建，这时找不到hello.h的错误已经消失，但是出现了一个新的错误：

```txt
main.c:(.text+0xa): undefined reference to `print_hello'
```

因为我们并没有link到共享库libhello上

#### 为target添加共享库

我们现在需要完成的任务是将目标文件链接到libhello，这里我们需要引入两个新的指令：

`LINK_DIRECTORIES`和`TARGET_LINK_LIBRARIES`

LINK_DIRECTORIES的语法是：

```cmake
link_directories(directory1 directory2 ...)
```

这个指令非常简单，添加非标准的共享库搜索路径，比如，在工程内部同时存在共享库和可执行二进制，在编译时就需要指定一下这些共享库的路径。这个例子中我们没有用到这个指令。

TARGET_LINK_LIBRARIES的语法是:

```cmake
TARGET_LINK_LIBRARIES(target library1
                      <debug | optimized> library2
                      ...)
```

这个指令可以用来为`target`添加需要链接的共享库，本例中是一个可执行文件，但是同样可以用于为自己编写的共享库添加共享库链接。

为了解决我们前面遇到的`print_hello`未定义错误，我们需要作的是向
src/CMakeLists.txt中添加如下指令：

```cmake
LINK_DIRECTORIES(/usr/local/lib)
TARGET_LINK_LIBRARIES(main hello)
```

这里的hello指的是我们上一节构建的共享库libhello。

进入build目录重新进行构建。

```shell
cmake ..
make
```

这是我们就得到了一个连接到libhello的可执行程序 main，位于 build/src目录，运行main的结果是输出：

`Hello CMake!`

让我们来检查一下`main`的链接情况：

```shell
[root@localhost src]# ldd main
        linux-vdso.so.1 =>  (0x00007ffdb59ea000)
        libhello.so.1 => /usr/local/lib/libhello.so.1 (0x00007fe24b577000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fe24b18e000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fe24b77a000)
```

可以清楚的看到`main`确实链接了共享库`libhello`，而且链接的是动态库
`libhello.so.1`

那如何链接到静态库呢？方法很简单：将`TARGET_LINK_LIBRRARIES`指令修改为:

`TARGET_LINK_LIBRARIES(main libhello.a)`

重新构建后再来看一下`main`的链接情况

```shell
[root@localhost src]# ldd main
        linux-vdso.so.1 =>  (0x00007fffa2597000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fb216c97000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fb217080000)
```

说明`main`确实链接到了静态库`libhello.a`。

#### 小结

本节我们探讨了:

- 如何通过`INCLUDE_DIRECTORIES`指令加入非标准的头文件搜索路径。
- 如何通过`LINK_DIRECTORIES`指令加入非标准的库文件搜索路径。
- 如果通过`TARGET_LINK_LIBRARIES`为库或可执行二进制加入库链接。

到这里为止，您应该基本可以使用`cmake`工作了，但是还有很多高级的话题没有探讨，比如**编译条件检查**、**编译器定义**、**平台判断**等等。

到这里，或许你可以理解前面讲到的“cmake的使用过程其实就是学习cmake语言并编写cmake程序的过程”，既然是“cmake语言”，自然涉及到变量、语法等。

下一节，我们将抛开程序的话题，看看常用的CMAKE变量以及一些基本的控制语法规则。

## CMake常用变量和常用环境变量

使用`${}`进行变量的引用。在IF等语句中，是直接使用变量名而不通过`${}`取值。

#### CMake常用变量

- `CMAKE_BINARY_DIR`

    `PROJECT_BINARY_DIR`

    `<projectname>_BINARY_DIR`

    这三个变量指代的内容是一致的，如果是`in source`编译，指得就是工程顶层目录，如果是`out-of-source`编译，指的是工程编译发生的目录。`PROJECT_BINARY_DIR`跟其他指令稍有区别，现在，你可以理解为他们是一致的。

- `CMAKE_SOURCE_DIR`

    `PROJECT_SOURCE_DIR`

    `<projectname>_SOURCE_DIR`

    这三个变量指代的内容是一致的，不论采用何种编译方式，都是工程顶层目录。也就是在`in source`编译时，他跟`CMAKE_BINARY_DIR`等变量一致。`PROJECT_SOURCE_DIR`跟其他指令稍有区别，现在，你可以理解为他们是一致的。

- `CMAKE_CURRENT_SOURCE_DIR`

指的是当前处理的`CMakeLists.txt`所在的路径，比如上面我们提到的src子目录。

- `CMAKE_CURRRENT_BINARY_DIR`

如果是`in-source`编译，它跟`CMAKE_CURRENT_SOURCE_DIR`一致，如果是`out-ofsource`编译，他指的是`target`编译目录。使用我们上面提到的`ADD_SUBDIRECTORY(src bin)`可以更改这个变量的值。
使用`SET(EXECUTABLE_OUTPUT_PATH <新路径>)`并不会对这个变量造成影响，它仅仅修改了最终目标文件存放的路径。

- `CMAKE_MODULE_PATH`

这个变量用来定义自己的 cmake 模块所在的路径。如果你的工程比较复杂，有可能会自己编写一些 cmake 模块，这些 cmake 模块是随你的工程发布的，为了让 cmake 在处理CMakeLists.txt 时找到这些模块，你需要通过 SET 指令，将自己的 cmake 模块路径设置一下。
比如

```cmake
SET(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)
```

这时候你就可以通过`INCLUDE`指令来调用自己的模块了。

#### CMake调用环境变量

使用`$ENV{NAME}`指令就可以调用系统的环境变量了。

比如

```cmake
MESSAGE(STATUS "HOME dir: $ENV{HOME}")
```

设置环境变量的方式是：

`SET(ENV{KEY} VALUE)`

#### 主要开关选项

- `BUILD_SHARED_LIBS`

这个开关用来控制默认的库编译方式，如果不进行设置，使用 ADD_LIBRARY并没有指定库类型的情况下，默认编译生成的库都是静态库。
如果`SET(BUILD_SHARED_LIBS ON)`后，默认生成的为动态库。

- `CMAKE_C_FLAGS`

设置C编译选项，也可以通过指令`ADD_DEFINITIONS()`添加。

- `CMAKE_CXX_FLAGS`

设置C++编译选项，也可以通过指令`ADD_DEFINITIONS()`添加。

## CMake常用指令

#### 基本指令

- `ADD_DEFINITIONS`

向C/C++编译器添加-D定义，比如:`ADD_DEFINITIONS(-DENABLE_DEBUG -DABC)`，参数之间用空格分割。如果你的代码中定义了`#ifdef ENABLE_DEBUG #endif`，这个代码块就会生效。如果要添加其他的编译器开关，可以通过`CMAKE_C_FLAGS`变量和`CMAKE_CXX_FLAGS`变量设置

- `ADD_DEPENDENCIES`

定义target依赖的其他target，确保在编译本target之前，其他的 target 已经被构建。

```cmake
ADD_DEPENDENCIES(target-name depend-target1
                 depend-target2 ...)
```

- `ADD_TEST`与`ENABLE_TESTING`

`ENABLE_TESTING`指令用来控制Makefile是否构建test目标，涉及工程所有目录。语法很简单，没有任何参数，ENABLE_TESTING()，一般情况这个指令放在工程的主CMakeLists.txt中。

`ADD_TEST`指令的语法是:`ADD_TEST(testname Exename arg1 arg2 ...)`

testname是自定义的test名称，Exename可以是构建的目标文件也可以是外部脚本等等。后面连接传递给可执行文件的参数。如果没有在同一个CMakeLists.txt 中打开`ENABLE_TESTING()`指令，任何`ADD_TEST`都是无效的。

比如我们前面的Helloworld例子，可以在工程主CMakeLists.txt 中添加

```cmake
ADD_TEST(mytest ${PROJECT_BINARY_DIR}/bin/main)
ENABLE_TESTING()
```

生成`Makefile`后，就可以运行`make test`来执行测试了。

- `AUX_SOURCE_DIRECTORY`

基本语法：`AUX_SOURCE_DIRECTORY(dir VARIABLE)`

作用是发现一个目录下所有的源代码文件并将列表存储在一个变量中，这个指令临时被用来自动构建源文件列表。因为目前 cmake 还不能自动发现新添加的源文件。

比如

```cmake
AUX_SOURCE_DIRECTORY(. SRC_LIST)
ADD_EXECUTABLE(main ${SRC_LIST})
```

你也可以通过后面提到的`FOREACH`指令来处理这个`LIST`

- `CMAKE_MINIMUM_REQUIRED`

其语法为`CMAKE_MINIMUM_REQUIRED(VERSION versionNumber [FATAL_ERROR])` 比如 `CMAKE_MINIMUM_REQUIRED(VERSION 2.5 FATAL_ERROR)` 如果cmake版本小与 2.5，则出现严重错误，整个过程中止。

- `EXEC_PROGRAM`

在CMakeLists.txt处理过程中执行命令，并不会在生成的Makefile中执行。具体语法为：

```cmake
EXEC_PROGRAM(Executable [directory in which to run]
            [ARGS <arguments to executable>]
            [OUTPUT_VARIABLE <var>]
            [RETURN_VALUE <var>])

```

用于在指定的目录运行某个程序，通过ARGS添加参数，如果要获取输出和返回值，可通过`OUTPUT_VARIABLE`和`RETURN_VALUE`分别定义两个变量。

这个指令可以帮助你在`CMakeLists.txt`处理过程中支持任何命令，比如根据系统情况去修改代码文件等等。

举个简单的例子，我们要在src目录执行ls命令，并把结果和返回值存下来。

可以直接在src/CMakeLists.txt中添加：

```cmake
EXEC_PROGRAM(ls ARGS "*.c" OUTPUT_VARIABLE LS_OUTPUT RETURN_VALUE LS_RVALUE)
IF(not LS_RVALUE)
    MESSAGE(STATUS "ls result: " ${LS_OUTPUT})
ENDIF(not LS_RVALUE)
```

在cmake生成Makefile的过程中，就会执行ls命令，如果返回0，则说明成功执行，那么就输出 ls *.c 的结果。关于IF语句，后面的控制指令会提到。

- `FILE`

    - FILE(WRITE filename "message to write"... )
    - FILE(APPEND filename "message to write"... )
    - FILE(READ filename variable)
    - FILE(GLOB variable [RELATIVE path] [globbing expressions]...)
    - FILE(GLOB_RECURSE variable [RELATIVE path] [globbing expressions]...)
    - FILE(REMOVE [directory]...)
    - FILE(REMOVE_RECURSE [directory]...)
    - FILE(MAKE_DIRECTORY [directory]...)
    - FILE(RELATIVE_PATH variable directory file)
    - FILE(TO_CMAKE_PATH path result)
    - FILE(TO_NATIVE_PATH path result)

这里的语法都比较简单，不在展开介绍了。

- `INCLUDE`

用来载入CMakeLists.txt文件，也用于载入预定义的cmake模块。

```cmake
INCLUDE(file1 [OPTIONAL])
INCLUDE(module [OPTIONAL])
```

OPTIONAL参数的作用是文件不存在也不会产生错误。你可以指定载入一个文件，如果定义的是一个模块，那么将在`CMAKE_MODULE_PATH`中搜索这个模块并载入。载入的内容将在处理到INCLUDE语句是直接执行。

- `FILE_`指令

    - FIND_FILE(<VAR> name1 path1 path2 ...)

        VAR 变量代表找到的文件全路径，包含文件名

    - FIND_LIBRARY(<VAR> name1 path1 path2 ...)

        VAR 变量表示找到的库全路径，包含库文件名

    - FIND_PATH(<VAR> name1 path1 path2 ...)

        VAR 变量代表包含这个文件的路径。

    - FIND_PROGRAM(<VAR> name1 path1 path2 ...)

        VAR 变量代表包含这个程序的全路径。

    - FIND_PACKAGE(<name> [major.minor] [QUIET] [NO_MODULE] [[REQUIRED|COMPONENTS] [componets...]])

        用来调用预定义在 CMAKE_MODULE_PATH 下的 Find<name>.cmake 模块，你也可以自己定义`Find<name>`模块，通过`SET(CMAKE_MODULE_PATH dir)`将其放入工程的某个目录中供工程使用，我们在后面的章节会详细介绍`FIND_PACKAGE`的使用方法和`Find`模块的编写。

        FIND_LIBRARY 示例：

        ```cmake
        FIND_LIBRARY(libX X11 /usr/lib)
        IF(NOT libX)
            MESSAGE(FATAL_ERROR “libX not found”)
        ENDIF(NOT libX)
        ```

#### 控制命令

- `IF`

```cmake
IF(expression)
    # THEN section.
    COMMAND1(ARGS ...)
    COMMAND2(ARGS ...)
    ...
ELSE(expression)
    # ELSE section.
    COMMAND1(ARGS ...)
    COMMAND2(ARGS ...)
    ...
ENDIF(expression)
```

另外一个指令是`ELSEIF`，总体把握一个原则，凡是出现IF的地方一定要有对应的ENDIF。出现 ELSEIF 的地方，ENDIF是可选的。

表达式的使用方法如下:

IF(var)，如果变量不是：空，0，N, NO, OFF, FALSE, NOTFOUND 或
<var>_NOTFOUND 时，表达式为真。

IF(NOT var )，与上述条件相反。

IF(var1 AND var2)，当两个变量都为真是为真。

IF(var1 OR var2)，当两个变量其中一个为真时为真。

IF(COMMAND cmd)，当给定的 cmd 确实是命令并可以调用是为真。

IF(EXISTS dir)或者 IF(EXISTS file)，当目录名或者文件名存在时为真。

IF(file1 IS_NEWER_THAN file2)，当 file1 比 file2 新，或者 file1/file2 其中有一个不存在时为真，文件名请使用完整路径。

IF(IS_DIRECTORY dirname)，当 dirname 是目录时，为真。

IF(variable MATCHES regex)

IF(string MATCHES regex)
当给定的变量或者字符串能够匹配正则表达式 regex 时为真。比如：

```cmake
IF("hello" MATCHES "ell")
    MESSAGE("true")
ENDIF("hello" MATCHES "ell")
```

数字比较表达式:

- IF(variable LESS number)
- IF(string LESS number)
- IF(variable GREATER number)
- IF(string GREATER number)
- IF(variable EQUAL number)
- IF(string EQUAL number)

按照字母序的排列进行比较:

- IF(variable STRLESS string)
- IF(string STRLESS string)
- IF(variable STRGREATER string)
- IF(string STRGREATER string)
- IF(variable STREQUAL string)
- IF(string STREQUAL string)

IF(DEFINED variable)，如果变量被定义，为真。

一个小例子，用来判断平台差异：

```cmake
IF(WIN32)
    MESSAGE(STATUS “This is windows.”)
    #作一些 Windows 相关的操作
ELSE(WIN32)
    MESSAGE(STATUS “This is not windows”)
    #作一些非 Windows 相关的操作
ENDIF(WIN32)
```

上述代码用来控制在不同的平台进行不同的控制，但是，阅读起来却并不是那么舒服，ELSE(WIN32)之类的语句很容易引起歧义。

这就用到了我们在“常用变量”一节提到的`CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS`开
关。可以`SET(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)`
这时候就可以写成:

```cmake
IF(WIN32)
ELSE()
ENDIF()
```

如果配合 ELSEIF 使用，可能的写法是这样:

```cmake
IF(WIN32)
    #do something related to WIN32
ELSEIF(UNIX)
    #do something related to UNIX
ELSEIF(APPLE)
    #do something related to APPLE
ENDIF(WIN32)
```

- `WHILE`

WHILE 指令的语法是：

```cmake
WHILE(condition)
    COMMAND1(ARGS ...)
    COMMAND2(ARGS ...)
    ...
ENDWHILE(condition)
```

其真假判断条件可以参考 IF 指令。

- `FOREACH`

FOREACH 指令的使用方法有三种形式：

1. 列表

    ```cmake
    FOREACH(loop_var arg1 arg2 ...)
        COMMAND1(ARGS ...)
        COMMAND2(ARGS ...)
        ...
    ENDFOREACH(loop_var)
    ```

    像我们前面使用的`AUX_SOURCE_DIRECTORY`的例子

    ```cmake
    AUX_SOURCE_DIRECTORY(. SRC_LIST)
    FOREACH(F ${SRC_LIST})
        MESSAGE(${F})
    ENDFOREACH(F)
    ```

1. 范围

    ```cmake
    FOREACH(loop_var RANGE total)
    ENDFOREACH(loop_var)
    ```

    从 0 到 total 以1为步进

    举例如下：

    ```cmake
    FOREACH(VAR RANGE 10)
    MESSAGE(${VAR})
    ENDFOREACH(VAR)
    最终得到的输出是：
    0
    1
    2
    3
    4
    5
    6
    7
    8
    9
    10
    ```

1. 范围和步进

```cmake
FOREACH(loop_var RANGE start stop [step])
ENDFOREACH(loop_var)
```

从start开始到stop结束，以step为步进，举例如下:

```cmake
FOREACH(A RANGE 5 15 3)
    MESSAGE(${A})
ENDFOREACH(A)
```

最终得到的结果是：5 8 11 14

这个指令需要注意的是，知道遇到`ENDFOREACH`指令，整个语句块才会得到真正的执行。

## 模块的使用和自定义模块

本章我们将着重介绍系统预定义的`Find`模块的使用以及自己编写`Find`模块，系统中提供了其他各种模块，一般情况需要使用`INCLUDE`指令显式的调用，`FIND_PACKAGE`指令是一个特例，可以直接调用预定义的模块。

在本章，我们基于我们前面的libhello共享库，编写一个FindHello.cmake模块。

对于系统预定义的`Find<name>.cmake`模块，每一个模块都会定义以下几个变量：

- `<name>_FOUND`
- `<name>_INCLUDE_DIR` or `<name>_INCLUDES`
- `<name>_LIBRARY` or `<name>_LIBRARIES`

你可以通过`<name>_FOUND`来判断模块是否被找到，如果没有找到，按照工程的需要关闭某些特性、给出提醒或者中止编译。

如果`<name>_FOUND`为真，则将`<name>_INCLUDE_DIR`加入`INCLUDE_DIRECTORIES`，将`<name>_LIBRARY`加入 `TARGET_LINK_LIBRARIES`中。

#### 编写FindHello模块

我们在此前的test3实例中，演示了构建动态库、静态库的过程并进行了安装。接下来，我们在test6示例中演示如何自定义`FindHello`模块并使用这个模块构建工程：

请在建立`/home/workspace/cmake_practice`中建立test6目录，并在其中建立cmake目录用于存放我们自己定义的`FindHello.cmake`模块，同时建立`src`目录，用于存放我们的源文件。

定义`cmake/FindHello.cmake`模块

```cmake
FIND_PATH(HELLO_INCLUDE_DIR hello.h /usr/local/include/hello /usr/include/hello)
FIND_LIBRARY(HELLO_LIBRARY NAMES hello PATH /usr/local/lib /usr/lib)
IF(HELLO_INCLUDE_DIR AND HELLO_LIBRARY)
        SET(HELLO_FOUND TRUE)
ENDIF()
IF(HELLO_FOUND)
        IF(NOT Hello_FIND_QUIETLY)
                MESSAGE(STATUS "Found Hello: ${HELLO_LIBRARY}")
        ENDIF()
ELSE()
        IF(Hello_FIND_REQUIRED)
                MESSAGE(FATAL_ERROR "Cound not find hello library")
        ENDIF()
ENDIF()
```

`QUIET`参数，对应与我们编写的`FindHello`中的 `HELLO_FIND_QUIETLY`，如果不指定这个参数，就会执行：
`MESSAGE(STATUS "Found Hello: ${HELLO_LIBRARY}")`

`REQUIRED`参数，其含义是指这个共享库是否是工程必须的，如果使用了这个参数，说明这个链接库是必备库，如果找不到这个链接库，则工程不能编译。对应于`FindHello.cmake`模块中的`HELLO_FIND_REQUIRED`变量。
同样，我们在上面的模块中定义了`HELLO_FOUND`,`HELLO_INCLUDE_DIR`,`HELLO_LIBRARY`变量供开发者在`FIND_PACKAGE`指令中使用。

在src/main.c中写入如下内容：

```c
#include <hello.h>
int main()
{
        print_hello();
        return 0;
}
```

建立src/CMakeLists.txt文件，内容如下：

```cmake
FIND_PACKAGE(Hello)
IF(HELLO_FOUND)
        ADD_EXECUTABLE(hello main.c)
        INCLUDE_DIRECTORIES(${HELLO_INCLUDE_DIR})
        TARGET_LINK_LIBRARIES(hello ${HELLO_LIBRARY})
ENDIF(HELLO_FOUND)
```

为了能够让工程找到`FindHello.cmake`模块(存放在工程中的cmake目录)我们在主工程文件CMakeLists.txt中加入：
`SET(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)`

仍然采用外部编译的方式，建立build目录，进入目录运行：

```shell
cmake ..
```

我们可以从输出中看到：

```txt
-- Found Hello: /usr/local/lib/libhello.so
```

如果没有找到hello library呢？

我们可以尝试将/usr/local/lib/libhello.x 移动到/tmp目录，这样，按照FindHello模块的定义，就找不到hello library了，我们再来看一下构建结果：

```shell
cmake ..
```

仍然可以成功进行构建，但是这时候是没有办法编译的。修改 `FIND_PACKAGE(HELLO)`为`FIND_PACKAGE(HELLO REQUIRED)`，将 hello library定义为工程必须的共享库。

这时候再次运行 cmake ..

我们得到如下输出：

`CMake Error: Could not find hello library.`

因为找不到libhello.x，所以，整个Makefile生成过程被出错中止。