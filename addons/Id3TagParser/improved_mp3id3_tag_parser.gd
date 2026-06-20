extends Node

class_name MP3ID3Tag
const TAG_HEADER_LENGTH: int = 10
const FRAME_HEADER_LENGTH: int = 10
const STRING_TERMINATOR = 0x00
const STRING_TERMINATOR_UTF = [0x00, 0x00]

var _ID3Header: ID3MainHeader
var _frames: Dictionary = {}
var _data_bytes: PackedByteArray
var _stream: AudioStreamMP3
var bytesShift: int

class ID3MainHeader:
	var isId3: bool
	var id3Ver: String
	var unsync: bool
	var compress: bool
	var size: int

class StreamBufferPeerStrings:
	extends StreamPeerBuffer
	const STRING_TERMINATOR = [0x00]
	const STRING_TERMINATOR_UTF = [0x00, 0x00]

	func get_terminated_string(isUnicode: bool = false) -> PackedByteArray:
		var tmt := STRING_TERMINATOR_UTF if isUnicode else STRING_TERMINATOR
		var stringBytes: PackedByteArray = []
		var tBuff: Array[int] = []
		while true:
			var byte: int = get_u8()
			stringBytes.append(byte)
			tBuff.append(byte)
			if tBuff.size() > tmt.size():
				tBuff.pop_front()
			if tBuff == tmt:
				break
		return stringBytes

# ===== Properties =====
var stream: AudioStreamMP3:
	set(value):
		_clear()
		_stream = value
		if value:
			_data_bytes = value.data
			if _data_bytes:
				_ID3Header = _decode_head_bytes(_data_bytes)
				_frames = _decode_frame_heads_bytes(_data_bytes)
	get:
		return _stream

var header: ID3MainHeader:
	get:
		if !_ID3Header:
			if _data_bytes:
				_ID3Header = _decode_head_bytes(_data_bytes)
		return _ID3Header

var frames: Dictionary:
	get:
		if !_frames and _data_bytes:
			_frames = _decode_frame_heads_bytes(_data_bytes)
		return _frames

func unload_file() -> void:
	_data_bytes = PackedByteArray()
	_stream = null
	_ID3Header = null
	_frames.clear()
	_frames = {}
	bytesShift = 0

# ===== Loading from file path =====
func load_file(path: String) -> bool:
	unload_file()

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("Cannot open file: " + path)
		return false

	_data_bytes = f.get_buffer(f.get_length())
	f.close()

	_ID3Header = _decode_head_bytes(_data_bytes)
	_frames = _decode_frame_heads_bytes(_data_bytes)
	return true

# ===== Internal =====
func _clear() -> void:
	_stream = null
	_ID3Header = null
	_frames = {}

# ===== Decode header from bytes =====
func _decode_head_bytes(bytes: PackedByteArray) -> ID3MainHeader:
	var id3: String = ""
	var verH: int
	var verL: int
	var flags: int
	var size: int = 0
	for i in range(TAG_HEADER_LENGTH):
		var cv = bytes[i]
		match i:
			0,1,2: id3 += char(cv)
			3: verH = cv
			4: verL = cv
			5: flags = cv
			_: size = (size << 7) | cv
	var headerObj := ID3MainHeader.new()
	if id3 == "ID3" and verH < 0xFF and verL < 0xFF and size <= 0x1FFFFFFF:
		headerObj.isId3 = true
		headerObj.id3Ver = str(verH) + "." + str(verL)
		headerObj.unsync = flags & 0b10000000
		headerObj.compress = flags & 0b01000000
		headerObj.size = size
	bytesShift = 7 if headerObj.unsync else 8
	return headerObj

