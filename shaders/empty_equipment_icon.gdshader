shader_type canvas_item;

void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    float brightness = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(vec3(brightness * 0.52), pixel.a * 0.38);
}
