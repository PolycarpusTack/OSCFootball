shader_type canvas_item;
// The referee's own art (assets/sprites/oscf_roles): drawn as is, except the card he holds up,
// keyed pure green (#00FF00) in the sheets, which becomes yellow or red (Match.book).

uniform vec3 card : source_color = vec3(1.0, 0.83, 0.0);

void fragment() {
	if (COLOR.g > 0.9 && COLOR.r < 0.2 && COLOR.b < 0.2) {  // COLOR: the texture, already modulated
		COLOR.rgb = card;
	}
}