# ===== Decode frame headers from bytes =====
func _decode_frame_heads_bytes(bytes: PackedByteArray) -> Dictionary:
	if not header or not header.isId3:
		return {}
	var fms: Dictionary = {}
	var frameStart: int = TAG_HEADER_LENGTH
	while frameStart < header.size:
		if frameStart + FRAME_HEADER_LENGTH >= bytes.size():
			break
		var frameHeaderBytes := bytes.slice(frameStart, frameStart + FRAME_HEADER_LENGTH)
		var frameId = char(frameHeaderBytes[0]) + char(frameHeaderBytes[1]) + char(frameHeaderBytes[2]) + char(frameHeaderBytes[3])
		var frameLength = (frameHeaderBytes[4] << (bytesShift*3) | frameHeaderBytes[5] << (bytesShift*2) | frameHeaderBytes[6] << bytesShift | frameHeaderBytes[7])
		if frameLength > 0 and frameStart + FRAME_HEADER_LENGTH + frameLength <= bytes.size():
			if not fms.has(frameId):
				fms[frameId] = []
			fms[frameId].append([frameStart, frameLength]) # store as array for multiple frames with same ID
		frameStart += FRAME_HEADER_LENGTH + frameLength
	return fms

# ===== Frame Data =====
func getFrameData(frameName: StringName, index: int = 0) -> Variant:
	if not frames.has(frameName):
		return null
	if index >= frames[frameName].size():
		return null
	match Array(frameName.split()):
		["T", ..]:
			return _getFrameDataString(frameName, index)
		["C","O","M","M"]:
			return _getFrameCommentDict(frameName, index)
		["A","P","I","C"]:
			return _getFrameImage(frameName, index)
		_:
			return null

# Returns an array of all frames with a given frame name
func getFrameDataAll(frameName: StringName) -> Array:
	var results := []
	if not frames.has(frameName):
		return results
	
	# If multiple frames exist, store them all
	var frame_info = frames[frameName]
	if frame_info is Array and frame_info.size() == 2 and frame_info[0] is int:
		# Single frame
		results.append(getFrameData(frameName))
	else:
		# Assume frame_info is an array of arrays for multiple frames
		for i in range(frame_info.size()):
			results.append(getFrameData(frameName, i))
	return results

func _getFrameBytes(frameName: StringName, index: int = 0) -> PackedByteArray:
	if not _data_bytes or not frames.has(frameName):
		return PackedByteArray()
	
	var frame_info = frames[frameName]
	var bytes_source = _data_bytes

	if frame_info is Array and frame_info.size() == 2 and frame_info[0] is int:
		# single frame
		var start: int = frame_info[0] + FRAME_HEADER_LENGTH
		var end: int = start + frame_info[1]
		return bytes_source.slice(start, end)
	else:
		# multiple frames
		var info = frame_info[index]
		var start: int = info[0] + FRAME_HEADER_LENGTH
		var end: int = start + info[1]
		return bytes_source.slice(start, end)

func _prepareByteTextToDecode(byteText: PackedByteArray) -> Array:
	var isUnicode: bool = byteText[0] > 0
	return [byteText.slice(1), isUnicode]

func _getFrameDataString(frameName: StringName, index: int) -> String:
	return _decodeByteText.callv(_prepareByteTextToDecode(_getFrameBytes(frameName, index)))

func _decodeByteText(text: PackedByteArray, isUnicode: bool) -> String:
	if isUnicode:
		match Array(text.slice(0, 4)):
			[0xFF,0xFE,0x0,0x0], [0x0,0x0,0xFE,0xFF]: return text.get_string_from_utf32()
			[0xFF,0xFE,..], [0xFE,0xFF,..]: return text.get_string_from_utf16()
			_: return text.get_string_from_utf8()
	else:
		return text.get_string_from_ascii()

func _getFrameCommentDict(frameName: StringName, index: int) -> Dictionary:
	var bytesText = _getFrameBytes(frameName, index)
	var prepared = _prepareByteTextToDecode(bytesText)
	bytesText = prepared[0] as PackedByteArray
	
	var lang = bytesText.slice(0, 3).get_string_from_ascii()
	var comment = bytesText.slice(3)
	
	var shortEnd = comment.find(0x00)
	var longStart = comment.rfind(0x00)
	
	var shortContent = _decodeByteText(comment.slice(0, shortEnd), prepared[1]) if shortEnd > -1 else _decodeByteText(comment, prepared[1])
	var longContent = _decodeByteText(comment.slice(longStart + 1), prepared[1]) if longStart > -1 else ""
	
	return {"lang": lang, "shortContent": shortContent, "longContent": longContent}

