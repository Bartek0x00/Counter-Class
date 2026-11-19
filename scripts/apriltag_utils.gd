extends RefCounted
class_name AprilTagUtils

const CALIB_DISTANCE: float = 150.0
const CALIB_SIZE: float = 31.58

const MAX_EDGE_RATIO: float = 1.2
const MAX_EDGE_DIFF: float = 2.0
const MAX_ANGLE_ERR: float = 10.0

static func get_edges_len(corners: PackedVector2Array) -> Array[float]:
	var lengths: Array[float] = []
	
	if corners.size() != 4:
		return lengths
	
	for i in range(4):
		var p1: Vector2 = corners[i]
		var p2: Vector2 = corners[(i + 1) % 4]
		lengths.append(p1.distance_to(p2))
	
	return lengths

static func get_avg_edge_len(corners: PackedVector2Array) -> float:
	var lengths := get_edges_len(corners)
	var total := 0.0
	
	if lengths.size() != 4:
		return 0.0
	
	for i in range(4):
		total += lengths[i]
	
	return total / 4.0

static func is_head_on(corners: PackedVector2Array) -> bool:
	if corners.size() != 4:
		return false
	
	var edges := get_edges_len(corners)
	var min_edge = edges.min()
	var max_edge = edges.max()
	
	if min_edge <= 0.0:
		return false
	
	if (max_edge / min_edge) > MAX_EDGE_RATIO:
		return false
	
	var hor_diff: float = abs(edges[0] - edges[2]) / ((edges[0] + edges[2]) / 2.0)
	var ver_diff: float = abs(edges[1] - edges[3]) / ((edges[1] + edges[3]) / 2.0)
	
	if hor_diff > MAX_EDGE_DIFF:
		return false
	
	if ver_diff > MAX_EDGE_DIFF:
		return false
	
	for i in range(4):
		var prev := corners[(i + 3) % 4]
		var curr := corners[i]
		var next := corners[(i + 1) % 4]
		
		var v1 := (prev - curr).normalized()
		var v2 := (next - prev).normalized()
		
		var angle := rad_to_deg(acos(clampf(v1.dot(v2), -1.0, 1.0)))
		
		if abs(angle - 90.0) > MAX_ANGLE_ERR:
			return false
	
	return true

static func estimate_distance(corners: PackedVector2Array) -> float:
	#if not is_head_on(corners):
	#	return -1.0
	
	var pixel_size := get_avg_edge_len(corners)
	
	if pixel_size < 0.0:
		return -1.0
	
	return CALIB_DISTANCE * (CALIB_SIZE / pixel_size) 
