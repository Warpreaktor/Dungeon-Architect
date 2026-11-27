shader_type canvas_item;
render_mode unshaded;

uniform sampler2D noise_map : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.63, 0.72, 0.81, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.58;
uniform float drift_speed : hint_range(0.0, 0.2) = 0.035;
uniform vec2 path_centers = vec2(0.78, 0.31);
uniform vec2 path_half_widths = vec2(0.06, 0.43);

void fragment() {
	vec2 uv = UV;
	float depth = smoothstep(0.08, 0.92, uv.y);
	float center = mix(path_centers.x, path_centers.y, depth);
	float width = mix(path_half_widths.x, path_half_widths.y, depth);
	float sides = 1.0 - smoothstep(width * 0.22, width, abs(uv.x - center));
	float ends = smoothstep(0.04, 0.22, uv.y) * (1.0 - smoothstep(0.65, 0.98, uv.y));
	float edges = smoothstep(0.0, 0.08, uv.x) * (1.0 - smoothstep(0.92, 1.0, uv.x));
	vec2 flow = vec2(-0.78, 0.62) * TIME * drift_speed;
	vec2 p = (uv - flow) * vec2(1.8, 2.5);
	float curl = texture(noise_map, p * 0.53 + vec2(0.23, 0.71)).r;
	float body = texture(noise_map, p + vec2(curl * 0.28, 0.0)).r;
	float wisps = texture(noise_map, p * vec2(1.4, 2.1) + flow * 0.45 + vec2(0.41, 0.18)).r;
	float clouds = smoothstep(0.28, 0.78, body * 0.72 + wisps * 0.28);
	float opacity = density * sides * ends * edges * mix(0.25, 1.0, clouds);
	vec3 color = fog_color.rgb * mix(0.76, 1.0, clouds);
	COLOR = vec4(color, opacity * fog_color.a * COLOR.a);
}