func _getFrameImage(frameName: StringName, index: int = 0) -> Dictionary:
	var buff := StreamBufferPeerStrings.new()
	buff.data_array = _getFrameBytes(frameName, index)

	# MIME type
	var isUnicode: bool = buff.get_u8()
	var mimeType := _decodeByteText(buff.get_terminated_string(isUnicode), isUnicode)

	# Picture type
	var pType: int = buff.get_u8()

	# Description
	var pDescr := _decodeByteText(buff.get_terminated_string(isUnicode), isUnicode)

	# Raw picture bytes (everything left in the frame, do NOT decode as text)
	var pictureBytes := buff.data_array.slice(buff.get_position(), buff.data_array.size())

	return {
		"mimeType": mimeType,
		"pictureType": pType,
		"description": pDescr,
		"pictureBytes": pictureBytes
	}

# ===== Helpers =====
func getAttachedPictures() -> Array:
	var pics = []
	if frames.has("APIC"):
		for i in range(frames["APIC"].size()):
			var d = getFrameData("APIC", i)
			if d:
				pics.append(d)
	
	if not frames.has("APIC") or frames["APIC"].size() == 0:
		print("No APIC frame")
		return []

	return pics

func getArtist() -> String:
	for i in 4:
		var data = getFrameData("TPE" + str(i+1))
		if data:
			return data
	return ""

func getTrackName() -> String:
	var value = getFrameData("TIT2")
	return value if value is String else ""

func getAlbum() -> String:
	var value = getFrameData("TALB")
	return value if value is String else ""

func getYear() -> String:
	var value = getFrameData("TYER")
	return value if value is String else ""

func getKey() -> String:
	var value = getFrameData("TKEY")
	return value if value is String else ""

func getAttachedPicture(index: int = 0) -> Image:
	var pDicts = getFrameDataAll("APIC")
	if pDicts.size() == 0 or index >= pDicts.size():
		return null
	
	var pDict: Dictionary = pDicts[index]
	var image := Image.new()
	var err: int
	
	# Make sure mimeType exists and is a string
	var mime := ""
	if pDict.has("mimeType") and typeof(pDict["mimeType"]) == TYPE_STRING:
		mime = pDict["mimeType"].to_lower()

	if mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
		err = image.load_jpg_from_buffer(pDict["pictureBytes"])
	elif mime == "image/png":
		err = image.load_png_from_buffer(pDict["pictureBytes"])
	else:
		# fallback: try JPEG first, then PNG
		err = image.load_jpg_from_buffer(pDict["pictureBytes"])
		if err != OK:
			err = image.load_png_from_buffer(pDict["pictureBytes"])
		if err != OK:
			return null

	if err != OK:
		return null
	
	var img_mime = [image, mime]
	return image

func getAttachedPictureAndMime(index: int = 0) -> Array:
	var pDicts = getFrameDataAll("APIC")
	if pDicts.size() == 0 or index >= pDicts.size():
		return []
	
	var pDict: Dictionary = pDicts[index]
	var image := Image.new()
	var err: int
	
	# Make sure mimeType exists and is a string
	var mime := ""
	if pDict.has("mimeType") and typeof(pDict["mimeType"]) == TYPE_STRING:
		mime = pDict["mimeType"].to_lower()

	if mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
		err = image.load_jpg_from_buffer(pDict["pictureBytes"])
	elif mime == "image/png":
		err = image.load_png_from_buffer(pDict["pictureBytes"])
	else:
		# fallback: try JPEG first, then PNG
		err = image.load_jpg_from_buffer(pDict["pictureBytes"])
		if err != OK:
			err = image.load_png_from_buffer(pDict["pictureBytes"])
		if err != OK:
			return []

	if err != OK:
		return []
	
	var img_mime = [image, mime]
	return img_mime

func _ensureString(frameName: StringName) -> String:
	var data = getFrameData(frameName)
	return data if data is String else ""

func _ensureDict(frameName: StringName) -> Dictionary:
	var data = getFrameData(frameName)
	return data if data is Dictionary else {}
