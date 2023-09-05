extends Node

class_name  serverConnection

var _client :NakamaClient = udp_client.new().Connect()

var _session : NakamaSession 

var _socket: NakamaSocket

var _world_id: String

var _last_position :Vector2

signal initial_state_received(positions, inputs, colors, names)
signal presences_changed
signal character_spawned
signal state_updated(positions, inputs)
signal position_updated(positions)

var error_message : String 

# presences 中不会包含当前玩家，数据仅包含[userId,userName] 
var presences := {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func login(username) -> bool:
	_client.logger._level = NakamaLogger.LOG_LEVEL.ERROR
	_session = await _client.authenticate_custom_async(username)
	if _session.is_exception():
		print("An error occurred: %s" % _session)
		return false
	print("Successfully authenticated: %s" % _session)
	# 登录后自动连接
	connect_to_server_async()
	return true
	
func connect_to_server_async():
	_socket = Nakama.create_socket_from(_client)
	var connected : NakamaAsyncResult = await _socket.connect_async(_session)
	if connected.is_exception():
		print("An error occurred: %s" % connected)
		return
	
	_socket.connect("connected", _on_NakamaSocket_connected)
	_socket.connect("closed", _on_NakamaSocket_closed)
	_socket.connect("connection_error",_on_NakamaSocket_connection_error)
	_socket.connect("received_error", _on_NakamaSocket_received_error)
	_socket.connect("received_match_presence", _on_NakamaSocket_received_match_presence)
	_socket.connect("received_match_state", _on_NakamaSocket_received_match_state)
	_socket.connect("received_channel_message", _on_NakamaSocket_received_channel_message)
	print("Socket connected.")


func _on_NakamaSocket_connected() -> void:
	return

# Called when the socket was closed.
func _on_NakamaSocket_closed() -> void:
	_socket = null

# Called when the socket was unable to connect.
func _on_NakamaSocket_connection_error(error: int) -> void:
	error_message = "Unable to connect with code %s" % error
	_socket = null

# 实时更新角色位置
func send_position_update(position: Vector2) -> void:
	if _socket and position != _last_position:
		_last_position = position
		var payload = { get_user_id() : {
			x = position.x,
			y=position.y
		}}
		_socket.send_match_state_async(_world_id, opt.OpCodes.OPCODE_MOVE, JSON.stringify(payload))
	
func _on_NakamaSocket_received_match_presence(new_presences: NakamaRTAPI.MatchPresenceEvent) -> void:
	print("收到了变更消息,需要先收到这个")
	for leave in new_presences.leaves:
		#warning-ignore: return_value_discarded
		presences.erase(leave.user_id)

	for join in new_presences.joins:
		if not join.user_id == get_user_id():
			print("有新的玩家加入游戏")
			presences[join.user_id] = join
	presences_changed.emit()
	
func send_jump() -> void:
	if _socket:
		var payload := {id = get_user_id()}
		_socket.send_match_state_async(_world_id, opt.OpCodes.OPCODE_ACTION, JSON.stringify(payload))

func _on_NakamaSocket_received_match_state(match_state: NakamaRTAPI.MatchData) -> void:
	var code := match_state.op_code
	var raw := match_state.data
	match code:
		opt.OpCodes.OPCODE_MOVE:
			# print("OPCODE_MOVE",raw,"自己的id:",ServerConnection.get_user_id())
			var decoded: Dictionary = JSON.parse_string(raw)
			emit_signal("position_updated", decoded)

		opt.OpCodes.OPCODE_INITIAL_STATE:
			print("OPCODE_INITIAL_STATE",raw)
			var decoded: Dictionary = JSON.parse_string(raw)
			initial_state_received.emit(decoded)
			
		opt.OpCodes.OPCODE_ACTION:
			print("额外输出了攻击")
			#  行动包含跳跃，攻击和其他常规操作
#			var decoded: Dictionary = JSON.parse_string(raw)
#			var positions: Dictionary = decoded.pos
#			var inputs: Dictionary = {"inputs":null}
#			var names: Dictionary = decoded.nms
#			var colors :Dictionary = {"c":null}
#			initial_state_received.emit(positions, inputs, colors, names)
		opt.OpCodes.OPCODE_SPAWN:
			"""当其他玩家加入游戏时，会收到这个消息，消息中包含了新玩家的位置"""
			# print("需要先收到前置命令,其他玩家加入游戏: OPCODE_SPAWN:", raw,"自己的id:",ServerConnection.get_user_id())
			var decoded = JSON.parse_string(raw)
			emit_signal("character_spawned", decoded)
			
	
func _on_NakamaSocket_received_channel_message(message: NakamaAPI.ApiChannelMessage) -> void:
	if message.code != 0:
		return

	var content: Dictionary = JSON.parse_string(message.content).result
	emit_signal("chat_message_received", message.sender_id, content.msg)

# Called when the socket reported an error.
func _on_NakamaSocket_received_error(error: NakamaRTAPI.Error) -> void:
	error_message = str(error)
	_socket = null

# 获取比列表
func get_match_list() -> NakamaAPI.ApiMatchList:
	var min_players = 0
	var max_players = 99
	var limit = 10
	var authoritative = true
	var label = ""
	var query = ""
	var result : NakamaAPI.ApiMatchList = await _client.list_matches_async(_session, min_players, max_players, limit, authoritative, label, query)
	return result
	
func join_match(match_id:String):
	_world_id = match_id
	var match_join_result = await _socket.join_match_async(match_id)
	
	# 加入失败则返回错误码
	if match_join_result.is_exception():
		var exception: NakamaException = match_join_result.get_exception()
		error_message = exception.message
		return exception.status_code

	# 如果加入成功则记录当前在线的玩家
	for presence in match_join_result.presences:
			presences[presence.user_id] = presence
	return match_join_result

func get_user_id() -> String:
	if _session:
		return _session.user_id
	return ""
	
func send_spawn() -> void:
	if _socket:
		print("只执行一次172")
		_socket.send_match_state_async(_world_id, opt.OpCodes.OPCODE_SPAWN, "")
