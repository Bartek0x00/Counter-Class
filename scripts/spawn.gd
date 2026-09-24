extends StaticBody3D

const PORT: int = 8000
const MAX_PLAYERS: int = 32

var ip_addr: String = "192.168.1.121"
var nickname: String = ""

var S302_SCENE: PackedScene = preload("res://scenes/classroom_302.tscn")

func _ready() -> void:
	#if OS.has_feature("server"):
	#	var main_instance = packed_main.instantiate()
	#	get_tree().root.add_child.call_deferred(main_instance)
	#	queue_free()
	#	main_instance.call_deferred("init_server", PORT, MAX_PLAYERS, false, nickname)
	get_node("../player").is_local = true
	pass

func _on_area_host_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player_body"):
		return
	var s302_instance = S302_SCENE.instantiate()
	get_node("/root/Main").add_child(s302_instance)
	body.get_node("..").queue_free()
	queue_free()
	get_node("/root/Main").call_deferred("init_server", PORT, MAX_PLAYERS, true)

func _on_area_join_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player_body"):
		return
	var s302_instance = S302_SCENE.instantiate()
	get_node("/root/Main").add_child(s302_instance)
	body.get_node("..").queue_free()
	queue_free()
	get_node("/root/Main").call_deferred("init_client", ip_addr, PORT)
