shader_type canvas_item;

// Art-free flowing-water animation for the walkable water tiles.
//
// The whole terrain layer (grass, paths, roofs, stone AND water) is drawn
// through this shader, but only blue water pixels are touched: a color key
// isolates them, everything else passes through untouched. A world-space
// varying drives the ripple so the flow is continuous across tile borders
// with no visible per-tile repetition. Sits BENEATH the Core Keeper
// reflection quad, which still draws on top unchanged.

// world_pos is the fragment position in the layer's local (world) space,
// so the animation reads as one continuous body of water across cells.
varying vec2 world_pos;

// Color key (normalized 0..1). Defaults tuned to the town tileset's water:
// blue-dominant pixels, land tiles never satisfy all four tests at once.
uniform float key_min_b : hint_range(0.0, 1.0) = 0.42;
uniform float key_b_over_r : hint_range(0.0, 1.0) = 0.14;
uniform float key_b_over_g : hint_range(0.0, 1.0) = 0.04;
uniform float key_max_r : hint_range(0.0, 1.0) = 0.55;

// Animation tuning.
uniform float flow_speed : hint_range(0.0, 4.0) = 0.6;
uniform float flow_strength : hint_range(0.0, 3.0) = 1.0;
// Lighter blue nudged onto the crests for a hint of foam/sparkle.
uniform vec3 crest_tint : source_color = vec3(0.49, 0.66, 0.82);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float r = base.r;
	float g = base.g;
	float b = base.b;
	// Is this a water pixel? Land tiles fail at least one of these.
	bool is_water =
		b > key_min_b &&
		b > r + key_b_over_r &&
		b > g + key_b_over_g &&
		r < key_max_r;
	if (!is_water) {
		COLOR = base;
	} else {
		// Two crossing low-frequency waves = a slow, non-repeating swell.
		float w = sin(world_pos.x * 0.09 + TIME * flow_speed) * 0.5
			+ sin(world_pos.y * 0.13 - TIME * flow_speed * 0.7) * 0.5;
		// A sharper scrolling band reads as a moving caustic highlight.
		float caustic = smoothstep(0.6, 1.0,
			sin(world_pos.y * 0.25 + world_pos.x * 0.12 + TIME * flow_speed * 1.3 + w));
		vec3 rgb = base.rgb + w * flow_strength * 0.06 + caustic * flow_strength * 0.12;
		// Tint the brightest crests very slightly toward foam blue.
		rgb = mix(rgb, crest_tint, caustic * flow_strength * 0.10);
		COLOR = vec4(clamp(rgb, 0.0, 1.0), base.a);
	}
}
