extends Node3D
## Fazenda: terreno procedural + fileiras geradas por codigo.
## PlaneMesh 96x96 deslocado por ruido suave, cor por vertice e normais
## analiticas; colisao trimesh identica ao visual. Semente fixa = layout
## deterministico (missoes/placas).

const TAMANHO := 60.0
const CELULAS := 96
const SEED := 12345
const ALTURA_BASE := 0.8
const ALTURA_BORDA := 3.5
const ELEVACAO_BORDA := 6.0
const RAIO_BORDA := 20.0
const PONTO_SPAWN := Vector2(0.0, 14.0)

const FILEIRAS: Array = [
	{"x": -12.0, "cultura": "soja", "cor": Color(0.30, 0.62, 0.28)},
	{"x": 0.0, "cultura": "milho", "cor": Color(0.45, 0.66, 0.25)},
	{"x": 12.0, "cultura": "pousio", "cor": Color(0.42, 0.30, 0.18)},
]

const PLANTAS_POR_FILEIRA := 8
const ESPACAMENTO := 2.2
const Z_INICIAL := -7.7

const COR_BAIXA := Color(0.88, 0.82, 0.68)
const COR_ALTA := Color(0.78, 0.90, 0.68)
const SOLO_ALBEDO := "res://assets/textures/grass_ground_diff_1k.jpg"

var _ruido := FastNoiseLite.new()


func _ready() -> void:
	_ruido.seed = SEED
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 0.035
	_criar_ceu()
	var sol := get_node_or_null("Sol") as DirectionalLight3D
	if sol != null:
		sol.light_energy = 1.2
		sol.shadow_blur = 1.2
	_criar_terreno()
	_assentar_estruturas()
	_vestir_arvores_especiais()
	_criar_fileiras()


func altura(x: float, z: float) -> float:
	var base := _ruido.get_noise_2d(x, z)
	var d := Vector2(x, z).length()
	var borda := smoothstep(RAIO_BORDA, TAMANHO * 0.5, d)
	var h := base * lerpf(ALTURA_BASE, ALTURA_BORDA, borda) + borda * borda * ELEVACAO_BORDA
	var dp := Vector2(x, z).distance_to(PONTO_SPAWN)
	h *= smoothstep(1.5, 5.0, dp)
	return h


func _normal(x: float, z: float) -> Vector3:
	var e := 0.3
	var n := Vector3(altura(x - e, z) - altura(x + e, z), 2.0 * e, altura(x, z - e) - altura(x, z + e))
	if n.length() < 0.0001:
		return Vector3.UP
	return n.normalized()


func _criar_ceu() -> void:
	var ambiente := WorldEnvironment.new()
	ambiente.name = "Ceu"
	var env := Environment.new()
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color(0.20, 0.45, 0.80)
	mat_ceu.sky_horizon_color = Color(0.55, 0.72, 0.88)
	mat_ceu.ground_bottom_color = Color(0.20, 0.28, 0.20)
	mat_ceu.ground_horizon_color = Color(0.65, 0.75, 0.80)
	ceu.sky_material = mat_ceu
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.75, 0.86, 0.94)
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 160.0
	env.fog_sky_affect = 0.0
	ambiente.environment = env
	add_child(ambiente)


func _criar_terreno() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(TAMANHO, TAMANHO)
	plano.subdivide_width = CELULAS
	plano.subdivide_depth = CELULAS
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plano.get_mesh_arrays())
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(malha, 0)
	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		var h := altura(v.x, v.z)
		mdt.set_vertex(i, Vector3(v.x, h, v.z))
		var t := clampf((h + 1.0) * 0.5, 0.0, 1.0)
		mdt.set_vertex_color(i, COR_BAIXA.lerp(COR_ALTA, t))
		mdt.set_vertex_normal(i, _normal(v.x, v.z))
	malha.clear_surfaces()
	mdt.commit_to_surface(malha)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load(SOLO_ALBEDO) as Texture2D
	mat.uv1_scale = Vector3(16.0, 16.0, 16.0)
	mat.roughness = 0.95
	malha.surface_set_material(0, mat)
	var corpo := StaticBody3D.new()
	corpo.name = "Terreno"
	add_child(corpo)
	var malhaholder := MeshInstance3D.new()
	malhaholder.name = "Malha"
	malhaholder.mesh = malha
	corpo.add_child(malhaholder)
	var colisao := CollisionShape3D.new()
	colisao.name = "Colisao"
	colisao.shape = malha.create_trimesh_shape()
	corpo.add_child(colisao)


func _assentar_estruturas() -> void:
	if has_node("Celeiro"):
		var c: Node3D = $Celeiro
		c.position.y = altura(c.position.x, c.position.z) - 0.4
		var mat_mad := StandardMaterial3D.new()
		mat_mad.albedo_color = Color(0.55, 0.38, 0.22)
		mat_mad.roughness = 0.85
		(c as CSGBox3D).material = mat_mad
	if has_node("Lagoa"):
		var l: Node3D = $Lagoa
		l.position.y = altura(l.position.x, l.position.z) + 0.1
		var mat_agua := StandardMaterial3D.new()
		mat_agua.albedo_color = Color(0.25, 0.50, 0.75)
		mat_agua.roughness = 0.25
		mat_agua.metallic = 0.35
		(l as CSGBox3D).material = mat_agua
	for filho in get_children():
		if filho is Node3D and (str(filho.name).begins_with("Placa_") or str(filho.name).begins_with("Arvore_") or str(filho.name).begins_with("Ultimate_")): 
			(filho as Node3D).position.y = altura((filho as Node3D).position.x, (filho as Node3D).position.z)


func _vestir_arvores_especiais() -> void:
	var mat_folhagem := StandardMaterial3D.new()
	mat_folhagem.albedo_color = Color(0.24, 0.38, 0.20)
	mat_folhagem.roughness = 0.95
	var mat_casca := StandardMaterial3D.new()
	mat_casca.albedo_texture = load("res://assets/Textured Stylized Trees - May 2020/Textures/Tree_Bark.jpg") as Texture2D
	mat_casca.roughness = 0.9
	for filho in get_children():
		if not (filho is Node3D and ("Pine" in str(filho.name) or "Tree1" in str(filho.name))):
			continue
		var e_pinheiro := "Pine" in str(filho.name)
		var malhas := (filho as Node).find_children("*", "MeshInstance3D", true, false)
		for m in malhas:
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			if e_pinheiro and mi.mesh.get_surface_count() > 1:
				mi.set_surface_override_material(1, mat_folhagem)
			elif not e_pinheiro and mi.mesh.get_surface_count() > 1:
				mi.set_surface_override_material(0, mat_casca)
				mi.set_surface_override_material(1, mat_folhagem)


func _criar_fileiras() -> void:
	var malha_planta := SphereMesh.new()
	malha_planta.radius = 0.28
	malha_planta.height = 0.7
	for f: Dictionary in FILEIRAS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = f["cor"]
		mat.roughness = 0.9
		for i: int in PLANTAS_POR_FILEIRA:
			var planta := MeshInstance3D.new()
			planta.mesh = malha_planta
			planta.set_surface_override_material(0, mat)
			var px := float(f["x"])
			var pz := Z_INICIAL + float(i) * ESPACAMENTO
			planta.position = Vector3(px, altura(px, pz) + 0.45, pz)
			add_child(planta)
