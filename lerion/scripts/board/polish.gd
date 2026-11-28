extends Node3D
## Visual polish for the kingdom. Presentation only: it reads positions and quality and never touches
## the save or the rules. Every effect has a budget per quality tier and can be switched off:
##   ambient_on  fireflies, dust, leaves, crystal and building glints, START beacon
##   special_on  landing rings, dust puffs, sparkle bursts, emotes
##   post_on     colour grade and soft bloom (bloom only on tier 1 and 2)
## Android notes: all ambient motes are three MultiMeshes (three draw calls), bursts are short
## one-shot CPUParticles3D capped by `budget`, rings are pooled-size tweens. No dynamic lights.
const TIERS := [
	{"fireflies": 8, "dust": 0, "leaves": 0, "sparkles": 4, "glints": 3, "puffs": 5, "burst": 8, "rings": 2, "glow": false},
	{"fireflies": 16, "dust": 10, "leaves": 4, "sparkles": 6, "glints": 6, "puffs": 8, "burst": 14, "rings": 3, "glow": true},
	{"fireflies": 24, "dust": 16, "leaves": 6, "sparkles": 8, "glints": 6, "puffs": 12, "burst": 22, "rings": 4, "glow": true}]
const ICONS := {"coins": preload("res://assets/crystal/coin.svg"), "fragments": preload("res://assets/crystal/crystal.svg"),
	"build_points": preload("res://assets/crystal/hammer.svg"), "quest_tokens": preload("res://assets/crystal/challenge.svg"),
	"energy": preload("res://assets/crystal/energy.svg"), "chest": preload("res://assets/crystal/chest.svg")}
const PIVOTS := [Vector3(-0.38,0.82,0.58), Vector3(0,1.48,0.65), Vector3(0,1.81,0.79),
	Vector3(-0.66,0.57,0.54), Vector3(0.72,1.64,-0.18), Vector3(1.03,1.13,0.56)]
static var star_texture: ImageTexture
static var soft_texture: GradientTexture2D

var ambient_on := true
var special_on := true
var post_on := true
var tier := 1
var reduced := false
var age := 0.0
var accumulated := 0.0
var path: Node
var village: Node
var crystal_center := Vector3(0,1.5,0)
var fx_root := Node3D.new()
var motes := {}
var start_beacon: MeshInstance3D
var start_ring: MeshInstance3D
var start_material: StandardMaterial3D
var ring_material: StandardMaterial3D
var seeds := PackedFloat32Array()
var environment: Environment
var live_rings := 0


static func make_textures() -> void:
	if star_texture == null:
		var image := Image.create(48,48,false,Image.FORMAT_RGBA8)
		for y in range(48):
			for x in range(48):
				var p := Vector2((x - 23.5)/24.0,(y - 23.5)/24.0)
				# Four-point star (astroid) plus a soft core.
				var star := 1.0 - (pow(absf(p.x),0.5) + pow(absf(p.y),0.5))*1.05
				var core := 1.0 - p.length()*2.2
				var a := clampf(maxf(star,core*0.9),0.0,1.0)
				image.set_pixel(x,y,Color(1,1,1,a*a if a < 0.6 else a))
		star_texture = ImageTexture.create_from_image(image)
	if soft_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0,Color(1,1,1,1))
		gradient.set_color(1,Color(1,1,1,0))
		soft_texture = GradientTexture2D.new()
		soft_texture.gradient = gradient
		soft_texture.fill = GradientTexture2D.FILL_RADIAL
		soft_texture.fill_from = Vector2(0.5,0.5)
		soft_texture.fill_to = Vector2(0.5,0.0)
		soft_texture.width = 64
		soft_texture.height = 64


func glow_material(texture: Texture2D, billboard := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	return material


func _batch(name: String, texture: Texture2D, size: float, count: int, billboard := true) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size,size)
	quad.material = glow_material(texture,billboard)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-14,-1,-16),Vector3(28,12,32))
	add_child(node)
	motes[name] = node
	return node


func setup(loop_path: Node, sat: Node, crystal_point: Vector3) -> void:
	make_textures()
	path = loop_path
	village = sat
	crystal_center = crystal_point
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	for i in range(160):
		seeds.append(rng.randf())
	add_child(fx_root)
	fx_root.name = "Efecte"
	_batch("fireflies",soft_texture,0.2,TIERS[2].fireflies)
	_batch("dust",soft_texture,0.1,TIERS[2].dust)
	var leaf := _batch("leaves",null,0.2,TIERS[2].leaves,false)
	leaf.multimesh.mesh.material.albedo_texture = null
	leaf.multimesh.mesh.material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_batch("sparkles",star_texture,0.34,TIERS[2].sparkles)
	_batch("glints",star_texture,0.5,TIERS[2].glints)
	for i in range(TIERS[2].leaves):
		leaf.multimesh.set_instance_color(i,Color("#8fdc66") if i % 3 != 0 else Color("#ff9fc4"))
	_build_beacon()
	_apply()
	set_process(true)


