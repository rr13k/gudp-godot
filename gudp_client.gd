extends Node

class_name GUDPClient

const apiProto = preload("./protos/gudp.gd")
const resend_max:int = 3

signal onReceiveConfirmationMessage(ack:int)
signal onReceiveMessage(bytes: PackedByteArray)

var ip :String
var port :int
var socket :PacketPeerUDP
var connected = false
var session_id :PackedByteArray
var __rpc_id :int

# 定长数组
var rpcResponseList : Array:
	set(value):
		while true:
			if len(value) < 50:
				break
			else:
				value.pop_at(0)
		rpcResponseList = value

# 连接的客户端key需要
var client_key = "https://rr13k.github.io/gudp/very-good"

var reliability : Reliability = Reliability.new()
var sceneTree # 用于获取scene 否则无法sleep

# 确认队列
var ConfirmationQueue:Array = []

func _init(ip:String,port:int):
	self.ip = ip
	self.port = port
	onReceiveConfirmationMessage.connect(updateConfirmation)
	Connect()
	
func _get_rpc_id():
	++__rpc_id
	return __rpc_id
	
# _process in use
func onRecord():
	if socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		print("debug:: Received message:", packet)
		var msg_type = parse_record(packet)
		print("msg_type:",msg_type)
		match msg_type:
			apiProto.gudp_message_type.HANDSHAKEMESSAGE:
				# 收到握手，需要区分第一次还是第二次
				var hand = apiProto.HandshakeMessage.new()
				var result_code = hand.from_bytes(packet)
				if result_code == apiProto.PB_ERR.NO_ERRORS:
					var _cookie = hand.get_cookie()
					var _session = hand.get_session_id()
					if _session:
						print("接收到了 _session",_session)
						session_id = _session
					elif _cookie: # 如果获取到了cookie需要用cookie换取session
						print("获取到的cookie为",_cookie)
						sendHandMessage(hand.to_bytes())
					
			apiProto.gudp_message_type.PING:
				print("收到ping")
				
			apiProto.gudp_message_type.PONG:
				print("收到pong")
				
			apiProto.gudp_message_type.RPCMESSAGE:
				print("收到了rpc消息")
				var rpcMsg = apiProto.rpc_message.new()
				var result_code = rpcMsg.from_bytes(packet)
				if result_code == apiProto.PB_ERR.NO_ERRORS:
					var rpc_id = rpcMsg.get_rpc_id()
					print("收到了rpc消息id为:",rpc_id)
					# 设置固定长度的数组
					onReceiveConfirmationMessage.emit(rpc_id)
					rpcResponseList.append(rpcMsg)
				
			apiProto.gudp_message_type.RELIABLEMESSAGE:
				print("收到可靠消息",packet)
				# 接收到消息，需要考虑是否进行排序后再返回给用户侧

				var reliableMsg = apiProto.ReliableMessage.new()
				var result_code = reliableMsg.from_bytes(packet)
				if result_code == apiProto.PB_ERR.NO_ERRORS:
					var _data = reliableMsg.get_data()
					if len(_data) == 0:
						print("收到的为确认消息ack:",reliableMsg.get_ack())
						onReceiveConfirmationMessage.emit(reliableMsg.get_ack())
						# 仅通过ack进行确认不使用ack-bits
						# 接受到消息后需要把相关消息标记为可靠,并允许返回给客户端
					else:
						# 排序的方法为，接收到消息记录时间，查看序号是否为预期的序号，如果不为预期的序号则放到队列中等待，如果为预期序号则直接返回 并清空记录时间。
						# 如果中途序号丢失并且重传也未成功，则更具首个记录时间timeout, 更新预期为当前最小序号, 再进行用户返回
						print("接收到转给用户的消息")
						onReceiveMessage.emit(_data)
			apiProto.gudp_message_type.UNRELIABLEMESSAGE:
				print("收到不可靠消息")
				var unreliableMsg = apiProto.UnreliableMessage.new()
				var result_code = unreliableMsg.from_bytes(packet)
				if result_code == apiProto.PB_ERR.NO_ERRORS:
					onReceiveMessage.emit(unreliableMsg.get_data())

# 解析接收的消息类型
func parse_record(rec: PackedByteArray) -> int:
	if rec.size() < 1:
		print("Error: empty record")
		return 0
	var msg_type:int = rec[0]
	rec = rec.slice(1, rec.size())
	return msg_type
	
