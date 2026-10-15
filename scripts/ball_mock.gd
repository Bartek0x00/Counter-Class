extends Area3D

func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	pass
	if body.is_in_group("Player Body"):
		rpc_id(1, "client_sync_obj")