func _build_beacon() -> void:
	var origin: Vector3 = path.centers[0] if path and path.centers.size() > 0 else Vector3(0,0,12)
	start_material = glow_material(soft_texture,false)
	var disc := QuadMesh.new()
	disc.size = Vector2(2.6,2.6)
	disc.orientation = PlaneMesh.FACE_Y
	disc.material = start_material
	start_beacon = MeshInstance3D.new()
	start_beacon.mesh = disc
	start_beacon.position = origin + Vector3.UP*0.2
	start_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(start_beacon)
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.albedo_color = Color(1,0.9,0.5,0.6)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 3
	torus.material = ring_material
	start_ring = MeshInstance3D.new()
	start_ring.mesh = torus
	start_ring.position = origin + Vector3.UP*0.2
	start_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(start_ring)


# ---- Settings ---------------------------------------------------------------------------------

func configure(quality: int, fewer: bool) -> void:
	tier = clampi(quality,0,2)
	reduced = fewer
	_apply()


func budget() -> Dictionary:
	return TIERS[tier]


func set_toggle(key: String, on: bool) -> void:
	match key:
		"ambient": ambient_on = on
		"special": special_on = on
		"post": post_on = on
	_apply()


func ambient_active() -> bool:
	return ambient_on and not reduced


func special_active() -> bool:
	return special_on and not reduced


func _apply() -> void:
	if not is_inside_tree() and motes.is_empty():
		return
	var spec: Dictionary = budget()
	var show := ambient_active()
	for key: String in ["fireflies","dust","leaves","sparkles","glints"]:
		if not motes.has(key):
			continue
		var node: MultiMeshInstance3D = motes[key]
		node.visible = show
		node.multimesh.visible_instance_count = int(spec[key])
	if start_beacon:
		start_beacon.visible = show
		start_ring.visible = show
	_apply_environment()
	set_process(show or special_on)


## Colour grade and soft bloom. Filmic and ACES tone mappers washed the sky and fog out in tests, so the
## mapper stays linear; the grade is a slight contrast and saturation lift. Bloom is screen-blended with
## a high threshold, so it only picks up emissive and additive things (crystal, magic, gold, chests).
## Bloom is skipped on the low tier and with reduced effects.
func _apply_environment() -> void:
	var holder := get_node_or_null("../Lumina") as WorldEnvironment
	if holder == null or holder.environment == null:
		return
	environment = holder.environment
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.adjustment_enabled = post_on
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.12
	var glow_on: bool = post_on and not reduced and bool(budget().glow)
	environment.glow_enabled = glow_on
	environment.glow_intensity = 0.4
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN


# ---- Ambient motion ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	age += delta
	accumulated += delta
	if accumulated < (1.0/20.0 if tier == 0 else 1.0/30.0):
		return
	accumulated = 0.0
	if ambient_active():
		_drift_fireflies()
		_drift_dust()
		_drift_leaves()
		_twinkle_sparkles()
		_twinkle_glints()
		_pulse_beacon()


func _s(i: int) -> float:
	return seeds[i % seeds.size()]


func _drift_fireflies() -> void:
	var multi: MultiMesh = motes.fireflies.multimesh
	for i in range(multi.visible_instance_count):
		var base := Vector3((_s(i*3) - 0.5)*13.0,0.6 + _s(i*3 + 1)*1.6,(_s(i*3 + 2) - 0.45)*16.0)
		# Keep clear of the central fountain pad so the crystal stays readable.
		if Vector2(base.x,base.z).length() < 2.6:
			base.x += 3.2*signf(base.x + 0.01)
		var t := age*(0.25 + _s(i + 40)*0.3) + _s(i + 80)*TAU
		var p := base + Vector3(sin(t)*0.7,sin(t*1.7)*0.25,cos(t*0.8)*0.7)
		var blink := pow(maxf(0.0,sin(age*(0.7 + _s(i + 20)) + _s(i + 60)*TAU)),2.0)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.6 + 0.6*blink)),p))
		multi.set_instance_color(i,Color(1.0,0.9,0.5,0.25 + 0.6*blink) if i % 3 != 0 else Color(0.65,1.0,0.85,0.2 + 0.5*blink))


