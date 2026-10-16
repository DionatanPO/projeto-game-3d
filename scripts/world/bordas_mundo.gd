@tool
extends Node3D
## BordasMundo: 3 camadas em 1 node.
## 1) Paredes invisiveis em +-LIMITE (prende jogador/trator/drone baixo).
## 2) Cinturao verde: anel denso de Tree_1/Pine_1 (MultiMesh, 2 draws).
## 3) Anel de montanhas PBR ao horizonte + chao distante.
## Segue o relevo do Terreno via altura().

const LIMITE := 206.0
const SEED := 9917
const ANEL_MONTANHAS_SHADER := "res://shaders/anel_montanhas.gdshader"
const ANEL_NOVO := "res://assets/models/anel_montanhas_novo.glb"


func _ready() -> void:
	_limpar()
	_ajustar_nevoa()
	_paredes()
	_anel_novo()
	_chao_distante()


func _limpar() -> void:
	for f in get_children():
		remove_child(f)
		f.queue_free()


func _ajustar_nevoa() -> void:
	var ceu := get_parent().get_node_or_null("MundoCeu") as WorldEnvironment
	if ceu == null or ceu.environment == null:
		return
	var env := ceu.environment
	env.fog_enabled = true
	env.fog_depth_begin = 0.0
	env.fog_depth_end = 400.0
	env.fog_density = 0.5


func _paredes() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ParedesMundo"
	add_child(corpo)
	var defs := [
		[Vector3(0, 12, LIMITE), Vector3(480, 30, 4)],
		[Vector3(0, 12, -LIMITE), Vector3(480, 30, 4)],
		[Vector3(LIMITE, 12, 0), Vector3(4, 30, 480)],
		[Vector3(-LIMITE, 12, 0), Vector3(4, 30, 480)],
	]
	for d in defs:
		var col := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = d[1]
		col.shape = caixa
		col.position = d[0]
		corpo.add_child(col)


func _anel_novo() -> void:
	## Anel modelado no Blender: fino (205-300m), ondulacao de montanha
	## por dentro sob o anel das arvores e plano por fora. Mesma textura
	## do chao do mapa + nevoa da cena (material padrao recebe fog).
	var pacote := load(ANEL_NOVO) as PackedScene
	if pacote == null:
		push_error("BordasMundo: nao foi possivel carregar " + ANEL_NOVO)
		return
	var no := pacote.instantiate() as Node3D
	no.name = "AnelMontanhasNovo"
	var mat := ShaderMaterial.new()
	var shader_nevoa := Shader.new()
	shader_nevoa.code = """
shader_type spatial;
uniform sampler2D chao_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 cor_nevoa : source_color = vec3(0.75, 0.86, 0.94);
varying vec3 pos_mundo;
void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 base = texture(chao_albedo, UV * 40.0).rgb;
	ROUGHNESS = 0.95;
	float dist_cam = length(pos_mundo - CAMERA_POSITION_WORLD);
	float nevoa = 0.30 + smoothstep(180.0, 520.0, dist_cam) * 0.55;
	ALBEDO = mix(base, cor_nevoa, clamp(nevoa, 0.0, 0.9));
}
"""
	mat.shader = shader_nevoa
	mat.set_shader_parameter("chao_albedo", load("res://assets/textures/grass_ground_diff_1k.jpg"))
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(no)


