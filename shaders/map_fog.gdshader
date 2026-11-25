shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fog_mask : filter_nearest, repeat_disable;
uniform vec2 mask_size = vec2(3.0);
uniform vec4 fog_color : source_color;
uniform float feather : hint_range(0.05, 0.49) = 0.38;
uniform float memory_opacity : hint_range(0.0, 1.0) = 0.55;

vec2 cell_state(vec2 cell) {
	return texture(fog_mask, (cell + vec2(0.5)) / mask_size).rg;
}

void fragment() {
	vec2 grid = UV * (mask_size - vec2(2.0));
	vec2 cell = floor(grid) + vec2(1.0);
	vec2 offset = fract(grid) - vec2(0.5);
	vec2 direction = step(vec2(0.0), offset) * 2.0 - vec2(1.0);
	vec2 distance_to_edge = vec2(0.5) - abs(offset);
	vec2 center = cell_state(cell);
	vec2 horizontal = cell_state(cell + vec2(direction.x, 0.0));
	vec2 vertical = cell_state(cell + vec2(0.0, direction.y));
	vec2 diagonal = cell_state(cell + direction);
	vec2 edge = smoothstep(vec2(0.0), vec2(feather), distance_to_edge);
	float corner = smoothstep(0.0, feather, length(distance_to_edge));
	// Затухание внутрь открытых клеток не раскрывает неизвестную область.
	vec2 coverage = center * mix(vec2(edge.x), vec2(1.0), horizontal)
		* mix(vec2(edge.y), vec2(1.0), vertical)
		* mix(vec2(corner), vec2(1.0), diagonal);
	float opacity = 1.0 - coverage.r * (1.0 - memory_opacity * (1.0 - coverage.g));
	COLOR = vec4(fog_color.rgb, opacity * COLOR.a);
}
