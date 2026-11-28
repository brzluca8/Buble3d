extends Control
## Prize icon of the wheel result: a flat texture (energy) or a chest drawn by ChestArt, so a won
## chest is the same chest the player will open next.
const ChestArt := preload("res://scripts/crystal/chest_art.gd")
var texture: Texture2D
var chest_kind := ""
var age := 0.0


func show_texture(image: Texture2D, tint: Color) -> void:
	texture = image
	chest_kind = ""
	modulate = tint
	set_process(false)
	queue_redraw()


func show_chest(kind: String) -> void:
	chest_kind = kind
	texture = null
	modulate = Color.WHITE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	if chest_kind != "":
		# 300x260 design space scaled into the control, centred on the chest body.
		var scale_f := minf(size.x/300.0,size.y/260.0)*1.05
		var offset := Vector2((size.x - 300.0*scale_f)*0.5,(size.y - 260.0*scale_f)*0.5 - 6.0)
		ChestArt.draw(self,chest_kind,0.0,0.0,age,true,Transform2D(Vector2(scale_f,0),Vector2(0,scale_f),offset))
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	elif texture:
		var side := minf(size.x,size.y)
		draw_texture_rect(texture,Rect2((size - Vector2.ONE*side)*0.5,Vector2.ONE*side),false)
