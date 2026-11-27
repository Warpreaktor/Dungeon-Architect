shader_type canvas_item;

uniform vec4 inner_color : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.64, 0.18, 1.0);
uniform vec4 outer_color : source_color = vec4(0.82, 0.16, 0.04, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float sway : hint_range(0.0, 1.0) = 0.22;
uniform float detail : hint_range(1.0, 12.0) = 6.0;
uniform float speed : hint_range(0.2, 4.0) = 1.2;
uniform float phase = 0.0;
uniform float flame_height : hint_range(0.4, 1.2) = 0.95;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed + phase;
	float y = 1.0 - uv.y;
	float taper = mix(0.46, 0.08, pow(y, 0.85));
	float lateral = fbm(vec2(uv.x * detail + 0.3, y * 2.4 - t * 1.1));
	float lateral_fine = fbm(vec2(uv.x * (detail * 1.8), y * 4.5 - t * 1.9));
	float offset = (lateral - 0.5) * sway + (lateral_fine - 0.5) * sway * 0.4;
	float center_dist = abs((uv.x + offset) - 0.5);
	float body = 1.0 - smoothstep(taper, taper + 0.06, center_dist);
	float top_cut = 1.0 - smoothstep(flame_height - 0.12, flame_height + 0.06, y + (lateral_fine - 0.5) * 0.15);
	float base = smoothstep(0.0, 0.08, y);
	float tongue = smoothstep(0.18, 0.95, fbm(vec2(uv.x * 8.5 - 1.3, y * 5.0 - t * 2.5)) + (1.0 - y) * 0.75);
	float mask = clamp(body * top_cut * base * tongue, 0.0, 1.0);
	float glow = clamp((1.0 - center_dist / max(taper, 0.001)) * (1.0 - y * 0.78), 0.0, 1.0);
	vec4 color = mix(outer_color, mid_color, smoothstep(0.06, 0.6, glow));
	color = mix(color, inner_color, smoothstep(0.38, 0.92, glow) * smoothstep(0.0, 0.55, y));
	float alpha = mask * intensity;
	COLOR = vec4(color.rgb * (0.72 + glow * 0.45) * intensity, alpha);
}
