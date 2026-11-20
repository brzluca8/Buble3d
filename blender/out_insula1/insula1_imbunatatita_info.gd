# Insula 1 îmbunătățită: date generate de blender/insula1/imbunatateste.py (metri, Y în sus).
extends RefCounted

const NIVEL_RAU := -1.411
## lacurile (laguna, iazurile): [nivel, centru]
const LACURI := [
	[-2.590, Vector3(-0.948, -2.504, 9.091)],
	[-2.930, Vector3(-0.446, -2.957, 10.983)],
	[-4.214, Vector3(2.957, -4.168, 6.599)],
	[-4.411, Vector3(2.944, -4.410, 7.161)],
]
## cascadele, cea mai înaltă prima: [buza, baza, lățimea]
const CASCADE := [
	[Vector3(3.328, -0.627, 8.559), Vector3(3.861, -6.642, 8.688), 2.12],
	[Vector3(-0.310, -3.090, 11.147), Vector3(-0.304, -5.403, 11.244), 1.20],
	[Vector3(0.958, 2.405, -8.386), Vector3(0.959, 1.161, -8.373), 0.52],
]
## portalul: centrul panoului, direcția spre care privește, mărimea (lățime, înălțime)
const PORTAL_CENTRU := Vector3(7.265, 1.699, -5.309)
const PORTAL_NORMALA := Vector3(-0.542, 0.000, 0.840)
const PORTAL_MARIME := Vector2(0.996, 1.417)
## densitatea texturii (pixeli pe metru); originalul avea 28
const DENSITATE := {"toata": 56}
