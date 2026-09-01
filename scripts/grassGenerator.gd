@tool
extends Node3D

@export var grass_per_tile : int = 10
@export var tile_size : float = 5.0
@export var grass_range : float = 100.0

@export_category("")
@export var grass_high_lod : ArrayMesh;
@export var grass_low_lod : ArrayMesh;
@export var grass_material : Material;

@onready var player : Node3D = get_node("../Player")

var spaitial_grid : Dictionary[Vector3, MultiMeshInstance3D] = {}
var loaded_multimesh_instances : Array[MultiMeshInstance3D] = []

@export var distance_multiplier: Dictionary[int, float] = {}

func world_to_chunk_coord(current_position : Vector3, chunk_size : float) -> Vector3:
	return Vector3(floor(current_position.x / chunk_size), 
					0,
					floor(current_position.z / chunk_size))
					
func chunk_to_world_coord(chunk_position : Vector3, chunk_size : float) -> Vector3:
	return chunk_position * chunk_size

func create_multimesh(grass_count : int, grass_tile_size : float, grass_mesh : ArrayMesh, loaded_multimesh : MultiMesh) -> MultiMesh:
	var multimesh : MultiMesh = MultiMesh.new()
	if not loaded_multimesh:
		multimesh = MultiMesh.new()
		multimesh.use_custom_data = true
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
	else:
		multimesh = loaded_multimesh
		
	multimesh.mesh = grass_mesh
	multimesh.instance_count = grass_count * grass_count
	var density : float = (multimesh.instance_count) / grass_tile_size;
	
	for i in range(grass_count):
		var xPos : float = i / float(grass_count)
		for j in range(grass_count):
			
			var yPos : float = j / float(grass_count)
			var offsetVec : Vector3 = Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
			var chunk_position : Vector3 = (Vector3(xPos, 0, yPos) * grass_tile_size) + offsetVec
			
			multimesh.set_instance_transform(
				i + j * grass_count, 
			Transform3D(Basis(), chunk_position))
			
			var custom_data = Color(density, 0.0, 0.0, 0.0)
			multimesh.set_instance_custom_data(i + j * grass_count, custom_data)

	return multimesh;

func distance_to_position( nodePosition : Vector3, playerPosition : Vector3) -> float:
	var distance : float = nodePosition.distance_squared_to(playerPosition)
	return distance
	
func despawn_multimesh(key : Vector3):
	var multimesh : MultiMeshInstance3D = spaitial_grid.get(key)
	spaitial_grid.erase(key)
	multimesh.multimesh.instance_count = 0
	multimesh.visible = false
	loaded_multimesh_instances.append(multimesh)

func spawn_grass_instance(chunk_position : Vector3, playerPosition : Vector3) -> MultiMeshInstance3D:
	var multimeshInstance : MultiMeshInstance3D;
	if not loaded_multimesh_instances.is_empty():
		multimeshInstance = loaded_multimesh_instances.pop_front()
		multimeshInstance.visible = true
	else:
		multimeshInstance = MultiMeshInstance3D.new()
		add_child(multimeshInstance)
		
	multimeshInstance.name = str(chunk_position)
	multimeshInstance.material_override = grass_material
	multimeshInstance.position = chunk_to_world_coord(chunk_position, tile_size)
	multimeshInstance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	var dist : float = distance_to_position(chunk_position, playerPosition)
	#chunk_to_world_coord(chunk_position, tile_size).distance_to(
		#chunk_to_world_coord(playerPosition, tile_size)
		#)
	update_grass_instance(dist, multimeshInstance)
	spaitial_grid[chunk_position] = multimeshInstance
	return multimeshInstance;

func update_grass_instance(distance : float, grass : MultiMeshInstance3D):
	var keys : Array = distance_multiplier.keys()
	var multiplier : float = distance_multiplier[keys[keys.size() - 1]]
	
	for key in keys:
		if distance < key:
			multiplier = distance_multiplier[key]
			break

	var grassAmount : int = floor(grass_per_tile * multiplier)
	if (not grass.multimesh) or (pow(grassAmount, 2) != grass.multimesh.instance_count):
		grass.multimesh = create_multimesh(grassAmount, 
		tile_size,
		grass_low_lod if multiplier <= 0.8 else grass_high_lod, 
		grass.multimesh)

var previous_chunk : Vector3 = Vector3.INF;
func update_grass_instances():
	var current_chunk : Vector3 = world_to_chunk_coord(player.global_position, tile_size)
	if previous_chunk == current_chunk:
		return
	previous_chunk = current_chunk;
	
	# all items in range
	var chunks_in_range : Array[Vector3] = []
	for i in range(-grass_range, grass_range, tile_size):
		for j in range(-grass_range, grass_range, tile_size):
			var chunk_pos : Vector3 = world_to_chunk_coord(Vector3(i, 0, j), tile_size) + current_chunk
			chunks_in_range.append(chunk_pos)
	
	# despawn
	var despawnCount : int = 0
	for item in spaitial_grid.keys():
		var dist : float = distance_to_position(item, current_chunk)
		if dist > grass_range:	
			despawn_multimesh(item)
			despawnCount += 1
		else:
			update_grass_instance(dist, spaitial_grid[item])
			
	print("Despawned Count: {dCount}/{mCount}".format({"dCount": despawnCount, "mCount": chunks_in_range.size()}))
	
	# spawn
	var spawnCount : int = 0
	for chunk_coord in chunks_in_range:
		if not spaitial_grid.has(chunk_coord):
			spawn_grass_instance(chunk_coord, current_chunk)
			spawnCount += 1
	print("Spawned Count: %d" % [spawnCount])
	
func _init() -> void:
	pass
	
func _ready() -> void:
	update_grass_instances()
	pass

func _process(delta: float) -> void:
	update_grass_instances()
	pass
