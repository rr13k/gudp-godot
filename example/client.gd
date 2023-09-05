extends Node

var gudpClient:GUDPClient

func _ready():
	gudpClient = gudp.NewClient("127.0.0.1", 12345)
	gudpClient.onReceiveMessage.connect(record)

func _process(_deal):
    # must!
	gudpClient.onRecord()
	
# on server send msg~
func record(resp:PackedByteArray):
	print("接收到了消息", resp)

func Login(username:String, password:String):
    gudpClient.SendMessage("ad22")
	pass
	