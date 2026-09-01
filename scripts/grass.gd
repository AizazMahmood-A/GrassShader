extends MultiMeshInstance3D

# @export var instance_count: int = 10000
@export var spawn_area: Vector2 = Vector2(50.0, 50.0)

@export var density_per_tile : int = 1000;
@export var tile_size : float = 5.0;
func _ready():
	setup_grass()

func setup_grass():
	
	var grassAmt = density_per_tile;
	
	if multimesh == null:
		multimesh = MultiMesh.new()

	# 1. Configure MultiMesh buffer flags MUST be set before instance_count
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false           # Set to true if you want per-instance color variation
	multimesh.use_custom_data = true        # Enables INSTANCE_CUSTOM in shader
	multimesh.instance_count = grassAmt * grassAmt
	#multimesh.custom_aabb = AABB(Vector3(0, 0, 0), Vector3(grassAmt, 1, grassAmt))
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for i in range(0, grassAmt):
		var xpos : float = i / float(grassAmt)
		for j in range(0, grassAmt):
			var ypos : float = j / float(grassAmt)
			# var grassPosition = Vector3();
			var pos = Vector3(
				xpos, 0.0, ypos) * tile_size
		
			var rotation_y = 0.0 #rng.randf_range(0.0, TAU)
			var basis = Basis(Vector3.UP, rotation_y)
			var transform = Transform3D(basis, pos)
		
			multimesh.set_instance_transform(i + j * grassAmt, transform)

			var sway_phase = rng.randf_range(0.0, 100.0)   # INSTANCE_CUSTOM.x
			var height_scale = rng.randf_range(0.8, 1.4)    # INSTANCE_CUSTOM.y
			var stiffness = rng.randf_range(0.1, 0.3)       # INSTANCE_CUSTOM.z
		
			var custom_data = Color(sway_phase, height_scale, stiffness, 0.0)
			# multimesh.set_instance_custom_data(i + j * grassAmt, custom_data)
