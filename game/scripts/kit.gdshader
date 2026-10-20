shader_type canvas_item;
// Draws FIFA 96 player sprites stored as palette indices (see build_godot_assets.py)
// and recolours the kit slots: 1 shirt, 2 shirt second colour, 3 shorts, 4 socks, 5 boots.

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform vec3 shirt = vec3(0.8, 0.1, 0.1);
uniform vec3 shirt2 = vec3(0.9, 0.8, 0.1);
uniform vec3 shorts = vec3(0.1, 0.1, 0.7);
uniform vec3 socks = vec3(0.8, 0.1, 0.1);
uniform vec3 boots = vec3(0.1, 0.1, 0.1);
uniform bool recolour = true;

void fragment() {
	int idx = int(round(texture(TEXTURE, UV).r * 255.0));
	if (idx == 255) {
		discard;
	}
	vec3 c = texelFetch(palette, ivec2(idx, 0), 0).rgb;
	vec4 meta = texelFetch(palette, ivec2(idx, 1), 0);
	int slot = int(round(meta.r * 255.0));
	if (recolour && slot > 0) {
		vec3 kit = slot == 1 ? shirt : slot == 2 ? shirt2 : slot == 3 ? shorts : slot == 4 ? socks : boots;
		float shade = pow(meta.g, 0.75);
		// keep some highlight on dark kits so folds stay readable
		c = kit * shade * 1.1 + vec3(0.12) * shade * shade;
	}
	COLOR = vec4(min(c, vec3(1.0)), 1.0) * COLOR.a;
}
