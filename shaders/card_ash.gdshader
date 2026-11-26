shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float burn = 0.0;
uniform vec2 card_origin;
uniform vec2 card_x;
uniform vec2 card_y;
uniform vec2 card_size = vec2(1.0);
varying vec2 group_position;

void vertex() {
	group_position = VERTEX;
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 uv = (vec2(dot(card_x, group_position), dot(card_y, group_position)) + card_origin) / card_size;
	float noise = grain(floor(uv * card_size / 2.0));
	float edge = 0.12 + 0.76 * clamp(uv.y, 0.0, 1.0) + 0.20 * (noise - 0.5);
	float remaining = smoothstep(-0.022, 0.022, edge - burn);
	float ember = (1.0 - smoothstep(0.0, 0.075, abs(edge - burn))) * remaining;
	if (burn > 0.0) {
		c.rgb = mix(c.rgb, vec3(0.95, 0.38, 0.09), ember * 0.85);
		c.a *= remaining * (1.0 - step(1.0, burn));
	}
	COLOR *= c;
}
