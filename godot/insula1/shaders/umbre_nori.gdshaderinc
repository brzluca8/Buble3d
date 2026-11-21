// Insula 1 (v4): umbrele norilor care trec peste insulă (zgomot procedural în coordonatele lumii, fără textură).
// `nori_deplasare` (metri) o mută insula1.gd în fiecare cadru, după vânt; `nori_umbra` = cât de întunecată e umbra
// (0 la calitatea Mic și la mișcare redusă). Același zgomot dă și rafalele de vânt care trec peste iarbă și copaci.
#ifndef UMBRE_NORI_INC
#define UMBRE_NORI_INC
global uniform vec2 nori_deplasare;
global uniform float nori_umbra;

float nori_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float nori_zgomot(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(nori_hash(i), nori_hash(i + vec2(1.0, 0.0)), u.x),
			mix(nori_hash(i + vec2(0.0, 1.0)), nori_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float umbra_nori(vec3 pos) {
	if (nori_umbra <= 0.0) {
		return 1.0;
	}
	vec2 q = (pos.xz - nori_deplasare) / 14.0;
	float n = nori_zgomot(q) * 0.65 + nori_zgomot(q * 2.3 + vec2(5.2, 1.3)) * 0.35;
	return 1.0 - smoothstep(0.55, 0.75, n) * nori_umbra;
}
#endif
