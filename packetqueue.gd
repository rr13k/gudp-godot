extends Node

# 仅可靠数据使用
class_name PacketQueue

class PacketData:
	var sequence: int
	var time: float
	var size: int
	var re:int
	var bytes : PackedByteArray
	var timeout: int

# 数组中存放PacketData
var queue:Array = []

# 添加数据包到发送队列
func enqueue(data):
	queue.append(data)

# 获取并移除队列中的下一个数据包
func dequeue():
	if queue.size() > 0:
		queue.remove_at(0)
	return null

# 获取队列中的数据包数量
func size():
	return queue.size()
	
static func sequenceMoreRecent(s1: int, s2: int, maxSequence: int) -> bool:
	return (s1 > s2) && (s1 - s2 <= maxSequence / 2) or (s2 > s1) and (s2 - s1 > maxSequence / 2)

func Exists(sequence: int) -> bool:
	for i in range(queue.size()):
		if queue[i].sequence == sequence:
			return true
	return false
	
static func generateAckBits(ack:int, receivedQueue :PacketQueue, maxSequence :int):
	var ackBits:int
	
	var itor = 0
	
	while itor < len(receivedQueue.queue):
		var iseq = receivedQueue.queue[itor].sequence

		if iseq == ack || sequenceMoreRecent(iseq, ack, maxSequence):
			break
		
		var bitIndex = bitIndexForSequence(iseq, ack, maxSequence)
		if bitIndex <= 31:
			ackBits |= 1 << bitIndex
		itor += 1
	return ackBits

static func bitIndexForSequence(sequence: int, ack: int, maxSequence: int) -> int:
	# TODO: remove those asserts once done
	if sequence == ack:
		print("assert(sequence != ack)")
	
	if sequenceMoreRecent(sequence, ack, maxSequence) :
		print("assert(!sequenceMoreRecent(sequence, ack, maxSequence))")
	
	if sequence > ack :
		if ack >= 33:
			print("assert(ack < 33)")
		
		if maxSequence < sequence :
			print("assert(maxSequence >= sequence)")
		
		return ack + (maxSequence - sequence)
	
	if ack < 1 :
		print("assert(ack >= 1)")
	
	if sequence > ack-1:
		print("assert(sequence <= ack-1)")
	return ack - 1 - sequence