func RpcCall(method: String,args:Dictionary) -> Dictionary:
	var rpc_id = reliability.localSequence
	var rpcMsg = apiProto.rpc_message.new()
	
	rpcMsg.set_rpc_id(rpc_id)
	rpcMsg.set_method(method)
	var args_bytes = JSON.stringify(args)
	rpcMsg.set_data(args_bytes.to_utf8_buffer())
	
	var data = rpcMsg.to_bytes()
	reliability.PacketSent(data)
	await send_req_packet(rpc_id,apiProto.gudp_message_type.RPCMESSAGE)
	
	# 从队列中获取响应数据
	for i in rpcResponseList:
		if i.get_rpc_id() == rpc_id:
			var resData = i.get_data()
			return JSON.parse_string(resData.get_string_from_utf8())
	return {}


func SendMessage(bytes:PackedByteArray, reliability: bool=true):
	if reliability:
		return await sendReliabilityMessgae(bytes)
	else:
		sendUnreliableMessage(bytes)
		return true

func sendSocket(bytes:PackedByteArray):
	socket.put_packet(bytes)

# 发送协议消息
func sendGudpMessage(type:apiProto.gudp_message_type, bytes:PackedByteArray):
	var prload = PackedByteArray([type]) + bytes
	sendSocket(prload)

# 发送rpc消息
func sendRpcMessage(bytes:PackedByteArray):
	sendGudpMessage(apiProto.gudp_message_type.RPCMESSAGE, bytes)
	
# 发送不可靠消息
func sendUnreliableMessage(bytes:PackedByteArray):
	var uMsg = apiProto.UnreliableMessage.new()
	uMsg.set_data(bytes)
	var data = uMsg.to_bytes()
	sendGudpMessage(apiProto.gudp_message_type.UNRELIABLEMESSAGE,data)

# 发送可靠消息
func _sendReliabilityMessgae(bytes:PackedByteArray):
	sendGudpMessage(apiProto.gudp_message_type.RELIABLEMESSAGE,bytes)

# 发送可靠udp消息
func sendReliabilityMessgae(bytes:PackedByteArray,timeout=120) -> bool:
	print("seq:",reliability.localSequence,"ack:",reliability.remoteSequence,"ack-bits:",reliability.GenerateAckBits())
	var reliableMsg = apiProto.ReliableMessage.new()
	var seq = reliability.localSequence
	reliableMsg.set_seq(seq)
	reliableMsg.set_ack(reliability.remoteSequence)
	reliableMsg.set_ackBits(reliability.GenerateAckBits())
	reliableMsg.set_data(bytes)
	print("检查设置进去的内容:", bytes)
	# 这里不能简单的发送，还需要保证接收到响应，如果超时没接收到则需要进行重发
	var data = reliableMsg.to_bytes()
	# 更新信息,rpc共用可靠协议
	reliability.PacketSent(data)
	return await send_req_packet(seq)

func Connect():
	socket = PacketPeerUDP.new()
	socket.connect_to_host(ip, port)
		
	if socket.get_available_packet_count() > 0:
		print("Connected: %s" % socket.get_packet().get_string_from_utf8())
	connected = true

	# 进行握手连接
	var handel = apiProto.HandshakeMessage.new()
	handel.set_key(client_key.to_utf8_buffer())
	sendHandMessage(handel.to_bytes())

# 可靠消息通过req队列发送包,不在直接发送
func send_req_packet(seq: int, msg_type: apiProto.gudp_message_type=apiProto.gudp_message_type.RELIABLEMESSAGE):
	# 获取包信息
	var packet = reliability.GetSentPacket(seq)
	print("添加可靠信息后的消息:", packet.bytes)
	if msg_type == apiProto.gudp_message_type.RELIABLEMESSAGE:
		_sendReliabilityMessgae(packet.bytes)
	else:
		sendRpcMessage(packet.bytes)
	packet.re += 1
#	print("发送次数", packet.re)
	if packet.re > resend_max: # 超过最大次数返回失败
		return false
	var timeout = packet.timeout
	var _start_time = Time.get_ticks_msec()
	
	while true:
		if ConfirmationQueue.has(seq):
			print("seq ",seq,"响应间隔: ",  Time.get_ticks_msec() - _start_time,"ms")
			# 校验完成后去除seq
			ConfirmationQueue.erase(seq)
			break
		elif Time.get_ticks_msec() > _start_time + timeout:
			print("send_req_packet seq :", seq," timeout!")
			return await send_req_packet(seq, msg_type)
		await sceneTree.process_frame
	return true

func sendHandMessage(bytes:PackedByteArray):
	var mytype = PackedByteArray([apiProto.gudp_message_type.HANDSHAKEMESSAGE])
	var data = mytype + bytes
	socket.put_packet(data)

# 更新确认队列，将收到的确认消息放置到确认队列中去
func updateConfirmation(ack :int):
	print("添加ack确认消息:", ack," ->队列")
	if ConfirmationQueue.has(ack) == false:
		ConfirmationQueue.append(ack)

