shader_type spatial;

uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_roughness : hint_roughness_gray, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_roughness : hint_roughness_gray, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_roughness : hint_roughness_gray, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float texture_scale = 0.012;
uniform vec3 haze_color : source_color = vec3(0.75, 0.86, 0.94);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.05;
uniform float haze_base_strength : hint_range(0.0, 1.0) = 0.17;
uniform float haze_base_height : hint_range(1.0, 100.0) = 36.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 triplanar_color(sampler2D tex, vec3 p, vec3 n) {
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 from_x = texture(tex, p.zy * texture_scale).rgb;
	vec3 from_y = texture(tex, p.xz * texture_scale).rgb;
	vec3 from_z = texture(tex, p.xy * texture_scale).rgb;
	return from_x * weights.x + from_y * weights.y + from_z * weights.z;
}

float triplanar_roughness(sampler2D tex, vec3 p, vec3 n) {
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	float from_x = texture(tex, p.zy * texture_scale).r;
	float from_y = texture(tex, p.xz * texture_scale).r;
	float from_z = texture(tex, p.xy * texture_scale).r;
	return from_x * weights.x + from_y * weights.y + from_z * weights.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float slope = 1.0 - abs(n.y);
	float soil_blend = smoothstep(0.12, 0.46, slope);
	float rock_blend = smoothstep(0.38, 0.78, slope);

	vec3 grass = triplanar_color(grass_albedo, world_position, n) * vec3(0.88, 0.92, 0.78);
	vec3 soil = triplanar_color(soil_albedo, world_position, n) * vec3(0.92, 0.88, 0.76);
	vec3 rock = triplanar_color(rock_albedo, world_position, n) * vec3(0.90, 0.88, 0.84);

	vec3 ground = mix(grass, soil, soil_blend);
	vec3 terrain_color = mix(ground, rock, rock_blend);
	// Haze is fixed by terrain height, so the mountain base blends into the horizon
	// without changing when the camera or player approaches.
	float base_haze = 1.0 - smoothstep(0.0, haze_base_height, max(world_position.y, 0.0));
	float haze = mix(haze_strength, haze_base_strength, base_haze);
	ALBEDO = mix(terrain_color, haze_color, haze);
	float rough_grass = triplanar_roughness(grass_roughness, world_position, n);
	float rough_soil = triplanar_roughness(soil_roughness, world_position, n);
	float rough_rock = triplanar_roughness(rock_roughness, world_position, n);
	ROUGHNESS = mix(mix(rough_grass, rough_soil, soil_blend), rough_rock, rock_blend);
	SPECULAR = 0.18;
}
