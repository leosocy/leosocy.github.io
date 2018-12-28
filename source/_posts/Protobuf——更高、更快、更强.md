---
title: Protobuf——更高、更快、更强
copyright: true
date: 2018-12-15 17:30:30
photos:
- https://blog-images-1257621236.cos.ap-shanghai.myqcloud.com/protobuf.png
tags:
- 序列化
categories:
- serializer
---

Protobuf（全称Protocol Buffers）用于序列化数据结构，描述数据组织结构，支持大部分目前流行的语言。相较于XML，Protobuf使用更简单，清晰，序列化后的数据占用空间小3\~10倍，解析速度快20\~100倍。

<!-- more -->

## PB3语法

### 定义message

#### 基本格式

```protobuf
syntax = "proto3";

package = test_message;

message MessageName {
    [FieldRule] FieldType FieldName = FieldNumber; //Comment
}
```

- 第一行指定使用的是`proto3`语法。不指定则默认使用`proto2`的语法。
- `package`用于防止使用不同的proto文件时，消息或者服务冲突。

#### FieldType

可以使用标准类型，也可以使用自定义的字段类型，包括`枚举`和`其他消息类型`

##### Scalar Value Types

|.proto Type|Notes|Python Type|C++Type|
|:---------:|:---:|:---------:|:-----:|
|double     |     |float      |double |
|float      |     |float      |float  |
|int32      |使用变长编码。编码负数的效率很低，如果字段可能有负值，则使用`sint32`代替|int|int32|
|int64      |使用变长编码。如果字段可能有负值，则使用`sint64`代替|int|int64|
|uint32|使用变长编码|int/long|uint32|
|uint64|使用变长编码|int/long|uint64|
|sint32|使用变长编码，比`int32`更有效的编码负数|int|int32|
|sint64|使用变长编码，比`int64`更有效的编码负数|int/long|int64|
|fixed32|总是4字节。如果值通常大于pow(2, 28)，则比`uint32`更有效|int|uint32|
|fixed64|总是8字节。如果值通常大于pow(2, 58)，则比`uint64`更有效|int/long|uint64|
|sfixed32|总是使用4字节|int|int32|
|sfixed64|总是使用8字节|int/long|int64|
|bool| |bool|bool|
|string|字符串必须始终包含UTF-8编码或7位ASCII文本|str/unicode|string|
|bytes|可以包含任意字节序列|str|BytesString|

##### Enumerations

举例

```protobuf
message SearchRequest {
  string query = 1;
  int32 page_number = 2;
  int32 result_per_page = 3;
  enum Corpus {
    UNIVERSAL = 0;
    WEB = 1;
    IMAGES = 2;
    LOCAL = 3;
    NEWS = 4;
    PRODUCTS = 5;
    VIDEO = 6;
  }
  Corpus corpus = 4;
}
```

注意，枚举的第一个值**必须是0**。

如果想通过为不同的enum常量分配相同的值来定义别名，需要在枚举中设置`option allow_alias = true;`

e.g.

```protobuf
enum EnumAllowingAlias {
  option allow_alias = true;
  UNKNOWN = 0;
  STARTED = 1;
  RUNNING = 1;
}
```

#### Field Numbers

消息定义中的每个字段都有唯一的编号。其中，1\~15编码时占用1字节，16\~2047占用2字节，以此类推，Field Number范围为1\~pow(2, 29)-1。不用使用protobuf的`系统保留编号（19000~19999）`以及消息中定义的`保留编号`

#### Field Rules

- singular:一个格式良好的消息可以有这个字段的零或一个(但不多于一个)。
- repeated:此字段可以在格式良好的消息中重复任意次数(包括零次)。重复值的顺序将被保留。

#### 

和C/C++注释的方法相同，使用`//`或者`/*...*/`注释

#### Reserved Fields

如果一个字段被删除或注释掉，未来的用户可以在更新类型时重用字段号。如果以后加载相同.proto的旧版本，则会导致严重的问题(包括数据损坏、隐私bug等)。确保不会发生这种情况的一种方法是指定已删除字段的字段号(和/或名称，这也可能导致JSON序列化问题)`reserved`。如果将来的用户试图使用这些字段标识符，protobuf编译器将会报错。

```protobuf
message Foo {
    reserved 5, 7;
    reserved "type";
}
```

注意，不能在同一个保留语句中混合字段名和字段号。e.g.`reserved 5, "type"`

#### import

可以通过导入其他.proto文件使用定义。要导入另一个.proto的定义，请在文件顶部添加一条import语句:

```protobuf
import "myproject/other_protos.proto";
```

`import public`可以将所有导入转发到对应的proto文件中，这个特性可以用于proto文件的迁移。

#### 嵌套定义

类似于C/C++中的结构体，proto也支持嵌套定义message

