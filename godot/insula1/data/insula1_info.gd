# Insula 1 (v3, Faza A): date generate de blender/insula1/v3_faza_a.py (metri, Y în sus).
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

## moara: pivotul palelor (butucul) și axul de rotație
const MOARA_PIVOT := Vector3(-2.720, 2.739, -6.859)
const MOARA_AX := Vector3(0.538, -0.088, 0.838)
## barca: pivotul (mijlocul carenei, la nivelul apei) și direcția lungă a carenei
const BARCA_PIVOT := Vector3(-0.600, -2.590, 9.250)
const BARCA_AX := Vector3(0.821, 0.000, 0.571)
## flăcările felinarelor (halouri calde care pâlpâie)
const FLACARI: Array[Vector3] = [
	Vector3(-7.934, 1.459, 1.594),
	Vector3(-5.441, 0.818, 5.162),
	Vector3(6.483, 0.780, 1.864),
	Vector3(6.510, 0.350, 1.717),
	Vector3(9.321, 0.025, 0.249),
	Vector3(8.451, 0.468, 3.151),
	Vector3(1.433, 0.013, 7.775),
	Vector3(-2.801, -0.499, 8.825),
	Vector3(-3.598, -0.833, 6.738),
	Vector3(-1.668, -0.490, 7.506),
	Vector3(-2.632, -0.495, 7.323),
	Vector3(6.769, 2.011, -5.889),
	Vector3(8.049, 2.032, -5.011),
	Vector3(7.623, 0.896, -3.683),
	Vector3(-2.185, -0.358, 1.710),
	Vector3(6.182, 0.125, -1.626),
	Vector3(4.422, -0.076, -0.499),
	Vector3(-0.216, 0.893, 1.988),
	Vector3(-0.239, 3.419, -0.395),
	Vector3(-1.197, 3.195, 0.123),
	Vector3(-2.078, 1.671, 1.638),
	Vector3(-0.820, 1.904, 0.634),
	Vector3(-1.931, 1.533, -0.415),
	Vector3(-1.331, 1.909, -0.462),
	Vector3(3.360, 0.271, 2.174),
	Vector3(3.304, 0.111, 1.124),
	Vector3(0.993, 3.263, -1.697),
	Vector3(1.879, 3.201, 0.151),
	Vector3(2.839, 1.638, 1.610),
	Vector3(0.460, 1.919, -1.583),
	Vector3(1.963, 1.909, -0.503),
	Vector3(2.288, 1.918, 0.336),
	Vector3(2.336, 0.647, 4.327),
	Vector3(-2.871, 0.060, 4.452),
	Vector3(0.082, 0.615, 4.358),
	Vector3(-1.170, 0.394, 5.096),
	Vector3(-0.523, 1.174, -5.541),
	Vector3(1.269, 0.896, -5.683),
	Vector3(-6.818, 1.702, -6.204),
	Vector3(-5.319, 1.704, -7.251),
	Vector3(-2.935, 3.166, -7.138),
]
## obiectele insulei pe clase (numele din GLB), cu triunghiurile după simplificare
const CLASE := {"Insula_restul": 43226, "Apa": 1368, "Cascade": 1075, "Insula_stanci": 17046, "Insula_iarba": 5604, "Insula_frunzis": 27918, "Insula_flori": 4455, "Insula_panze": 161, "Insula_cristale": 423, "Insula_felinare": 2412, "Insula_portal": 1670, "Barca": 1562, "Moara_pale": 726}
