shader_type canvas_item;
// Draws FIFA 96 player sprites stored as palette indices (see build_godot_assets.py)
// and recolours the kit slots: 1 shirt, 2 shirt second colour, 3 shorts, 4 socks, 5 boots,
// and, when set for the player, 6 skin and 7 hair.
// With own_art it draws our RGBA art instead (brand/sprites/line_actions), drawn in the OSCF
// kit, and recolours it by colour: white shirt and socks, blue shorts, green keeper shirt;
// and, when set for the player, its skin like slot 6.

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform vec3 shirt = vec3(0.8, 0.1, 0.1);
uniform vec3 shirt2 = vec3(0.9, 0.8, 0.1);
uniform vec3 shorts = vec3(0.1, 0.1, 0.7);
uniform vec3 socks = vec3(0.8, 0.1, 0.1);
uniform vec3 boots = vec3(0.1, 0.1, 0.1);
uniform bool recolour = true;
uniform vec3 skin = vec3(0.85, 0.66, 0.48);
uniform vec3 hair = vec3(0.2, 0.15, 0.1);
uniform bool has_skin = false;  // false: FIFA 96's own colours
uniform bool has_hair = false;
uniform bool own_art = false;
uniform bool white_is_kit = true;  // outfield art; the keeper's white is his gloves

vec3 hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

// Our own art: each kit colour of the OSCF kit, shaded by its value against `full`.
vec4 own_art_colour(vec4 t) {
	vec3 h = hsv(t.rgb);
	float hue = h.x * 360.0;
	vec3 kit = vec3(-1.0);
	float full = 1.0;
	if (white_is_kit && h.y < 0.2 && h.z > 0.6) {
		kit = shirt; full = 0.9;
	} else if (hue >= 195.0 && hue <= 255.0 && h.y > 0.45 && h.z > 0.25) {
		kit = shorts; full = 0.7;
	} else if (hue >= 80.0 && hue <= 170.0 && h.y > 0.3 && h.z > 0.2) {
		kit = shirt; full = 0.55;
	} else if ((hue < 10.0 || hue > 345.0) && h.y > 0.55 && h.z > 0.4) {
		kit = shirt2; full = 0.8;
	}
	if (kit.r < 0.0) {
		// skin, shaded around the art's own mid-tone (value 0.84). Its dark hair can't be told
		// from the skin's shadows by colour, so it stays as drawn.
		if (has_skin && hue >= 5.0 && hue <= 45.0 && h.y > 0.25) {
			return vec4(min(skin * (0.35 + 0.65 * h.z / 0.84), vec3(1.0)), t.a);
		}
		return t;
	}
	float shade = min(h.z / full, 1.2);
	return vec4(min(kit * shade + vec3(0.12) * shade * shade, vec3(1.0)), t.a);
}

void fragment() {
	if (own_art) {
		COLOR = own_art_colour(texture(TEXTURE, UV)) * vec4(1.0, 1.0, 1.0, COLOR.a);
	} else {
		int idx = int(round(texture(TEXTURE, UV).r * 255.0));
		if (idx == 255) {
			discard;
		}
		vec3 c = texelFetch(palette, ivec2(idx, 0), 0).rgb;
		vec4 meta = texelFetch(palette, ivec2(idx, 1), 0);
		int slot = int(round(meta.r * 255.0));
		if (slot == 6 || slot == 7) {
			// skin and hair: a photo gives the mid-tone, so centre the ramp on it
			if ((slot == 6 && has_skin) || (slot == 7 && has_hair)) {
				c = (slot == 6 ? skin : hair) * (0.35 + 1.3 * meta.g);
			}
		} else if (recolour && slot > 0) {
			vec3 kit = slot == 1 ? shirt : slot == 2 ? shirt2 : slot == 3 ? shorts : slot == 4 ? socks : boots;
			float shade = pow(meta.g, 0.75);
			// keep some highlight on dark kits so folds stay readable
			c = kit * shade * 1.1 + vec3(0.12) * shade * shade;
		}
		COLOR = vec4(min(c, vec3(1.0)), 1.0) * COLOR.a;
	}
}
