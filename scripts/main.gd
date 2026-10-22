extends Node3D
class_name Main

var players: Dictionary = {}
var objects: Dictionary = {}
var points: Array[int] = [0 ,0]

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

signal set_score(team: int, score: int)

enum ObjType {
	BALL = 0
}
const REAL_OBJECTS: Array[PackedScene] = [
	preload("res://scenes/ball.tscn")
]
const MOCK_OBJECTS: Array[PackedScene] = [
	preload("res://scenes/mock/ball_mock.tscn")
]

func _ready() -> void:
	var _trash = OpenXRFbSpatialAnchorManager.new()
	get_viewport().transparent_bg = true

func init_server(port: int, max_players: int, is_also_client: bool) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)
	if error != OK:
		push_error("Failed to create server: %s" % str(error))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	await get_tree().create_timer(0.1).timeout
	spawn_player(1, true, is_also_client)
	server_spawn_obj(ObjType.BALL)

func init_client(addr: String, port: int) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(addr, port)
	if error != OK:
		push_error("Failed to create client: %s" % str(error))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func remove() -> void:
	multiplayer.multiplayer_peer = null
	queue_free()

func _on_peer_connected(peer_id: int) -> void:
	assert(multiplayer.is_server())
	rpc_id(peer_id, "spawn_player", peer_id, true)
	for id in players.keys():
		if id == peer_id:
			continue
		rpc_id(id, "spawn_player", peer_id, false)
		rpc_id(peer_id, "spawn_player", id, false, players[id].is_also_client)
	
	for id in objects.keys():
		rpc_id(peer_id, "client_spawn_obj", id, objects[id].get_meta("obj_type"))

func _on_peer_disconnected(peer_id: int) -> void:
	assert(multiplayer.is_server())
	rpc("despawn_player", peer_id)

func _on_server_disconnected() -> void:
	queue_free()

var _sync_timer: float = 0.0
var _sync_interval: float = 0.020

func _physics_process(delta: float) -> void:
	if multiplayer.get_unique_id() != 1:
		return
	_sync_timer += delta
	if _sync_timer >= _sync_interval:
		_sync_timer = 0.0
		for obj_id in objects.keys():
			var snapshot = {
				"p": objects[obj_id].global_position,
				"q": objects[obj_id].quaternion
			}
			rpc("client_sync_obj", obj_id, snapshot)

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, is_local: bool, is_also_client: bool = true) -> void:
	if players.has(peer_id):
		return
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	player.is_local = is_local
	player.is_also_client = is_also_client
	add_child(player)
	player.global_position = Vector3(-5, 0, 0)
	players[peer_id] = player
	
	for id in objects.keys():
		rpc("client_spawn_obj", objects[id].get_meta("obj_id"), objects[id].get_meta("obj_type"))

@rpc("any_peer", "call_local", "reliable")
func server_spawn_obj(obj_type: ObjType) -> void:
	if multiplayer.get_unique_id() != 1:
		return
	if len(objects) >= 16:
		return
	var obj_scene = REAL_OBJECTS[obj_type]
	if obj_scene == null:
		return
	var obj = obj_scene.instantiate()
	var obj_id = obj.get_instance_id()
	obj.name = "Object_%d" % obj_id
	add_child(obj)
	obj.global_position = Vector3(0, 0, 0)
	obj.set_meta("obj_type", obj_type)
	obj.set_meta("obj_id", obj_id)
	objects[obj_id] = obj
	
	for id in players.keys():
		if id == 1:
			continue
		rpc_id(id, "client_spawn_obj", obj_id, obj_type)

@rpc("any_peer", "call_local", "reliable")
func client_spawn_obj(obj_id: int, obj_type: ObjType) -> void:
	if objects.has(obj_id):
		return
	var obj_scene = MOCK_OBJECTS[obj_type]
	if obj_scene == null:
		return
	var obj = obj_scene.instantiate()
	obj.name = "Object_%d" % obj_id
	add_child(obj)
	obj.global_position = Vector3(0, 0, 0)
	obj.set_meta("obj_type", obj_type)
	obj.set_meta("obj_id", obj_id)
	objects[obj_id] = obj

@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	players[peer_id].queue_free()
	players.erase(peer_id)

@rpc("authority", "call_local", "reliable")
func despawn_obj(obj_id: int) -> void:
	if not objects.has(obj_id):
		return
	objects[obj_id].process_mode = ProcessMode.PROCESS_MODE_DISABLED
	objects[obj_id].queue_free()
	objects.erase(obj_id)

@rpc("any_peer", "call_local", "unreliable_ordered")
func server_sync_player(peer_id: int, state: Dictionary) -> void:
	if not players.has(peer_id):
		return
	for id in players.keys():
		players[id].rpc("client_sync_player", peer_id, state)

@rpc("authority", "call_local", "unreliable_ordered")
func client_sync_obj(obj_id: int, state: Dictionary) -> void:
	if not objects.has(obj_id):
		return
	objects[obj_id].global_position = state["p"]
	objects[obj_id].quaternion = state["q"]

@rpc("any_peer", "call_local", "unreliable_ordered")
func server_add_score(team: int) -> void:
	points[team] += 1
	rpc("client_set_score", team, points[team])

@rpc("authority", "call_local", "unreliable_ordered")
func client_set_score(team: int, score: int) -> void:
	points[team] = score
	set_score.emit(team, score)