func _anel_montanhas() -> void:
	var pontos: Array = []
	var ruido := FastNoiseLite.new()
	ruido.seed = SEED + 300
	ruido.frequency = 1.0
	ruido.fractal_octaves = 1

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 301
	var picos_angulos := PackedFloat32Array()
	var picos_alturas := PackedFloat32Array()
	var picos_larguras := PackedFloat32Array()
	var qtd_picos := 16
	for p in qtd_picos:
		picos_angulos.append(TAU * (float(p) + 0.5) / float(qtd_picos) + rng.randf_range(-0.10, 0.10))
		picos_alturas.append(rng.randf_range(45.0, 95.0))
		picos_larguras.append(rng.randf_range(0.17, 0.28))

	var frac_raio := [0.0, 0.10, 0.22, 0.36, 0.50, 0.62, 0.74, 0.84, 0.93, 1.0]
	var perfil_altura := [0.0, 0.06, 0.20, 0.42, 0.72, 1.0, 0.90, 0.66, 0.30, 0.0]
	var passos_angulo := 512
	for i in passos_angulo:
		var angulo := TAU * float(i) / float(passos_angulo)
		var c := cos(angulo)
		var s := sin(angulo)
		var ruido_amplo := ruido.get_noise_2d(c * 1.05, s * 1.05)
		var ruido_medio := ruido.get_noise_2d(c * 4.2 + 17.0, s * 4.2 - 9.0)
		var ruido_fino := ruido.get_noise_2d(c * 12.0 - 31.0, s * 12.0 + 23.0)
		var volume_pico := 0.0
		for p in qtd_picos:
			var diferenca := absf(wrapf(angulo - picos_angulos[p], -PI, PI))
			var influencia := exp(-0.5 * pow(diferenca / picos_larguras[p], 2.0))
			volume_pico = maxf(volume_pico, picos_alturas[p] * influencia)

		var altura_crista := clampf(85.0 + ruido_amplo * 26.0 + ruido_medio * 8.0 + ruido_fino * 2.0 + volume_pico, 50.0, 190.0)
		var linha_raio := 260.0 + ruido_amplo * 12.0 + ruido_medio * 6.0
		var anel: PackedVector3Array = []
		for row in frac_raio.size():
			var fracao: float = frac_raio[row]
			var raio_base := lerpf(210.0, 600.0, fracao)
			var variacao_raio := ruido_amplo * 19.0 + ruido_medio * 8.0
			var raio := lerpf(raio_base, linha_raio, 0.20) + variacao_raio
			# Os ombros abrem para fora da crista e descem gradualmente, sem formar uma muralha.
			if row < 3:
				raio = lerpf(raio_base, linha_raio, 0.12)
			elif row > 3:
				raio = lerpf(linha_raio, raio_base, 0.22)
			var ruido_cruzado := ruido.get_noise_2d(c * (2.0 + float(row) * 0.7) + float(row) * 2.1, s * (2.0 + float(row) * 0.7) - float(row) * 1.7)
			var altura := maxf(0.0, altura_crista * float(perfil_altura[row]) + ruido_cruzado * 10.0 * float(perfil_altura[row])) * 0.55
			anel.append(Vector3(c * raio, altura, s * raio))
		pontos.append(anel)

	var borda_montanhas := PackedVector3Array()
	for anel in pontos:
		var anel_atual: PackedVector3Array = anel
		borda_montanhas.append(anel_atual[0])
	_transicao_mapa_montanhas(borda_montanhas)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in passos_angulo:
		var prox := (i + 1) % passos_angulo
		var atual: PackedVector3Array = pontos[i]
		var seguinte: PackedVector3Array = pontos[prox]
		for row in frac_raio.size() - 1:
			var p00: Vector3 = atual[row]
			var p01: Vector3 = seguinte[row]
			var p11: Vector3 = seguinte[row + 1]
			var p10: Vector3 = atual[row + 1]
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p10)
	st.index()
	st.generate_normals()
	var malha := st.commit()

	var shader := load(ANEL_MONTANHAS_SHADER) as Shader
	if shader == null:
		push_error("BordasMundo: nao foi possivel carregar o shader do anel.")
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_albedo", load("res://assets/textures/polyhaven/sparse_grass/basecolor_1k.jpg"))
	material.set_shader_parameter("soil_albedo", load("res://assets/textures/polyhaven/rocky_terrain_02/basecolor_1k.jpg"))
	material.set_shader_parameter("rock_albedo", load("res://assets/textures/polyhaven/rock_face/basecolor_1k.jpg"))
	material.set_shader_parameter("grass_roughness", load("res://assets/textures/polyhaven/sparse_grass/roughness_1k.png"))
	material.set_shader_parameter("soil_roughness", load("res://assets/textures/polyhaven/rocky_terrain_02/roughness_1k.png"))
	material.set_shader_parameter("rock_roughness", load("res://assets/textures/polyhaven/rock_face/roughness_1k.png"))

	var montanhas := MeshInstance3D.new()
	montanhas.name = "AnelMontanhasProcedural"
	montanhas.mesh = malha
	montanhas.material_override = material
	montanhas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(montanhas)


