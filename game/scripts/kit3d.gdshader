shader_type spatial;
// One kit slot of the 3D footballer (Puppet): a plain colour, or the shirt in stripes of two
// across the body, as the sprites have them (tools/blender/footballer.py, STRIPE).

uniform vec3 colour : source_color = vec3(1.0);
uniform vec3 colour2 : source_color = vec3(1.0);
uniform float stripe = 0.0;  // metres from one stripe to the next across the part; 0: plain

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec3 c = colour;
	if (stripe > 0.0 && fract(local.x / stripe) > 0.5) {
		c = colour2;
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
