extends Node3D
## Visual state of the central Super Crystal. Presentation only: it reads a charge fraction
## and never touches the save. One billboard halo, one MultiMesh of motes, an optional light.
const MOTES := 10
var gem: MeshInstance3D
var light: OmniLight3D
var jewel: StandardMaterial3D
var halo := MeshInstance3D.new()
var halo_material := StandardMaterial3D.new()
var ring := MeshInstance3D.new()
var ring_material := StandardMaterial3D.new()
var motes := MultiMesh.new()
var mote_batch := MultiMeshInstance3D.new()
var fraction := 0.0
var charged := false
var reduced := false
var tier := 2
var age := 0.0
var accumulated := 0.0
var burst_age := -1.0
var pulse := 0.0
var invite := Label3D.new()
var invite_ring := MeshInstance3D.new()
var invite_material := StandardMaterial3D.new()
var spin_speed := 0.0
var center := Vector3(0,1.48,0)


func setup(crystal: MeshInstance3D, glow_light: OmniLight3D) -> void:
	gem = crystal
	light = glow_light
	jewel = gem.material_override as StandardMaterial3D
	var bounds := gem.get_aabb()
	center = gem.global_transform * bounds.get_center()
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,1))
	gradient.set_color(1,Color(1,1,1,0))
	var soft := GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5,0.5)
	soft.fill_to = Vector2(0.5,0.0)
	soft.width = 64
	soft.height = 64
	for material: StandardMaterial3D in [halo_material,ring_material]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.no_depth_test = false
		material.disable_receive_shadows = true
	halo_material.albedo_texture = soft
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6,2.6)
	quad.material = halo_material
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	halo.position = center
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	torus.material = ring_material
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = center - Vector3.UP*0.55
	ring.hide()
	var spark := PrismMesh.new()
	spark.size = Vector3(0.11,0.2,0.08)
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.vertex_color_use_as_albedo = true
	spark.material = shine
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.use_colors = true
	motes.mesh = spark
	motes.instance_count = MOTES
	for i in range(MOTES):
		motes.set_instance_color(i,Color("#ffe58a") if i % 2 == 0 else Color("#9ff3ff"))
	mote_batch.multimesh = motes
	mote_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mote_batch)
	# Fully charged: the crystal turns slowly, rings leave the basin and a short call to tap bobs above.
	invite_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	invite_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invite_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var band := TorusMesh.new()
	band.inner_radius = 0.95
	band.outer_radius = 1.0
	band.rings = 32
	band.ring_segments = 3
	band.material = invite_material
	invite_ring.mesh = band
	invite_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	invite_ring.position = center - Vector3.UP*0.95
	add_child(invite_ring)
	invite.text = "ATINGE!"
	invite.font_size = 64
	invite.pixel_size = 0.0055
	invite.outline_size = 14
	invite.modulate = Color("#ffe58a")
	invite.outline_modulate = Color("#1a3a6a")
	invite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	invite.no_depth_test = true
	invite.render_priority = 2
	add_child(invite)
	_apply(0.0)


func crystal_center() -> Vector3:
	return center


func set_progress(value: float, ready: bool) -> void:
	fraction = clampf(value,0.0,1.0)
	charged = ready
	_apply(0.0)


func configure(quality: int, fewer: bool) -> void:
	tier = quality
	reduced = fewer
	_apply(0.0)


## A short expanding ring when the wheel is summoned or a prize lands.
func burst() -> void:
	if reduced:
		return
	burst_age = 0.0
	ring.show()


## A quick bright beat, for example when a roll adds charge or the crystal becomes ready.
func pulse_now(strength := 1.0) -> void:
	pulse = maxf(pulse,strength)
	set_process(true)


func _process(delta: float) -> void:
	age += delta
	accumulated += delta
	if accumulated < 1.0/30.0:
		return
	_apply(accumulated)
	accumulated = 0.0


func _apply(_step: float) -> void:
	if gem == null:
		return
	var beat := 0.5 + 0.5*sin(age*(4.2 if charged else 2.0))
	if jewel:
		jewel.emission = Color("#19566d").lerp(Color("#7fe8ff"),fraction*0.6 + (0.4*beat if charged else 0.0))
		jewel.emission_energy_multiplier = 0.28 + 0.75*fraction + (0.9 + 0.7*beat if charged else 0.12*beat*fraction) + 1.6*pulse
	pulse = maxf(0.0,pulse - maxf(_step,1.0/30.0)*2.6)
	# Etapa 4.3: a faint, slow breath even when empty, so the heart of the kingdom never looks dead.
	var idle := 0.0 if reduced else 0.07*(0.5 + 0.5*sin(age*1.1))
	var glow := idle + fraction*0.26 + (0.26 + 0.16*beat if charged else 0.0) + 0.5*pulse
	halo.visible = glow > 0.03
	halo_material.albedo_color = Color(0.55,0.88,1.0,glow).lerp(Color(1.0,0.86,0.45,glow),0.35 if charged else 0.0)
	halo.scale = Vector3.ONE*(0.75 + 0.35*fraction + (0.12*beat if charged else 0.0) + 0.35*pulse)
	var show_motes := charged and not reduced
	mote_batch.visible = show_motes
	if show_motes:
		var count := MOTES if tier > 0 else MOTES/2
		motes.visible_instance_count = count
		for i in range(count):
			var a := age*1.3 + TAU*i/count
			var lift := fposmod(age*0.35 + i*0.13,1.0)
			var radius := 0.85 + 0.12*sin(age*2.0+i)
			var size := sin(PI*lift)
			var point := center + Vector3(cos(a)*radius,-0.7 + lift*1.7,sin(a)*radius)
			motes.set_instance_transform(i,Transform3D(Basis(Vector3.UP,a*2.0).scaled(Vector3.ONE*maxf(0.001,size)),point))
	if light:
		light.visible = charged and tier > 0 and not reduced or burst_age >= 0.0
		light.light_color = Color("#9fe9ff")
		light.light_energy = 0.9 + 0.8*beat if burst_age < 0.0 else 2.6*(1.0-burst_age)
	if burst_age >= 0.0:
		burst_age += maxf(_step,1.0/30.0)/0.7
		var t := clampf(burst_age,0.0,1.0)
		ring.scale = Vector3.ONE*lerpf(0.4,3.2,t)
		ring_material.albedo_color = Color(1.0,0.88,0.5,0.9*(1.0-t))
		if burst_age >= 1.0:
			burst_age = -1.0
			ring.hide()
	var calling := charged and not reduced
	invite.visible = calling
	invite_ring.visible = calling
	if calling:
		var hop := absf(sin(age*3.2))
		invite.position = center + Vector3.UP*(1.55 + 0.18*hop)
		invite.scale = Vector3.ONE*(1.0 + 0.08*(1.0 - hop))
		var cycle := fposmod(age*0.6,1.0)
		invite_ring.scale = Vector3.ONE*lerpf(0.9,3.0,cycle)
		invite_material.albedo_color = Color(0.6,0.95,1.0,0.7*(1.0 - cycle))
	spin_speed = lerpf(spin_speed,0.9 if charged else 0.0,0.1)
	if gem and spin_speed > 0.001:
		gem.rotation.y += spin_speed*maxf(_step,1.0/30.0)
	set_process(not reduced or fraction > 0.0 or charged or burst_age >= 0.0 or pulse > 0.0 or spin_speed > 0.001)