```protobuf
message SearchResponse {
  message Result {
    string url = 1;
    string title = 2;
    repeated string snippets = 3;
  }
  repeated Result results = 1;
}
```

如果想在另一个message中使用Result，需要指定子message的完整路径

```protobuf
message SomeOtherMessage {
    SearchResponse.Result result = 1;
}
```

#### 如何更新正在使用的message

如果需要修改已经在使用的message，例如增加额外的字段，需要注意一下几点才不会破坏现有的代码：

- 不要更改任何现有字段的字段编号。
- 如果您添加了新的字段，那么使用您的“旧”消息格式序列化的任何消息仍然可以通过您的新生成的代码进行解析。您应该记住这些元素的默认值，以便新代码可以与旧代码生成的消息进行适当的交互。类似地，新代码创建的消息可以通过旧代码进行解析:旧二进制文件在解析时忽略新字段。
- 字段可以被删除，只要在更新的消息类型中不再使用字段编号。您可能希望重命名该字段，可能添加前缀“OBSOLETE_”，或者保留字段号，以便.proto的未来用户不会意外地重用该数字。
- int32、uint32、int64、uint64和bool都是兼容的——这意味着您可以在不破坏向前或向后兼容性的情况下将字段从这些类型之一更改为另一个类型。如果从不适合相应类型的连接中解析一个数字，您将得到与在c++中将该数字转换为该类型相同的效果(例如，如果一个64位的数字被读为int32，那么它将被截断为32位)。
- sint32和sint64相互兼容，但与其他整数类型不兼容。
- 字符串和字节是兼容的，只要字节是有效的UTF-8。
- 如果字节包含消息的编码版本，则嵌入的消息与字节兼容。
- fixed32与sfixed32兼容，sfixed64与sfixed64兼容。

#### Unknown Field

Unknown Field表示解析器无法识别的字段。例如，当一个旧的二进制文件解析由一个新二进制文件发送的带有新字段的数据时，这些新字段就成为旧二进制文件中的未知字段。

Proto3实现可以成功地解析带有未知字段的消息，但是，实现可能支持也可能不支持保存这些未知字段。您不应该依赖于被保存或删除的未知字段。对于大多数protobuf实现，在proto3中无法通过相应的proto运行时访问未知字段，并且在反序列化时被删除和遗忘。

#### Oneof

Oneof类似于C中的union。如果您有一个包含多个字段的消息，并且最多同时设置一个字段，那么您可以使用oneof特性强制执行此行为并保存内存。

除了共享内存中的所有字段外，其中一个字段类似常规字段，最多可以同时设置一个字段。设置oneof的任何成员将自动清除所有其他成员。您可以使用一个特殊的case()或哪个of()方法，根据您所选择的语言，检查其中一个值的设置(如果有的话)。

##### 使用Oneof

```protobuf
message SampleMessage {
  oneof test_oneof {
    string name = 4;
    SubMessage sub_message = 9;
  }
}
```

oneof中可以添加任何类型的字段，但不能使用repeated。

##### 特点

- 设置oneof字段的一个成员将自动清除该字段所有其他成员。因此，如果设置了几个成员的值，那么只有最后一个成员具有值。
- 如果解析器在连接中遇到同一成员的多个成员，则在解析消息中只使用最后一个成员。
- oneof不能被`repeated`修饰

#### Maps

```protobuf
map<key_type, value_type> map_field = N;
```

`key_type`可以是任何`integral`或`string`(因此，除了浮点类型和字节之外的任何标量类型)。注意，enum不是一个有效的`key_type`。`value_type`可以是除其`map`之外的任何类型。

##### 特点

- map字段不能是`repeated`
- 在为.proto生成文本格式时，映射是按键排序的。数字键按数字排序。
- 当编码时，如果有重复的映射键，则使用最后一个键。当解码时，如果有重复的键，解析可能失败。
- 如果只提供了map的key，没有提供value，那么value_type的默认值将会被序列化。

#### Packages

用于防止消息类型冲突。使用举例

bar.proto
```protobuf
package foo.bar;
message Open {...}
```

```protobuf
import "bar.proto"
message Foo {
  foo.bar.Open open = 1;
}
```

包说明符影响生成代码的方式取决于您选择的语言:

- 在C++中，生成的class在C++的namespace中。例如`Open`会在foo::bar明明空间下。
- 在Java中，package被用作Java包，除非在proto文件中显示的定义了`option java_package`
- 在Python中，包指令被忽略，因为Python模块是根据它们在文件系统中的位置来组织的。
- 在Go中，package被用作Go的包名，除非在proto文件中显示的定义了`option go_package`

### 定义Services

