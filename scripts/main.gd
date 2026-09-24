extends Node3D

var players: Dictionary = {}

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

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

func _on_peer_disconnected(peer_id: int) -> void:
	assert(multiplayer.is_server())
	rpc("despawn_player", peer_id)

func _on_server_disconnected() -> void:
	queue_free()

@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, is_local: bool, is_also_client: bool = true) -> void:
	if players.has(peer_id):
		return
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	player.is_local = is_local
	player.is_also_client = is_also_client
	add_child(player)
	player.global_position = Vector3(-5, 0, -5)
	players[peer_id] = player

@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	players[peer_id].queue_free()
	players.erase(peer_id)

@rpc("any_peer", "call_local", "unreliable_ordered")
func server_sync_player(peer_id: int, state: Dictionary) -> void:
	if not players.has(peer_id):
		return
	for id in players.keys():
		players[id].rpc("client_sync_player", peer_id, state)

#@rpc("any_peer", "call_local", "unreliable_ordered")
#func server_sync_obj(peer_id: int, state: Dictionary) -> void:
#	if not players.has(peer_id):
#		return
#	players[peer_id].rpc("client_sync_obj", state)
