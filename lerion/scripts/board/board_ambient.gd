extends Node3D
## Decorative motion uses local time only. The fountain and flags retain their painted meshes.
@onready var gem: MeshInstance3D = $"../Fantana".find_child("CristalCentral",true,false)
var flags: Array[MeshInstance3D] = []
var anchors := PackedVector3Array()
var butterflies: Array[MeshInstance3D] = []
var beads := MultiMesh.new()
var ripples := MultiMesh.new()
var embers := MultiMesh.new()
@onready var village := $"../Sat"
var step_time := 1.0/30.0
var accumulated := 0.0
var reduced := false
var age := 0.0
var jets := 6
var gust := 0.0


func _ready() -> void:
	var light: WorldEnvironment = $"../Lumina"
	var air := light.environment.duplicate() as Environment
	# Etapa 4.3: a little less fill and haze, a warmer key light. Shadows and forms read better while
	# the far hills keep a soft aerial blue. The palette and the models are unchanged.
	air.ambient_light_color = Color("#e3ecff")
	air.ambient_light_energy = 0.41
	air.fog_light_color = Color("#a9d8e8")
	air.fog_density = 0.0024
	light.environment = air
	var jewel := StandardMaterial3D.new()
	jewel.vertex_color_use_as_albedo = true
	jewel.roughness = 0.25
	jewel.metallic_specular = 0.47
	jewel.emission_enabled = true
	jewel.emission = Color("#19566d")
	jewel.emission_energy_multiplier = 0.28
	gem.material_override = jewel
	_make_embers()
	for flag: MeshInstance3D in $"../Castel".find_children("Steag*","MeshInstance3D",true,false):
		flags.append(flag)
		var bounds := flag.get_aabb()
		anchors.append(Vector3(bounds.position.x,bounds.get_center().y,bounds.get_center().z))
	var pearl := SphereMesh.new()
	pearl.radius = 0.057
	pearl.height = 0.095
	pearl.radial_segments = 6
	pearl.rings = 2
	var water := StandardMaterial3D.new()
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.albedo_color = Color("#dcffff")
	pearl.material = water
	beads.transform_format = MultiMesh.TRANSFORM_3D
	beads.mesh = pearl
	beads.instance_count = 8
	var streams := MultiMeshInstance3D.new()
	streams.multimesh = beads
	streams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streams)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.14
	ring.outer_radius = 0.17
	ring.rings = 16
	ring.ring_segments = 4
	ring.material = water
	ripples.transform_format = MultiMesh.TRANSFORM_3D
	ripples.mesh = ring
	ripples.instance_count = 8
	var foam := MultiMeshInstance3D.new()
	foam.multimesh = ripples
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)
	var silk := ShaderMaterial.new()
	silk.shader = preload("res://assets/board/butterfly.gdshader")
	silk.set_shader_parameter("wings",preload("res://assets/board/butterfly.svg"))
	var wings := PlaneMesh.new()
	wings.size = Vector2(0.43,0.34)
	wings.subdivide_width = 1
	wings.material = silk
	for i in range(2):
		var insect := MeshInstance3D.new()
		insect.mesh = wings
		insect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(insect)
		butterflies.append(insect)


func _process(delta: float) -> void:
	age += delta
	accumulated += delta
	if accumulated < step_time:
		return
	accumulated = fmod(accumulated,step_time)
	gust = maxf(0.0,gust - step_time*0.6)
	if not reduced:
		_drift_embers()
	var breath := 0.5-0.5*cos(age*2.0)
	gem.scale = Vector3.ONE * (1.0+0.035*breath+0.012*sin(age*5.3))
	gem.position.y = 0.012*breath
	for i in range(flags.size()):
		var wave := (sin(age*2.8+i) * 0.15 + sin(age*4.3+i)*0.05 + sin(age*1.1+i*0.7)*0.08)*(1.0 + 2.5*gust) + sin(age*9.0+i)*0.08*gust
		var turn := Basis(Vector3.UP,wave) * Basis(Vector3.BACK,0.06*sin(age*3.3+i*1.7) + 0.03*sin(age*5.1+i))
		flags[i].transform = Transform3D(turn,anchors[i]-turn*anchors[i])
	for i in range(jets):
		var t := fposmod(age*1.16+i*0.27,1.0)
		var axis := Vector2.from_angle((i+0.5)*TAU/jets)
		var distance := 0.62+0.52*t
		var height := 1.045+0.82*t-1.21*t*t
		beads.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(axis.x*distance,height,axis.y*distance)))
		var radius := 0.2+0.9*t
		var waterline := Vector3(axis.x*1.08,0.624-0.032*smoothstep(0.75,1.0,t),axis.y*1.08)
		ripples.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(radius,0.35,radius)),waterline))
	for i in range(butterflies.size()):
		if not butterflies[i].visible:
			continue
		var t := age*0.95+i*2.4
		var patch := Vector3(-2.2,0.68,5.2) if i == 0 else Vector3(2.1,0.86,-4.1)
		butterflies[i].position = patch + Vector3(0.56*sin(t),0.15*sin(2.0*t),0.27*sin(t*2))
		butterflies[i].rotation = Vector3(0.42,atan2(cos(t),cos(2.0*t)),0.16*sin(t))

func _make_embers() -> void:
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.vertex_color_use_as_albedo = true
	var mote := PrismMesh.new()
	mote.size = Vector3(0.16,0.26,0.12)
	mote.material = light
	embers.transform_format = MultiMesh.TRANSFORM_3D
	embers.use_colors = true
	embers.mesh = mote
	embers.instance_count = 8
	for i in range(8):
		embers.set_instance_color(i,Color("#b0f5ff") if i < 4 else Color("#efb9ff"))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = embers
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	_drift_embers()

func _drift_embers() -> void:
	var lab_built: bool = village.models.size() > 3 and village.models[3].visible
	embers.visible_instance_count = 8 if lab_built else 4
	for i in range(embers.visible_instance_count):
		var center := Vector3(0,1.48,0)
		if i >= 4:
			center = village.models[3].position + Vector3(0,1.77,0)
		var cycle := fposmod(age*0.46 + i*0.62,3.0)
		var t := minf(1.0,cycle)
		var a := i*2.4 + t*1.8
		var size_m := maxf(0.001,sin(PI*t))
		var point := center + Vector3(cos(a)*0.64,t*1.08,sin(a)*0.51)
		embers.set_instance_transform(i,Transform3D(Basis(Vector3.UP,a).scaled(Vector3.ONE*size_m),point))

func configure(tier: int, fewer: bool) -> void:
	reduced = fewer
	jets = [4,6,8][tier]
	beads.visible_instance_count = jets
	ripples.visible_instance_count = jets
	step_time = 1.0/[15.0,24.0,30.0][tier]
	for i in range(butterflies.size()):
		butterflies[i].visible = not fewer and i < tier
	if fewer:
		embers.visible_instance_count = 0
	else:
		_drift_embers()


## A strong breeze for a moment (kingdom awakening). Flags flap harder and settle back.
func blow(strength := 1.0) -> void:
	gust = maxf(gust,strength)
