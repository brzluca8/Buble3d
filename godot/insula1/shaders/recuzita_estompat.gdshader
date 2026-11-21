// Insula 1 (v4): varianta estompată a recuzitei: un copac o primește doar cât timp acoperă pe Orion;
// `alfa` (pe instanță) scade și crește lin, fără puncte.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_always;

#define ESTOMPAT
#include "res://insula1/shaders/recuzita_comun.gdshaderinc"
