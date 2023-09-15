extends Node

class_name Reliability

# 最大的seq
@export var maxSequence: int = 4096
# 本地的seq
@export var localSequence :int
# 远程传递过来的seq
@export var remoteSequence :int

var sentPackets : int  #// total number of packets sent
var recvPackets  :int # total number of packets received
var lostPackets  :int # total number of packets lost
var ackedPackets :int # total number of packets acked

var receivedQueue: PacketQueue = PacketQueue.new() # 回复确认队列
var sentQueue: PacketQueue = PacketQueue.new() # 发送队列
var pendingAckQueue: PacketQueue = PacketQueue.new() # 等待验证队列
var ackedQueue: PacketQueue = PacketQueue.new() # 已验证队列

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func GetSentPacket(seq:int) -> PacketQueue.PacketData:
	var packet
	for sent in sentQueue.queue:
		if sent.sequence == seq:
			packet = sent
			break
	return packet
	

func PacketSent(bytes: PackedByteArray,timeout:int=120):
	if sentQueue.Exists(localSequence):
		print("local sequence %d exists ", localSequence)
		for i in sentQueue.queue:
			print(" + ", i.sequence)
		pass
	if sentQueue.Exists(localSequence):
		print("assert( !sentQueue.exists( localSequence ) )")
	
	if pendingAckQueue.Exists(localSequence):
		print("assert( !pendingAckQueue.exists( localSequence ) )")

	var data :PacketQueue.PacketData = PacketQueue.PacketData.new()
	data.sequence = localSequence
	data.time = 0
	data.re = 0
	data.bytes = bytes
	data.timeout = timeout
	data.size = len(bytes)
	sentQueue.queue.append(data)
	pendingAckQueue.queue.append(data)
	sentPackets += 1
	localSequence += 1
	if localSequence > maxSequence:
		localSequence = 0
	
func GenerateAckBits():
	return PacketQueue.generateAckBits(remoteSequence, receivedQueue, maxSequence)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
