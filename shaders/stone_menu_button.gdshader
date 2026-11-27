shader_type canvas_item;
render_mode unshaded;

uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform float pressed : hint_range(0.0, 1.0) = 0.0;
uniform float disabled : hint_range(0.0, 1.0) = 0.0;

uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform vec2 artwork_size = vec2(1.0);

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float luminance = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
	float metal = smoothstep(0.015, 0.15, art.r - art.b);
	float bevel = metal * smoothstep(0.15, 0.65, luminance);
	float pulse = 0.90 + 0.10 * sin(TIME * 3.1 + UV.x * 7.0);
	float light = highlight * pulse;
	vec3 gold = vec3(1.0, 0.68, 0.23);
	vec3 lit = art.rgb * (1.0 + light * 0.12);
	lit += gold * light * metal * (0.14 + bevel * 0.90);
	lit = mix(lit, vec3(luminance) * 0.66, disabled * 0.8);
	lit *= 1.0 - pressed * 0.14;
	float alpha = art.a * (1.0 - disabled * 0.30);
	if (burn > 0.0) {
		float noise = grain(floor(UV * artwork_size / 2.0));
		float edge = 0.12 + 0.76 * UV.y + 0.20 * (noise - 0.5);
		float remaining = smoothstep(-0.022, 0.022, edge - burn);
		float ember = (1.0 - smoothstep(0.0, 0.075, abs(edge - burn))) * remaining;
		lit = mix(lit, vec3(0.95, 0.38, 0.09), ember * 0.85);
		alpha *= remaining * (1.0 - step(1.0, burn));
	}
	COLOR = vec4(lit, alpha);
}
