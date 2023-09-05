extends Node

class_name opt

# 将proto复制;改为,同步
enum OpCodes {
	OPCODE_UNSPECIFIED = 0,
	OPCODE_INITIAL_STATE  = 1,
	OPCODE_SPAWN  = 2,
	OPCODE_UPDATE = 3,
	OPCODE_MOVE = 4,
	OPCODE_REJECTED = 5,
	OPCODE_ACTION = 6
}
