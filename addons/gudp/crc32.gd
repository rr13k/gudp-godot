class_name crc32

#func calculate_crc32(data: String) -> int:
#	# 计算数据的校验和
#	var checksum = 0
#	for i in range(data.length()):
#		checksum += get_utf8_code(data[i])
#	return checksum
#
#func get_utf8_code(character: String) -> int:
#	# 获取字符的 UTF-8 编码（以字节数组的形式）
#	var utf8_array = character.to_utf8_buffer()
#	# 将字节数组转换为整数
#	var utf8_code = 0
#	for i in range(utf8_array.size()):
#		utf8_code += utf8_array[i] << (8 * (utf8_array.size() - 1 - i))
#
#	return utf8_code


func calculate_crc32(data: String) -> int:
	var checksum = 0
	for i in range(data.length()):
		checksum += get_utf8_code(data[i])
	return checksum

func get_utf8_code(character: String) -> int:
	var utf8_array = character.to_utf8_buffer()
	var utf8_code = 0
	for i in range(utf8_array.size()):
		utf8_code += utf8_array[i] << (8 * (utf8_array.size() - 1 - i))
	return utf8_code