func _transicao_mapa_montanhas(borda_externa: PackedVector3Array) -> void:
	if borda_externa.size() < 3:
		return

	var no_terreno := get_parent().get_node_or_null("Terreno")
	var material_mapa: Material
	if no_terreno != null:
		material_mapa = no_terreno.get("material") as Material
	if material_mapa == null:
		push_error("BordasMundo: nao foi encontrado o material do terreno para a faixa de transicao.")
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisoes_radiais := 24
	var total := borda_externa.size()
	for i in total:
		var seguinte := (i + 1) % total
		var angulo := TAU * float(i) / float(total)
		var angulo_seguinte := TAU * float(seguinte) / float(total)
		var direcao := Vector2(cos(angulo), sin(angulo))
		var direcao_seguinte := Vector2(cos(angulo_seguinte), sin(angulo_seguinte))
		var raio_quadrado := 210.0 / maxf(absf(direcao.x), absf(direcao.y))
		var raio_quadrado_seguinte := 210.0 / maxf(absf(direcao_seguinte.x), absf(direcao_seguinte.y))
		var interior := Vector3(direcao.x * raio_quadrado, 0.0, direcao.y * raio_quadrado)
		var interior_seguinte := Vector3(direcao_seguinte.x * raio_quadrado_seguinte, 0.0, direcao_seguinte.y * raio_quadrado_seguinte)
		var exterior := borda_externa[i]
		var exterior_seguinte := borda_externa[seguinte]

		for faixa in divisoes_radiais:
			var t0 := float(faixa) / float(divisoes_radiais)
			var t1 := float(faixa + 1) / float(divisoes_radiais)
			var p00 := interior.lerp(exterior, t0)
			var p01 := interior_seguinte.lerp(exterior_seguinte, t0)
			var p11 := interior_seguinte.lerp(exterior_seguinte, t1)
			var p10 := interior.lerp(exterior, t1)
			_adicionar_vertice_transicao(st, p00, t0)
			_adicionar_vertice_transicao(st, p01, t0)
			_adicionar_vertice_transicao(st, p11, t1)
			_adicionar_vertice_transicao(st, p00, t0)
			_adicionar_vertice_transicao(st, p11, t1)
			_adicionar_vertice_transicao(st, p10, t1)

	st.index()
	var malha := st.commit()
	var dados_material := material_mapa as StandardMaterial3D
	if dados_material == null or dados_material.albedo_texture == null:
		push_error("BordasMundo: o material do terreno nao possui textura albedo.")
		return
	var shader_transicao := Shader.new()
	shader_transicao.code = """
shader_type spatial;
uniform sampler2D mapa_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grama_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 cor_nevoa : source_color = vec3(0.75, 0.86, 0.94);
varying vec3 posicao_mundo;
void vertex() {
	posicao_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float peso = smoothstep(0.0, 1.0, COLOR.r);
	vec3 mapa = texture(mapa_albedo, UV * 40.0).rgb;
	vec3 grama = texture(grama_albedo, posicao_mundo.xz * 0.012).rgb * vec3(0.88, 0.92, 0.78);
	grama = mix(grama, cor_nevoa, 0.17);
	ALBEDO = mix(mapa, grama, peso);
	ROUGHNESS = 0.95;
}
"""
	var material_transicao := ShaderMaterial.new()
	material_transicao.shader = shader_transicao
	material_transicao.set_shader_parameter("mapa_albedo", dados_material.albedo_texture)
	material_transicao.set_shader_parameter("grama_albedo", load("res://assets/textures/polyhaven/sparse_grass/basecolor_1k.jpg"))

	var transicao := MeshInstance3D.new()
	transicao.name = "TransicaoTerrenoMontanhas"
	transicao.mesh = malha
	transicao.material_override = material_transicao
	transicao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(transicao)


func _adicionar_vertice_transicao(st: SurfaceTool, ponto: Vector3, mistura: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(ponto.x / 420.0 + 0.5, ponto.z / 420.0 + 0.5))
	st.set_color(Color(mistura, 0.0, 0.0, 1.0))
	st.add_vertex(ponto)

func _chao_distante() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(1800, 1800)
	var mi := MeshInstance3D.new()
	mi.name = "ChaoDistante"
	mi.mesh = plano
	mi.position = Vector3(0, -1.2, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/grass_ground_diff_1k.jpg")
	mat.roughness = 0.95
	mat.uv1_scale = Vector3(240, 1, 240)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = mat
	add_child(mi)
