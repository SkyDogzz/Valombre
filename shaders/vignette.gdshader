shader_type canvas_item;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float edge_distance = length(centered);
	float edge_shadow = smoothstep(0.72, 1.15, edge_distance) * 0.72;
	float lower_shadow = smoothstep(0.58, 1.0, UV.y) * 0.16;
	float alpha = clamp(edge_shadow + lower_shadow, 0.0, 0.84);
	COLOR = vec4(0.025, 0.03, 0.025, alpha);
}
