extends Node

class_name gudp

signal onMessage

signal onReceiveConfirmationMessage(ack:int)
signal onReceiveMessage(bytes: PackedByteArray)
signal on_receive_msg()

const apiProto = preload("./protos/gudp.gd")

var connected = false
var session_id :PackedByteArray
var socket : PacketPeerUDP
var reliability : Reliability = Reliability.new()

static func NewClient(ip:String,port:int):
	return  GUDPClient.new(ip, port)

func Login(username:String):
	pass
	
# 发送握手消息
func sendHandMessage(bytes:PackedByteArray):
	var mytype = PackedByteArray([apiProto.gudp_message_type.HANDSHAKEMESSAGE])
	var data = mytype + bytes
	socket.put_packet(data)


# 计算校验合
func Crc32ChecksumIEEE(data:String) -> int:
	var checksum = crc32.new().fCRC32(data)
	return checksum
	