如果您想在RPC(Remote Procedure Call)系统中使用您的消息类型，您可以在.proto文件中定义一个RPC服务接口，protobuf编译器将用您选择的语言生成service interface和stubs。因此，例如，如果您想用获取`SearchRequest`并返回`SearchResponse`的方法定义一个RPC服务，您可以在.proto文件中定义它，如下所示: 

```protobuf
service SearchService {
  rpc Search(SearchReq) returns (SearchRes);    
}
```

与protobuf一起使用的最直接的RPC系统是gRPC:在谷歌开发的与语言和平台无关的开放源码RPC系统。gRPC在协议缓冲区中工作得特别好，允许您使用特殊的protobuf编译器插件直接从.proto文件生成相关的RPC代码。

当然，也可以使用其他的RPC框架（rpcx、go std rpc等等）

### JSON Mapping

如果一个值在json编码的数据中丢失，或者它的值为`null`，那么在解析到protobuf时，它将被解释为适当的***默认值***。如果一个字段在protobuf中具有默认值，则默认情况下将在json编码的数据中省略该字段以节省空间。

[具体映射关系](https://developers.google.com/protocol-buffers/docs/proto3#JSON%20Mapping)

### Options

一些选项是文件级选项，这意味着它们应该在顶级范围内编写，而不是在任何消息、枚举或服务定义中。有些选项是消息级别的选项，这意味着它们应该写在消息定义中。有些选项是字段级选项，这意味着它们应该写在字段定义中。选项也可以写在枚举类型、枚举值、服务类型和服务方法上;但是，目前没有任何有用的选项。

- `java_package` (file选项):您希望为生成的Java类使用的包。如果.proto文件中没有给出明确的java_package选项，那么默认情况下将使用proto包(使用.proto文件中的“package”关键字指定)。但是，proto包通常不会成为好的Java包，因为预计proto包不会以反向域名开始。如果不生成Java代码，则此选项无效。
- `optimize_for` (file选项):可以设置为SPEED、CODE_SIZE或LITE_RUNTIME。这将以以下方式影响c++和Java代码生成器(可能还有第三方生成器):
    - `SPEED`(默认):protobuf编译器将生成用于序列化、解析和执行消息类型的其他常见操作的代码。这段代码是高度优化的。
    - `CODE_SIZE`:protobuf编译器将生成最小的类，并将依赖于共享的、基于反射的代码来实现序列化、解析和各种其他操作。因此生成的代码会比速度小得多，但是操作会更慢。类仍然会实现与在SPEED模式下完全相同的公共API。在包含大量.proto文件的应用程序中，这种模式最有用，而且不需要所有文件都非常快。
    - `LITE_RUNTIME`:protobuf编译器将生成仅依赖于“lite”运行时库(libprotobuf-lite而不是libprotobuf)的类。lite运行时比完整的库要小得多(大约一个数量级)，但是忽略了某些特性，比如描述符和反射。这对于在移动电话等受限平台上运行的应用程序尤其有用。编译器仍然会生成所有方法的快速实现，就像在SPEED模式中那样。生成的类只会在每种语言中实现MessageLite接口，它只提供完整消息接口方法的一个子集。
- `deprecated`:如果设置为true，表明该字段已被弃用，新代码不应使用该字段。在大多数语言中，这没有实际效果。在Java中，这成为一个@Deprecated注释。将来，其他特定于语言的代码生成器可能会在字段的访问器上生成弃用注释，这反过来会导致编译试图使用该字段的代码时发出警告。如果任何人都不使用字段，并且希望防止新用户使用该字段，请考虑使用`reserved`。

### Generating Classes

要生成Java、Python、c++、Go、Ruby、Objective-C或C#代码，您需要使用.proto文件中定义的消息类型，您需要在.proto文件上运行protobuf编译器protoc。如果您还没有安装编译器，请[下载这个包](https://developers.google.com/protocol-buffers/docs/downloads)并遵循README中的说明。对于Go，您还需要为编译器安装一个特殊的代码生成器插件:您可以在GitHub上的[golang/protobuf](https://github.com/golang/protobuf/)存储库中找到这个和安装说明。

编译器调用如下:

```shell
protoc --proto_path=IMPORT_PATH --cpp_out=DST_DIR --java_out=DST_DIR --python_out=DST_DIR --go_out=DST_DIR --ruby_out=DST_DIR --objc_out=DST_DIR --csharp_out=DST_DIR path/to/file.proto
```

或者可以安装python gPRC tools
```shell
pip install grpcio-tools
python -m grpc_tools.protoc -I../../protos --python_out=. --grpc_python_out=. ../../protos/helloworld.proto
```
其中：

- `-I`和`--proto_path`相同，表示proto文件的搜索路径 
- `--python_out`表示`*_pb2.py`生成的路径，该文件包含自动生成的`request`和`response`类
- `--grpc_python_out`表示`*_pb2_grpc.py`生成的路径，该文件包含自动生成的`client`和`class`类
