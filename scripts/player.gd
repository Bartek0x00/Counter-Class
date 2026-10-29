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
const ANCHORS_FILE = "user://openxr_fb_anchor.json"
const APPLICATION_ID = "1391862670680685"

func _ready() -> void:
	init_meta_sdk()
	
	left_hand = get_node("LeftHand")
	right_hand = get_node("RightHand")
	
	get_node("OpenXRFbSpatialAnchorManager").openxr_fb_spatial_anchor_tracked.connect(_on_openxr_fb_spatial_anchor_tracked)
	get_node("OpenXRFbSpatialAnchorManager").openxr_fb_spatial_anchor_load_failed.connect(_on_load_failed)
	if not is_local:
		for c in get_children():
			c.queue_free()
		var mock_player = MOCK_PLAYER.instantiate()
		add_child(mock_player)
		
	get_node("OpenXRFbSpatialAnchorManager").load_anchor("2fc3d173-5f7c-d01c-e4b4-2a2c0611ebc6", {}, OpenXRFbSpatialEntity.STORAGE_CLOUD)

#func init_meta_sdk():
	#var request = MetaPlatformSDK.initialize_platform_async(APPLICATION_ID)
	#if request == null:
		#get_node("Label3D").text = "Request NULL"
		#return
	#var message: MetaPlatformSDK_Message = await request.completed
	#if message.is_error():
		#get_node("Label3D").text = "Initialization request failed: " + str(message.error)
		#return
		#
	#var user = await MetaPlatformSDK.user_get_logged_in_user_async().completed
	#if user.is_error():
		#get_node("Label3D").text = "User request failed: " + str(user.error)
		#return
	#get_node("Label3D").text = str(user.get_string())


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
			get_node("OpenXRFbSpatialAnchorManager").create_anchor(Transform3D.IDENTITY, Dictionary())


func init_meta_sdk() -> void:
	var label: Label3D = get_node("Label3D")

	# 1. Initialize the platform SDK.
	var request = MetaPlatformSDK.initialize_platform_async(APPLICATION_ID)
	if request == null:
		label.text = "Initialization request is NULL"
		return

	var init_message: MetaPlatformSDK_Message = await request.completed

	print("Init message: ", init_message)
	print("Init message is_error: ", init_message.is_error())

	if init_message.is_error():
		label.text = "Init error: " + str(init_message.error)
		return

	# 2. Check the platform initialization result.
	var init_info = init_message.get_platform_initialize()
	print("Platform init result: ", init_info.result)

	if init_info.result != MetaPlatformSDK.PLATFORM_INITIALIZE_SUCCESS:
		label.text = "Platform init result: " + str(init_info.result)
		return

	# 3. Check entitlement.
	var entitlement_request = MetaPlatformSDK.entitlement_get_is_viewer_entitled_async()
	if entitlement_request == null:
		label.text = "Entitlement request is NULL"
		return

	var entitlement_message: MetaPlatformSDK_Message = await entitlement_request.completed
	print("Entitlement response: ", entitlement_message)

	if entitlement_message.is_error():
		label.text = "Entitlement error: " + str(entitlement_message.error)
		return

	# 4. Request the logged-in user.
	var user_request = MetaPlatformSDK.user_get_logged_in_user_async()
	if user_request == null:
		label.text = "User request is NULL"
		return

	var user_message: MetaPlatformSDK_Message = await user_request.completed

	print("User message: ", user_message)
	print("User message type: ", user_message.type)
	print("User message is_error: ", user_message.is_error())

	if user_message.is_error():
		label.text = "User error: " + str(user_message.error)
		return

	var user: MetaPlatformSDK_User = user_message.get_user()

	print("User object: ", user)
	print("User Oculus ID: ", user.oculus_id)

	label.text = "Oculus ID: " + str(user.oculus_id)


func _on_openxr_fb_spatial_anchor_tracked(anchor_node: Object, spatial_entity: Object, is_new: bool):
	if not is_new:
		print("SUCCESS!!!")
		return
	print(spatial_entity.get_uuid())
	spatial_entity.openxr_fb_spatial_entity_saved.connect(_on_saved)
	spatial_entity.set_component_enabled(OpenXRFbSpatialEntity.COMPONENT_TYPE_STORABLE, true)
	spatial_entity.set_component_enabled(OpenXRFbSpatialEntity.COMPONENT_TYPE_SHARABLE, true)
	spatial_entity.save_to_storage(OpenXRFbSpatialEntity.StorageLocation.STORAGE_CLOUD)

func _on_saved(succeeded: bool, location: int):
	print(succeeded, location)

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	
	#if left_hinge.global_position.x > left_palm.global_position.x:
		#left_hinge.global_position.x = lerp(left_hinge.global_position.x, left_palm.global_position.x, 1.0)
	#else:
		#left_hinge.global_position = lerp(left_hinge.global_position, left_palm.global_position + (left_palm.global_basis * Vector3(0.0 , -1.0, 1.0)), 1.0)
	
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
