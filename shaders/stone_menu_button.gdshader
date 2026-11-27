shader_type canvas_item;
render_mode unshaded;

uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform float pressed : hint_range(0.0, 1.0) = 0.0;
uniform float disabled : hint_range(0.0, 1.0) = 0.0;

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
	COLOR = vec4(lit, art.a * (1.0 - disabled * 0.30));
}