func _drift_dust() -> void:
	var multi: MultiMesh = motes.dust.multimesh
	for i in range(multi.visible_instance_count):
		var t := fposmod(age*0.05*(0.6 + _s(i + 5)) + _s(i + 90),1.0)
		var p := Vector3(-7.0 + t*14.0 + sin(age*0.3 + i)*0.4,0.5 + _s(i + 11)*3.6 + sin(age*0.4 + i*1.3)*0.25,(_s(i + 33) - 0.5)*14.0)
		var fade := sin(PI*t)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.8 + 0.5*_s(i + 7))),p))
		multi.set_instance_color(i,Color(1.0,0.97,0.82,0.32*fade))


func _drift_leaves() -> void:
	var multi: MultiMesh = motes.leaves.multimesh
	for i in range(multi.visible_instance_count):
		var t := fposmod(age*0.07*(0.7 + _s(i + 3)) + _s(i + 50),1.0)
		var origin := Vector3(-8.5 if i % 2 == 0 else 8.0,6.2,(_s(i + 70) - 0.3)*8.0)
		var p := origin + Vector3(sin(t*TAU*2.0 + i)*1.4 + (t*2.5 if i % 2 == 0 else -t*2.5),-t*5.8,sin(t*TAU*1.5 + i*2.0)*0.8)
		var spin := Basis(Vector3(0.3,1,0.2).normalized(),age*1.7 + i*1.9)*Basis(Vector3.RIGHT,sin(age*2.0 + i)*0.9)
		multi.set_instance_transform(i,Transform3D(spin,p))
		var tint := Color("#8fdc66") if i % 3 != 0 else Color("#ff9fc4")
		multi.set_instance_color(i,Color(tint,1.0 - smoothstep(0.85,1.0,t)))


func _twinkle_sparkles() -> void:
	var multi: MultiMesh = motes.sparkles.multimesh
	for i in range(multi.visible_instance_count):
		var angle := age*0.5 + TAU*i/maxf(1.0,multi.visible_instance_count)
		var radius := 0.85 + 0.25*sin(age*0.9 + i*2.0)
		var lift := fposmod(age*0.22 + i*0.173,1.0)
		var p := crystal_center + Vector3(cos(angle)*radius,-0.55 + lift*1.9,sin(angle)*radius)
		var twinkle := pow(maxf(0.0,sin(age*2.4 + i*1.7)),3.0)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.35 + 0.9*twinkle*sin(PI*lift))),p))
		multi.set_instance_color(i,Color("#d8f6ff") if i % 2 == 0 else Color("#fff0b0"))


func _twinkle_glints() -> void:
	var multi: MultiMesh = motes.glints.multimesh
	if village == null:
		return
	for i in range(multi.visible_instance_count):
		var model: Node3D = village.models[i] if i < village.models.size() else null
		if model == null or not model.visible:
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.0001),Vector3.ZERO))
			continue
		var cycle := fposmod(age*0.32 + _s(i + 100)*3.0,1.0)
		var flash := pow(sin(PI*clampf(cycle*3.0,0.0,1.0)),2.0) if cycle < 0.34 else 0.0
		var spot: Vector3 = model.global_position + PIVOTS[i] + Vector3(0.12*sin(i*2.3),0.18,0.25)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.15 + 1.0*flash)),spot))
		multi.set_instance_color(i,Color(1.0,0.95,0.75,0.9*flash))


func _pulse_beacon() -> void:
	var breath := 0.5 + 0.5*sin(age*2.2)
	start_material.albedo_color = Color(1.0,0.82,0.45,0.18 + 0.2*breath)
	start_beacon.scale = Vector3.ONE*(0.9 + 0.12*breath)
	var cycle := fposmod(age*0.45,1.0)
	start_ring.scale = Vector3.ONE*lerpf(0.55,1.25,cycle)
	ring_material.albedo_color = Color(1.0,0.9,0.55,0.55*(1.0 - cycle))


# ---- Short effects ----------------------------------------------------------------------------

func active_effects() -> int:
	return fx_root.get_child_count()


## Expanding light ring on the ground. Pooled by the budget: extra requests are dropped.
func ring_burst(point: Vector3, color: Color, radius := 1.8, duration := 0.55) -> void:
	if not special_active() or live_rings >= int(budget().rings):
		return
	live_rings += 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color,0.9)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 3
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = point + Vector3.UP*0.12
	ring.scale = Vector3.ONE*0.2
	fx_root.add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring,"scale",Vector3.ONE*radius,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,duration)
	tween.chain().tween_callback(func() -> void:
		live_rings -= 1
		ring.queue_free())


