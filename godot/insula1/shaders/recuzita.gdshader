// Insula 1 (v4): materialul opac al recuzitei noi (codul e în recuzita_comun.gdshaderinc).
// Fără cull: frunzele de palmier, firele de iarbă și petalele sunt benzi văzute din ambele părți.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://insula1/shaders/recuzita_comun.gdshaderinc"
