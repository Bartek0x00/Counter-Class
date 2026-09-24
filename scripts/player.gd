extends Node3D

var is_local: bool = false
var is_also_client: bool = true

var _sync_timer: float = 0.0
var _sync_interval: float = 0.020

var left_hand
var right_hand

var MOCK_PLAYER: PackedScene = preload("res://scenes/player_mock.tscn")
var MOCK_HAND: PackedScene = preload("res://scenes/hand_mock.tscn")

func _ready() -> void:
	left_hand = get_node("LeftHand")
	right_hand = get_node("RightHand")
	
	if not is_local:
		get_node("MovementClimb").enabled = false
		get_node("PlayerBody").set_enabled(false)
		left_hand.queue_free()
		right_hand.queue_free()
		var mock_player = MOCK_PLAYER.instantiate()
		var mock_left_hand = MOCK_HAND.instantiate()
		mock_left_hand.name = "MockLeftHand"
		var mock_right_hand = MOCK_HAND.instantiate()
		mock_right_hand.name = "MockRightHand"
		add_child(mock_player)
		add_child(mock_left_hand)
		add_child(mock_right_hand)

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	
	_sync_timer += delta
	if _sync_timer >= _sync_interval:
		_sync_timer = 0.0
		var snapshot = {
			"p": global_position,
			"q": quaternion,
			"lh_p": left_hand.global_position,
			"lh_q": left_hand.quaternion,
			"rh_p": right_hand.global_position,
			"rh_q": right_hand.quaternion
		}
		get_parent().rpc_id(1, "server_sync_player", multiplayer.get_unique_id(), snapshot)

@rpc("authority", "call_local", "unreliable_ordered")
func client_sync_player(peer_id: int, state: Dictionary) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var tmp_players = get_parent().players
	if not tmp_players.has(peer_id):
		return
	tmp_players[peer_id].global_position = state["p"]
	tmp_players[peer_id].quaternion = state["q"]
	tmp_players[peer_id].get_node("MockLeftHand").global_position = state["lh_p"]
	tmp_players[peer_id].get_node("MockLeftHand").quaternion = state["lh_q"]
	tmp_players[peer_id].get_node("MockRightHand").global_position = state["rh_p"]
	tmp_players[peer_id].get_node("MockRightHand").quaternion = state["rh_q"]

#@rpc("authority", "call_local", "unreliable_ordered")
#func client_sync_obj(state: Dictionary) -> void:
#	var obj = get_node("/root/Main/School302/yellow_table_017")
#	obj.global_position = state["p"]
#	obj.quaternion = state["q"]
