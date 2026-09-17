extends StaticBody3D

var counter: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	counter += 1
	get_parent().get_node("Licznik").text = "Licznik: %d" % counter
