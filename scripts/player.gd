extends Node3D

var is_local: bool = false
var is_also_client: bool = true

var _sync_timer: float = 0.0
var _sync_interval: float = 0.020

var _geo_id: int = 0
var _geo_timer: float = 0.0
var _geo_interval: float = 0.250

var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.200

var left_hand: XRController3D
var right_hand: XRController3D

var MOCK_PLAYER: PackedScene = preload("res://scenes/player_mock.tscn")

var udp: PacketPeerUDP = PacketPeerUDP.new()
var request: FeedRequest
var camera: NativeCamera
var april_img: Image

const TAG_SIZE: float = 0.1
const FX: float = 600
const FY: float = 600
const CX: float = 400
const CY: float = 300

func _on_frame_available(frame: FrameInfo) -> void:
	april_img = frame.get_image()
	
	var detector := AprilTagDetector.new()
	var family := AprilTagFamily.new()
	family.set_type(AprilTagFamily.TAG_STANDARD_41H12)
	detector.add_family(family)
	
	var detections := detector.detect(april_img)
	if len(detections) > 0:
		var t := detections[0].get_pose_transform(TAG_SIZE, FX, FY, CX, CY)
		transform = t
	camera.stop()

func _ready() -> void:
	camera = get_node("NativeCamera")
	camera.frame_available.connect(_on_frame_available)
	camera.request_camera_permission()
	
	var cameras := camera.get_all_cameras()
	
	var cam = cameras[1]
	request = FeedRequest.new().set_camera_id(cam.get_camera_id()).set_grayscale(true).set_rotation(0).set_frames_to_skip(5)
	
	udp.set_dest_address("192.168.0.249", 9000)
	_geo_id = randi_range(0, UINT16_MAX)
	
	left_hand = get_node("LeftHand")
	right_hand = get_node("RightHand")
	
	if not is_local:
		for c in get_children():
			c.queue_free()
		var mock_player = MOCK_PLAYER.instantiate()
		add_child(mock_player)
		

func _on_load_failed(uuid: String, custom_data: Dictionary, location: int):
	print(uuid, custom_data, location)

func _process(delta: float) -> void:
	if not is_local:
		return

	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		if left_hand.is_button_pressed("ax_button"):
			get_node("/root/Main").rpc_id(1, "server_spawn_obj", Main.ObjType.BALL)
		if left_hand.is_button_pressed("by_button"):
			camera.start(request)


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	
	#if left_hinge.global_position.x > left_palm.global_position.x:
		#left_hinge.global_position.x = lerp(left_hinge.global_position.x, left_palm.global_position.x, 1.0)
	#else:
		#left_hinge.global_position = lerp(left_hinge.global_position, left_palm.global_position + (left_palm.global_basis * Vector3(0.0 , -1.0, 1.0)), 1.0)
	
	_sync_timer += delta
	_geo_timer += delta
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
		
	if _geo_timer >= _geo_interval:
		_geo_timer = 0.0
		
		var geo_snapshot = {
			"id": _geo_id,
			"t": Time.get_ticks_msec(),
			"a": Input.get_accelerometer(),
			"g": Input.get_gyroscope(),
			"m": Input.get_magnetometer(),
			"rp": get_node("XRCamera3D").global_position,
			"rq": get_node("XRCamera3D").quaternion
		}
		udp.put_packet(JSON.stringify(geo_snapshot).to_utf8_buffer())

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
