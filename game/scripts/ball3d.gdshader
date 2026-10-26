shader_type spatial;
// The 3D edition's ball (Ball.make_puppet): white with twelve black patches, at the corners of
// an icosahedron, as the classic ball's pentagons are.

varying vec3 local;

void vertex() {
	local = normalize(VERTEX);
}

void fragment() {
	const float P = 1.618034;
	vec3 corners[6] = vec3[](vec3(0.0, 1.0, P), vec3(0.0, 1.0, -P), vec3(1.0, P, 0.0),
		vec3(1.0, -P, 0.0), vec3(P, 0.0, 1.0), vec3(-P, 0.0, 1.0));
	float near = 0.0;
	for (int i = 0; i < 6; i++) {
		near = max(near, abs(dot(local, normalize(corners[i]))));  // each corner and its opposite
	}
	ALBEDO = near > 0.93 ? vec3(0.05) : vec3(0.95);
	ROUGHNESS = 0.5;
}
