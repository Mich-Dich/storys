extends MeshInstance3D

var timer: Timer

@export var foliage_scene: PackedScene
@export var spawn_radius: float = 50.0
@export var step: float = 2.0
@export var grass_threshold: float = 0.5

# Noise objects (used when the texture is a NoiseTexture2D)
var _height_large_noise: Noise
var _height_small_noise: Noise
var _color_noise: Noise

# Fallback images for non‑procedural textures
var _height_large_img: Image
var _height_small_img: Image
var _color_noise_img: Image
var _height_large_size: Vector2i
var _height_small_size: Vector2i
var _color_noise_size: Vector2i

# Uniform values
var _scale_large: float
var _scale_small: float
var _amp_large: float
var _amp_small: float
var _noise_scale: float
var _blend_sharpness: float

func _ready():
	# Timer setup
	timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(update_position_camera)
	add_child(timer)

	# Read shader parameters
	var mat = get_surface_override_material(0)
	if not mat is ShaderMaterial:
		push_warning("Material is not a ShaderMaterial")
		return

	var smat = mat as ShaderMaterial

	var tex_large = smat.get_shader_parameter("heightmap_large")
	var tex_small = smat.get_shader_parameter("heightmap_small")
	var tex_color = smat.get_shader_parameter("color_noise")

	_scale_large   = smat.get_shader_parameter("scale_large")
	_scale_small   = smat.get_shader_parameter("scale_small")
	_amp_large     = smat.get_shader_parameter("amplitude_large")
	_amp_small     = smat.get_shader_parameter("amplitude_small")
	_noise_scale   = smat.get_shader_parameter("color_noise_scale")
	_blend_sharpness = smat.get_shader_parameter("blend_sharpness")

	# Extract noise objects from NoiseTexture2D
	if tex_large is NoiseTexture2D:
		_height_large_noise = (tex_large as NoiseTexture2D).noise
	else:
		_height_large_img = tex_large.get_image()
		if _height_large_img:
			_height_large_size = _height_large_img.get_size()

	if tex_small is NoiseTexture2D:
		_height_small_noise = (tex_small as NoiseTexture2D).noise
	else:
		_height_small_img = tex_small.get_image()
		if _height_small_img:
			_height_small_size = _height_small_img.get_size()

	if tex_color is NoiseTexture2D:
		_color_noise = (tex_color as NoiseTexture2D).noise
	else:
		_color_noise_img = tex_color.get_image()
		if _color_noise_img:
			_color_noise_size = _color_noise_img.get_size()
	spawn_foliage()


func spawn_foliage():
	if not foliage_scene:
		return
	for x in range(-spawn_radius, spawn_radius, step):
		for z in range(-spawn_radius, spawn_radius, step):
			var world_xz = Vector2(x, z)
			if is_grass_at(world_xz):
				var y = get_height_at(world_xz)
				var instance = foliage_scene.instantiate()
				add_child(instance)
				instance.global_position = Vector3(x, y, z)


func sample_noise(noise_obj: Noise, world_xz: Vector2, scale: float) -> float:
	var raw = noise_obj.get_noise_2d(world_xz.x * scale, world_xz.y * scale)
	# Map from [-1,1] to [0,1] to match NoiseTexture2D's output
	return (raw + 1.0) * 0.5


func sample_texture_r(img: Image, size: Vector2i, uv: Vector2) -> float:
	var x = wrapi(int(uv.x * size.x), 0, size.x)
	var y = wrapi(int(uv.y * size.y), 0, size.y)
	return img.get_pixel(x, y).r


func is_grass_at(world_xz: Vector2) -> bool:
	var noise_val: float
	if _color_noise:
		noise_val = sample_noise(_color_noise, world_xz, _noise_scale)
	elif _color_noise_img:
		noise_val = sample_texture_r(_color_noise_img, _color_noise_size, world_xz * _noise_scale)
	else:
		return false

	var t = smoothstep(0.5 - _blend_sharpness, 0.5 + _blend_sharpness, noise_val)
	return t > grass_threshold


func get_height_at(world_xz: Vector2) -> float:
	var h_large: float
	var h_small: float

	if _height_large_noise:
		h_large = sample_noise(_height_large_noise, world_xz, _scale_large)
	elif _height_large_img:
		h_large = sample_texture_r(_height_large_img, _height_large_size, world_xz * _scale_large)
	else:
		h_large = 0.0

	if _height_small_noise:
		h_small = sample_noise(_height_small_noise, world_xz, _scale_small)
	elif _height_small_img:
		h_small = sample_texture_r(_height_small_img, _height_small_size, world_xz * _scale_small)
	else:
		h_small = 0.0

	return (h_large * _amp_large) + (h_small * _amp_small)


func update_position_camera() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	var cp = camera.global_position
	global_position = Vector3(round(cp.x), global_position.y, round(cp.z))




