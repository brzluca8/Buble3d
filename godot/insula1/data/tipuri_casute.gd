# Insula 1: tipurile căsuțelor, DOAR pentru aspect (iconiță, inel luminos, culoarea aprinderii).
# Proiectul nu avea tipuri de căsuțe (doar START = 0), iar logica jocului nu citește lista asta.
# E o propunere: schimbă indicii sau tipurile aici, fără să atingi jocul.
extends RefCounted

const TIPURI := {
	0: "start",
	4: "cufar",
	8: "zar",
	11: "eveniment",
	15: "carte",
	18: "cufar",
}

const CULORI := {
	"simpla": Color(1.0, 0.86, 0.5),
	"start": Color(1.0, 0.82, 0.3),
	"cufar": Color(1.0, 0.62, 0.22),
	"zar": Color(0.35, 0.9, 1.0),
	"eveniment": Color(0.78, 0.45, 1.0),
	"carte": Color(0.45, 1.0, 0.65),
}

# poziția iconiței în atlasul insula1/textures/iconite_casute.png (5 pe orizontală)
const ICONITA := {"start": 0, "cufar": 1, "zar": 2, "eveniment": 3, "carte": 4}


static func tip(i: int) -> String:
	return TIPURI.get(i, "simpla")
