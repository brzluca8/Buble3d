extends SceneTree
## Transformă iconițele SVG (Lucide, ISC) în PNG 128 px pentru joc:
##   godot --headless --path godot -s ../tools/render_icons.gd -- <dosar_svg> <dosar_png>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var d := DirAccess.open(a[0])
	for f in d.get_files():
		if not f.ends_with(".svg"):
			continue
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(a[0] + "/" + f), 128.0 / 24.0)
		img.save_png(a[1] + "/" + f.replace(".svg", ".png"))
	print("gata")
	quit()
