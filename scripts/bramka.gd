extends Area3D

@export
var team: int = 0

func _ready() -> void:
	get_node("/root/Main").set_score.connect(_set_score)

func _set_score(team: int, score: int) -> void:
	if self.team != team:
		return
	get_node("Label3D").text = str(score)

func _on_body_entered(body: Node3D) -> void:

	if body.is_in_group("Ball"):
		get_node("/root/Main").rpc("despawn_obj", body.get_meta("obj_id"))
		get_node("/root/Main").rpc_id(1, "server_add_score", team)
		get_node("/root/Main").rpc_id(1, "server_spawn_obj", Main.ObjType.BALL)
