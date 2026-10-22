extends Node3D

var is_local: bool = false
var is_also_client: bool = true

var _sync_timer: float = 0.0
var _sync_interval: float = 0.020

var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.200

var left_hand: XRController3D
var right_hand: XRController3D

var MOCK_PLAYER: PackedScene = preload("res://scenes/player_mock.tscn")
const ANCHORS_FILE = "user://openxr_fb_anchor.json"

func _ready() -> void:
	left_hand = get_node("LeftHand")
	right_hand = get_node("RightHand")
	
	#global_position = get_tree().get_first_node_in_group("spawn_point").global_position

	XRServer.find_interface("OpenXR").session_begun.connect(_on_openxr_session_begun)
	
	if not is_local:
		for c in get_children():
			c.queue_free()
		var mock_player = MOCK_PLAYER.instantiate()
		add_child(mock_player)
	elif has_session_begun:
		var file = FileAccess.open(ANCHORS_FILE, FileAccess.WRITE)
		if not file:
			return
		
		var json = JSON.new()
		if json.parse(file.get_as_text()) != OK:
			return
		if not json.data() is Dictionary:
			return
		
		print(json.data)
		#get_node("OpenXRFbSpatialAnchorManager").load_anchor(json.data.keys()[0], json.data, OpenXRFbSpatialEntity.STORAGE_LOCAL, true)
		

var has_session_begun = false

func _on_openxr_session_begun():
	has_session_begun = true

func _process(delta: float) -> void:
	if not is_local:
		return
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		if left_hand.is_button_pressed("ax_button"):
			get_node("/root/Main").rpc_id(1, "server_spawn_obj", Main.ObjType.BALL)
		if left_hand.is_button_pressed("by_button"):
			if has_session_begun:
				get_node("OpenXRFbSpatialAnchorManager").create_anchor(Transform3D.IDENTITY, Dictionary())
				

func _on_openxr_fb_spatial_anchor_tracked():
		var file = FileAccess.open(ANCHORS_FILE, FileAccess.WRITE)
		if not file:
			return
		var uuids = get_node("OpenXRFbSpatialAnchorManager").get_anchor_uuids()
		if len(uuids) < 1:
			return
		var uuid = uuids[0]
		var anchor_data: Dictionary
		anchor_data[uuid] = {}
		file.store_string(JSON.stringify(anchor_data))
		file.close()
		get_node("Label3D").text = str(anchor_data)

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	_sync_timer += delta
	if _sync_timer >= _sync_interval:
		_sync_timer = 0.0
		var snapshot = {
			"p": get_node("PlayerBody/Skeleton3D").global_position,
			"q": get_node("PlayerBody").quaternion,
			"lh_p": left_hand.global_position,
			"lh_q": left_hand.quaternion,
			"rh_p": right_hand.global_position,
			"rh_q": right_hand.quaternion,
			"c_p": get_node("XRCamera3D").global_position,
			"c_q": get_node("XRCamera3D").quaternion
		}
		get_parent().rpc_id(1, "server_sync_player", multiplayer.get_unique_id(), snapshot)

@rpc("authority", "call_local", "unreliable_ordered")
func client_sync_player(peer_id: int, state: Dictionary) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var tmp_players = get_parent().players
	if not tmp_players.has(peer_id):
		return
	var player_mock = tmp_players[peer_id].get_node("PlayerMock")
	player_mock.global_position = state["p"]
	player_mock.quaternion = state["q"]
	player_mock.get_node("MockLeftHand").global_position = state["lh_p"]
	player_mock.get_node("MockLeftHand").quaternion = state["lh_q"]
	player_mock.get_node("MockRightHand").global_position = state["rh_p"]
	player_mock.get_node("MockRightHand").quaternion = state["rh_q"]
	player_mock.get_node("CameraMock").global_position = state["c_p"]
	player_mock.get_node("CameraMock").quaternion = state["c_q"]
