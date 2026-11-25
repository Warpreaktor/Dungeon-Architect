shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.34, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 pixel = COLOR;
	vec2 center = vec2(0.5 + 0.018 * sin(TIME * 1.7), 0.54);
	float distance_to_light = length((UV - center) * vec2(1.0, 1.05));
	float glow = 1.0 - smoothstep(0.06, 0.69, distance_to_light);
	float flicker = 0.91 + 0.055 * sin(TIME * 2.1) + 0.035 * sin(TIME * 4.3);
	float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	float detail_mask = smoothstep(0.015, 0.18, luminance);
	vec3 illumination = glow_color.rgb * intensity * glow * flicker * detail_mask;
	COLOR = vec4(pixel.rgb + (vec3(1.0) - pixel.rgb) * illumination, pixel.a);
}
