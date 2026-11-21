// Insula 1: varianta estompată a materialului insulei. Un obiect o primește doar cât timp acoperă pe Orion;
// `alfa` (pe instanță) scade și crește lin, fără puncte. Adâncimea se scrie, ca obiectul să nu se vadă prin el însuși.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_always;

#define ESTOMPAT
#include "res://insula1/shaders/insula_comun.gdshaderinc"
