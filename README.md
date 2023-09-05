# gudp-godot

## 介绍

`gudp` `godot`客户端库, 提供可靠`udp` 和 `rpc`等功能。

## 安装方法

在`godot`插件目录`addons`使用`git clone` 该仓库即可

```sh
# 进入项目目录
cd addons

git clone  https://github.com/rr13k/gudp-godot.git
```

## 使用方法

```js

extends Node

class_name gudp_client

var gudpClient:GUDPClient

func _ready():
	gudpClient = gudp.NewClient("127.0.0.1", 12345)
	gudpClient.sceneTree = get_tree() # must
	gudpClient.onReceiveMessage.connect(record)

func _process(_deal):
	gudpClient.onRecord()

func record(resp:PackedByteArray):
	print("on recv msg:", resp)

    var data = PackedByteArray(["hi"])
    # 发送可靠消息
    var res = await gudpClient.SendMessage(data)
    if !res:
		print("发送可靠信息失败")

    # 发送不可靠消息
    # gudpClient.SendMessage(data,false)

    # 调用rpc函数
    var res2 = await gudpClient.RpcCall("Multiply",{"A":2,"B":3})
	print("res2:",res2)
```