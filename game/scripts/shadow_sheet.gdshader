shader_type spatial;
// The sheet over the grass in the 3D edition (Stadium.light_bodies): it multiplies what's under it
// by 1 where the light reaches and by 1 - strength in the bodies' shadows. The stadium is unshaded,
// so it takes no shadow of its own.
render_mode blend_mul, depth_draw_never, ambient_light_disabled, specular_disabled;

uniform float strength = 0.4;

void fragment() {
	ALBEDO = vec3(1.0);
}

void light() {
	DIFFUSE_LIGHT = vec3(1.0 - strength * (1.0 - ATTENUATION));
}
