shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

// ═══════════════════════════════════════════════════════════════════════════
// Shader de Água Semi-Realista para Lago
// Ondas suaves, transparência com profundidade, reflexo Fresnel, espuma na borda.
// ═══════════════════════════════════════════════════════════════════════════

uniform vec4 cor_rasa : source_color = vec4(0.15, 0.45, 0.35, 0.7);
uniform vec4 cor_funda : source_color = vec4(0.04, 0.12, 0.18, 0.92);
uniform float profundidade_max : hint_range(0.5, 10.0) = 3.5;
uniform float velocidade_onda : hint_range(0.01, 2.0) = 0.35;
uniform float amplitude_onda : hint_range(0.0, 0.5) = 0.08;
uniform float frequencia_onda : hint_range(0.5, 8.0) = 2.5;
uniform float fresnel_potencia : hint_range(0.5, 8.0) = 3.5;
uniform float brilho_especular : hint_range(0.0, 2.0) = 0.85;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.08;
uniform float intensidade_normal : hint_range(0.0, 2.0) = 0.6;
uniform vec4 cor_espuma : source_color = vec4(0.85, 0.92, 0.95, 0.6);
uniform float largura_espuma : hint_range(0.0, 2.0) = 0.45;

// Ruído de onda procedural simples (sem texturas externas)
float onda_ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float ondas(vec2 uv, float tempo) {
	float w = 0.0;
	// Camada 1: ondas grandes e lentas
	w += sin(uv.x * frequencia_onda + tempo * velocidade_onda * 1.2) * 0.4;
	w += sin(uv.y * frequencia_onda * 0.8 - tempo * velocidade_onda * 0.9) * 0.3;
	// Camada 2: ondulação cruzada
	w += sin((uv.x + uv.y) * frequencia_onda * 1.5 + tempo * velocidade_onda * 1.6) * 0.18;
	// Camada 3: ruído de detalhe
	w += (onda_ruido(uv * 3.0 + vec2(tempo * 0.2, tempo * 0.15)) - 0.5) * 0.25;
	w += (onda_ruido(uv * 5.5 - vec2(tempo * 0.12, tempo * 0.18)) - 0.5) * 0.12;
	return w * amplitude_onda;
}

void vertex() {
	float t = TIME;
	vec2 mundo_uv = VERTEX.xz * 0.08;
	VERTEX.y += ondas(mundo_uv, t);
}

void fragment() {
	float t = TIME;
	vec2 mundo_uv = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz * 0.08 + UV * 4.0;

	// Normal das ondas via diferenças finitas
	float eps = 0.08;
	float h0 = ondas(mundo_uv, t);
	float hx = ondas(mundo_uv + vec2(eps, 0.0), t);
	float hz = ondas(mundo_uv + vec2(0.0, eps), t);
	vec3 normal_onda = normalize(vec3(h0 - hx, eps * (1.0 / intensidade_normal), h0 - hz));
	NORMAL = mix(NORMAL, normal_onda, intensidade_normal);

	// Fresnel: mais reflexivo em ângulos rasos
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_potencia);

	// Profundidade via depth buffer
	float profundidade = 0.0;
	float espuma_fator = 0.0;
	{
		float depth_tex = texture(DEPTH_TEXTURE, SCREEN_UV).r;
		// Reconstruir posição do fundo
		vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
		world_pos.xyz /= world_pos.w;
		profundidade = clamp((VERTEX.z - world_pos.z) / profundidade_max, 0.0, 1.0);
		// Espuma na borda (onde a água é rasa)
		espuma_fator = 1.0 - smoothstep(0.0, largura_espuma / profundidade_max, (VERTEX.z - world_pos.z));
		espuma_fator *= cor_espuma.a;
	}

	// Cor baseada na profundidade
	vec3 cor_agua = mix(cor_rasa.rgb, cor_funda.rgb, profundidade);

	// Adicionar reflexo do céu
	vec3 cor_ceu = vec3(0.55, 0.72, 0.88);
	cor_agua = mix(cor_agua, cor_ceu, fresnel * 0.45);

	// Espuma branca na borda
	cor_agua = mix(cor_agua, cor_espuma.rgb, espuma_fator * 0.5);

	ALBEDO = cor_agua;
	ALPHA = mix(cor_rasa.a, cor_funda.a, profundidade);
	ALPHA = mix(ALPHA, 1.0, fresnel * 0.3);
	METALLIC = 0.15;
	ROUGHNESS = rugosidade;
	SPECULAR = brilho_especular;
}
