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

func _ready() -> void:
	left_hand = get_node("LeftHand")
	right_hand = get_node("RightHand")
	
	#global_position = get_tree().get_first_node_in_group("spawn_point").global_position

	if not is_local:
		for c in get_children():
			c.queue_free()
		var mock_player = MOCK_PLAYER.instantiate()
		add_child(mock_player)

func _process(delta: float) -> void:
	if not is_local:
		return
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		if left_hand.is_button_pressed("ax_button"):
			get_node("/root/Main").rpc_id(1, "server_spawn_obj", Main.ObjType.BALL)

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