func _particles(point: Vector3, color: Color, count: int, speed: float, lifetime: float, size: float, upward := false, texture: Texture2D = null) -> void:
	if not special_active() or count <= 0:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(size,size)
	quad.material = glow_material(texture if texture else soft_texture)
	var cloud := CPUParticles3D.new()
	cloud.mesh = quad
	cloud.amount = mini(count,int(budget().burst))
	cloud.one_shot = true
	cloud.explosiveness = 0.95
	cloud.lifetime = lifetime
	cloud.direction = Vector3.UP if upward else Vector3(0,0.6,0)
	cloud.spread = 38.0 if upward else 80.0
	cloud.initial_velocity_min = speed*0.5
	cloud.initial_velocity_max = speed
	cloud.gravity = Vector3(0,-2.2 if upward else -3.2,0)
	cloud.scale_amount_min = 0.5
	cloud.scale_amount_max = 1.2
	cloud.scale_amount_curve = _shrink_curve()
	cloud.color = color
	cloud.position = point
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(cloud)
	cloud.finished.connect(cloud.queue_free)
	cloud.emitting = true


static var _curve: Curve
static func _shrink_curve() -> Curve:
	if _curve == null:
		_curve = Curve.new()
		_curve.add_point(Vector2(0,0.2))
		_curve.add_point(Vector2(0.2,1.0))
		_curve.add_point(Vector2(1,0.0))
	return _curve


func dust_puff(point: Vector3, strength := 1.0) -> void:
	_particles(point + Vector3.UP*0.1,Color(1.0,0.96,0.85,0.55),roundi(int(budget().puffs)*strength),1.4,0.5,0.3)


func sparkle_burst(point: Vector3, color: Color, strength := 1.0) -> void:
	_particles(point,color,roundi(int(budget().burst)*strength),2.4,0.8,0.32,true,star_texture)


## Landing on the final tile: ring in the tile category colour, dust and, for rare tiles, sparks.
func landing(point: Vector3, color: Color, rare := false) -> void:
	ring_burst(point,color,1.5 if not rare else 2.2,0.5 if not rare else 0.7)
	dust_puff(point,1.0 if not rare else 1.4)
	if rare:
		sparkle_burst(point + Vector3.UP*0.5,color,1.0)


func step_dust(point: Vector3) -> void:
	if tier > 0:
		_particles(point + Vector3.UP*0.05,Color(1.0,0.96,0.85,0.4),3,0.8,0.35,0.2)


func start_burst(point: Vector3) -> void:
	ring_burst(point,Color("#ffd866"),2.4,0.75)
	sparkle_burst(point + Vector3.UP*0.6,Color("#ffe58a"),1.0)


func upgrade_burst(point: Vector3) -> void:
	ring_burst(point,Color("#ffe58a"),2.6,0.7)
	sparkle_burst(point + Vector3.UP*0.8,Color("#fff0a8"),1.2)


## Dice touching the grass: a dust puff and a ground ring sized by the impact.
func dice_impact(points: Array, strength: float) -> void:
	for point: Vector3 in points:
		ring_burst(Vector3(point.x,0.05,point.z),Color(1.0,0.95,0.8),0.9 + 0.9*strength,0.42)
		dust_puff(Vector3(point.x,0.02,point.z),0.6 + 0.6*strength)


## Both dice at rest: a gold ring marks each final face.
func dice_settle(points: Array) -> void:
	for point: Vector3 in points:
		ring_burst(Vector3(point.x,0.05,point.z),Color("#ffd866"),1.3,0.5)
		_particles(point + Vector3.UP*0.6,Color("#fff0b0"),5,1.2,0.5,0.24,true,star_texture)


## Activation: motes appear around the fountain and are pulled into the crystal.
func crystal_gather() -> void:
	if not special_active():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3,0.3)
	quad.material = glow_material(star_texture)
	var cloud := CPUParticles3D.new()
	cloud.mesh = quad
	cloud.amount = int(budget().burst) + 8
	cloud.one_shot = true
	cloud.explosiveness = 0.7
	cloud.lifetime = 0.62
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	cloud.emission_sphere_radius = 3.0
	cloud.gravity = Vector3.ZERO
	cloud.radial_accel_min = -16.0
	cloud.radial_accel_max = -12.0
	cloud.damping_min = 2.0
	cloud.damping_max = 3.0
	cloud.color = Color("#b6f1ff")
	cloud.color_ramp = _gather_ramp()
	cloud.position = crystal_center
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(cloud)
	cloud.finished.connect(cloud.queue_free)
	cloud.emitting = true


