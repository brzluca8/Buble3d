# Insula 1 v2: clădirile mari, pe faze (generat de blender/insula_v2/build_props.py).
# poz = Vector3 Godot (metri), rot = grade în jurul verticalei. Faza 1 natură, 2 sat, 3 castel/port/portal.
extends RefCounted

const PROPS := [
	{"id": "castel", "fisier": "castel", "poz": Vector3(0.250, 0.500, -0.550), "rot": 0.0, "faza": 3},
	{"id": "moara", "fisier": "moara", "poz": Vector3(-3.100, 0.819, -7.750), "rot": -20.0, "faza": 2},
	{"id": "portal", "fisier": "portal", "poz": Vector3(6.700, 0.659, -5.800), "rot": -35.0, "faza": 3},
	{"id": "piata", "fisier": "piata", "poz": Vector3(5.400, -0.380, -0.300), "rot": -90.0, "faza": 2},
	{"id": "atelier", "fisier": "atelier", "poz": Vector3(-5.300, -1.384, 7.100), "rot": 30.0, "faza": 2},
	{"id": "debarcader", "fisier": "debarcader", "poz": Vector3(-2.800, -2.190, 8.000), "rot": 10.0, "faza": 3},
	{"id": "barca", "fisier": "barca", "poz": Vector3(-0.550, -2.640, 9.300), "rot": -80.0, "faza": 3},
	{"id": "pod_sus", "fisier": "pod", "poz": Vector3(-2.150, 0.420, -3.300), "rot": 130.4, "faza": 1},
	{"id": "pod_jos", "fisier": "pod", "poz": Vector3(-3.660, 0.420, 1.700), "rot": -148.9, "faza": 1},
	{"id": "copac_mare", "fisier": "copac_mare", "poz": Vector3(5.000, 0.808, -6.900), "rot": 20.0, "faza": 1},
]
