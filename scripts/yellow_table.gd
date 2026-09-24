extends RigidBody3D

var _sync_timer: float = 0.0
var _sync_interval: float = 0.020

func _physics_process(delta: float) -> void:
	_sync_timer += delta
	if _sync_timer >= _sync_interval:
		_sync_timer = 0.0
		var snapshot = {
			"p": global_position,
			"q": quaternion
		}
		#get_node("/root/Main").rpc_id(1, "server_sync_obj", get_node("/root/Main").multiplayer.get_unique_id(), snapshot)