static var _ramp: Gradient
static func _gather_ramp() -> Gradient:
	if _ramp == null:
		_ramp = Gradient.new()
		_ramp.set_color(0,Color(0.7,0.95,1.0,0.0))
		_ramp.add_point(0.3,Color(0.7,0.95,1.0,1.0))
		_ramp.set_color(1,Color(1.0,0.9,0.5,1.0))
	return _ramp


## The magic wave that leaves the fountain when the wheel opens.
func crystal_wave() -> void:
	ring_burst(crystal_center - Vector3.UP*1.2,Color("#8fe9ff"),5.5,0.9)
	ring_burst(crystal_center - Vector3.UP*1.15,Color("#ffe58a"),3.6,0.7)


## Kingdom awakening: a wave of light runs over every tile in order of distance from `origin`.
func tile_wave(centers: PackedVector3Array, origin: Vector3, duration := 1.5) -> void:
	if not special_active() or centers.is_empty():
		return
	var disc := QuadMesh.new()
	disc.size = Vector2(1.5,1.5)
	disc.orientation = PlaneMesh.FACE_Y
	disc.material = glow_material(soft_texture,false)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = disc
	batch.instance_count = centers.size()
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-14,-1,-16),Vector3(28,4,32))
	fx_root.add_child(node)
	var far := 0.0
	for c in centers:
		far = maxf(far,Vector2(c.x - origin.x,c.z - origin.z).length())
	var wave := node.create_tween()
	wave.tween_method(func(t: float) -> void:
		for i in range(centers.size()):
			var d := Vector2(centers[i].x - origin.x,centers[i].z - origin.z).length()/maxf(1.0,far)
			var k := clampf((t*1.35 - d*0.9)/0.35,0.0,1.0)
			var glow := sin(PI*k)
			var tint := Color("#8fe9ff").lerp(Color("#ffe58a"),d)
			batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.6 + 0.6*glow)),centers[i] + Vector3.UP*0.24))
			batch.set_instance_color(i,Color(tint,0.85*glow)),0.0,1.0,duration)
	wave.tween_callback(node.queue_free)


## Pufi's sneeze: soft bubbles in three colours plus a pop of stars.
func bubble_burst(point: Vector3) -> void:
	for colour in [Color("#ff9fd6"),Color("#9ff0ff"),Color("#fff09a")]:
		_particles(point,colour,6,1.6,1.1,0.34,true)
	sparkle_burst(point,Color("#e8c4ff"),0.8)


## Pongo's comic accident: a plank jumps off the building, spins and drops back.
func plank_jump(point: Vector3) -> void:
	if not special_active():
		return
	var plank := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(0.42,0.06,0.13)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#b9783f")
	board.material = wood
	plank.mesh = board
	fx_root.add_child(plank)
	plank.global_position = point
	var flight := plank.create_tween()
	flight.tween_method(func(t: float) -> void:
		plank.global_position = point + Vector3(0.25*t,1.6*sin(PI*t*0.92),0.2*t)
		plank.rotation = Vector3(t*7.0,t*2.0,t*5.0),0.0,1.0,0.85)
	flight.tween_property(plank,"scale",Vector3.ONE*0.01,0.12)
	flight.tween_callback(plank.queue_free)


func crystal_burst() -> void:
	ring_burst(crystal_center - Vector3.UP*0.9,Color("#8fe9ff"),2.6,0.8)
	sparkle_burst(crystal_center,Color("#b6f1ff"),1.0)


## An icon of the won resource that pops above Lerik's head, rises and fades.
func emote(point: Vector3, key: String) -> void:
	if not special_active() or not ICONS.has(key):
		return
	var icon := Sprite3D.new()
	icon.texture = ICONS[key]
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.pixel_size = 0.0035
	icon.shaded = false
	icon.no_depth_test = true
	icon.render_priority = 3
	icon.position = point
	icon.scale = Vector3.ONE*0.2
	fx_root.add_child(icon)
	var tween := icon.create_tween()
	tween.tween_property(icon,"scale",Vector3.ONE*1.15,0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon,"position:y",point.y + 0.6,0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(icon,"scale",Vector3.ONE,0.1)
	tween.tween_property(icon,"modulate:a",0.0,0.25).set_delay(0.18)
	tween.parallel().tween_property(icon,"position:y",point.y + 0.9,0.25)
	tween.tween_callback(icon.queue_free)
