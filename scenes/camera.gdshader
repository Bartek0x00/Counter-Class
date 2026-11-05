shader_type spatial;

uniform sampler2D cam_y: filter_linear, repeat_disable;
uniform sampler2D cam_cbcr: filter_linear, repeat_disable;

void fragment() {
	float y = texture(cam_y, UV).r;
	vec2 cbcr = texture(cam_cbcr, UV).rg;
	
	float cb = cbcr.r - 0.5;
	float cr = cbcr.g - 0.5;
	
	vec3 rgb;
	
	rgb.r = y + 1.402 * cr;
	rgb.g = y - 0.344136 * cb - 0.714136 * cr;
	rgb.b = y + 1.772 * cb;
	
	ALBEDO = clamp(rgb, 0.0, 1.0);
	ALPHA = 1.0;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
