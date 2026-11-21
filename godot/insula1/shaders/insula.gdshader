// Insula 1: materialul opac al insulei (stânci, iarbă, frunziș, flori, pânze, cristale, felinare, portal, barca,
// palele morii, restul). Codul e în insula_comun.gdshaderinc; clasa vine din uniformele pe instanță.
// Fără cull: modelul din Tripo are și fețe subțiri, văzute din ambele părți.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://insula1/shaders/insula_comun.gdshaderinc"
