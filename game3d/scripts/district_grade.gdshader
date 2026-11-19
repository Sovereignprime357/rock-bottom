shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// Encoded numeric Canvas RGB. No source_color conversion in this opaque SDR pass.
uniform vec3 multiply_rgb = vec3(1.0);
uniform float multiply_alpha = 0.0;
uniform vec3 overlay_rgb = vec3(0.5);
uniform float overlay_alpha = 0.0;
uniform vec2 world_feedback_offset_px = vec2(0.0);

void fragment() {
	vec2 world_uv = SCREEN_UV;
	if (world_feedback_offset_px != vec2(0.0)) {
		world_uv = clamp(SCREEN_UV-world_feedback_offset_px*SCREEN_PIXEL_SIZE,0.5*SCREEN_PIXEL_SIZE,vec2(1.0)-0.5*SCREEN_PIXEL_SIZE);
	}
	vec4 screen = textureLod(screen_texture, world_uv, 0.0);
	vec3 q = (1.0-multiply_alpha)*screen.rgb + multiply_alpha*screen.rgb*multiply_rgb;
	vec3 dark = 2.0*q*overlay_rgb;
	vec3 light = 1.0-2.0*(1.0-q)*(1.0-overlay_rgb);
	vec3 overlay = mix(dark,light,step(vec3(0.5),q));
	COLOR = vec4((1.0-overlay_alpha)*q+overlay_alpha*overlay,screen.a);
}
