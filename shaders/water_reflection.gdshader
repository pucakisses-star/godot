shader_type canvas_item;

// Core Keeper-style shoreline reflections: every water pixel re-samples
// the already-drawn screen a mirrored distance above itself (across the
// top of its water column), so whoever stands on the shore - player,
// NPCs, buildings, trees - appears flipped in the water, shimmering.
//
// The quad spans a rectangle of map cells; reflection_mask marks which
// of those cells are water (R) and how many water rows sit directly
// above each one (G * 16), which locates the shoreline for the mirror.

uniform sampler2D reflection_mask: filter_nearest;
uniform vec2 mask_cells = vec2(1.0, 1.0);
uniform float tile_px = 32.0;
uniform float view_zoom = 1.0;
uniform vec4 water_tint: source_color = vec4(0.2, 0.38, 0.6, 1.0);
uniform float reflection_alpha: hint_range(0.0, 1.0) = 0.34;
uniform float fade_cells = 3.2;
// Rain agitation (0 = calm): faster, wider sway and a duller mirror.
uniform float rain_ripple: hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture: hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
	vec2 cellf = UV * mask_cells;
	vec4 mask = texture(reflection_mask, UV);
	if (mask.r < 0.5) {
		discard;
	}
	// Distance below the shoreline (top edge of this water column), in cells.
	float below = mask.g * 16.0 + fract(cellf.y);
	float fade = clamp(1.0 - below / fade_cells, 0.0, 1.0);
	if (fade <= 0.001) {
		discard;
	}
	// Ripple: whole-pixel horizontal sway, rolling slowly down the water.
	float band = floor(cellf.y * tile_px * 0.5);
	float sway_speed = 1.7 + rain_ripple * 2.6;
	float sway_amp = 1.5 + rain_ripple * 1.8;
	float sway = floor(sin(TIME * sway_speed + band * 0.7 + cellf.x * 2.1) * sway_amp) * 2.0;
	vec2 offset = vec2(sway, -2.0 * below * tile_px) * view_zoom * SCREEN_PIXEL_SIZE;
	vec2 sample_uv = SCREEN_UV + offset;
	if (sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		discard;
	}
	vec3 reflected = texture(screen_texture, sample_uv).rgb;
	COLOR = vec4(mix(reflected, water_tint.rgb, 0.32), reflection_alpha * (1.0 - 0.3 * rain_ripple) * fade);
}
