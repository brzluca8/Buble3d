# Căsuțele drumului de pe insula1 (generat de blender/island_prep.py): metri, Y în sus, Z spre cameră.
extends RefCounted

const RAZA := 0.760  # raza unei căsuțe
const PAS := 1.900  # distanța obișnuită dintre două căsuțe vecine
const CASUTE: Array[Vector3] = [
	Vector3(0.069, 0.000, 6.523),
	Vector3(3.025, -0.017, 6.315),
	Vector3(5.000, -0.014, 5.668),
	Vector3(6.293, -0.000, 4.075),
	Vector3(7.632, 0.080, 2.251),
	Vector3(8.094, 0.097, 0.542),
	Vector3(7.817, 0.086, -1.340),
	Vector3(5.427, 0.785, -4.158),
	Vector3(4.238, 0.909, -5.312),
	Vector3(2.702, 0.960, -6.294),
	Vector3(0.843, 0.975, -6.675),
	Vector3(-1.062, 0.920, -6.317),
	Vector3(-2.679, 0.945, -5.509),
	Vector3(-4.261, 0.910, -4.735),
	Vector3(-5.612, 0.871, -3.453),
	Vector3(-6.605, 0.868, -1.571),
	Vector3(-6.963, 0.852, -0.047),
	Vector3(-6.893, 0.844, 1.419),
	Vector3(-6.454, 0.843, 2.897),
	Vector3(-5.970, 0.796, 4.283),
	Vector3(-3.129, 0.080, 5.357),
	Vector3(-1.513, 0.013, 6.084),
]
