@tool
extends StaticBody3D
## Terreno: relevo procedural do mundo principal.
## Plano (altura 0) perto das origens dos cenarios, ondulado no resto,
## para dar realismo sem quebrar nada construido.
## A mesma funcao gera a malha visual e a colisao (HeightMapShape3D),
## entao o jogador pisa exatamente onde o chao aparece.

@export var tamanho := 420.0
@export var celulas := 100
@export var altura_max := 12.0
@export var seed := 20240
@export var material: Material
@export var qtd_grama := 22000
@export var qtd_pedras := 120
@export var qtd_flores := 300
@export var qtd_arvores := 200
@export var qtd_samambaias := 400
@export var qtd_moitas_flor := 250

const PACK_GRAMA_A := preload("res://assets/Stylized Nature/FBX/Grass_Common_Short.fbx")
const PACK_GRAMA_B := preload("res://assets/Stylized Nature/FBX/Grass_Common_Tall.fbx")
const PACK_FLOR_B := preload("res://assets/Stylized Nature/FBX/Flower_4_Single.fbx")
const PACK_FLOR_GRUPO := preload("res://assets/Stylized Nature/FBX/Flower_3_Group.fbx")
const PACK_SAMAMBAIA := preload("res://assets/Stylized Nature/FBX/Fern_1.fbx")
const PACK_MOITA_FLOR := preload("res://assets/Stylized Nature/FBX/Bush_Common_Flowers.fbx")
const PACK_PEDRA := preload("res://assets/Stylized Nature/FBX/Rock_Medium_1.fbx")
const PACK_PEDRA_B := preload("res://assets/Stylized Nature/FBX/Rock_Medium_2.fbx")
const PACK_PEDRISCO := preload("res://assets/Stylized Nature/FBX/Pebble_Round_1.fbx")
const PACK_ARVORE_A := preload("res://assets/Stylized Nature/FBX/CommonTree_1.fbx")
const PACK_ARVORE_B := preload("res://assets/Stylized Nature/FBX/CommonTree_2.fbx")
const PACK_ARVORE_C := preload("res://assets/Stylized Nature/FBX/CommonTree_3.fbx")

# Origens dos cenarios + corredor da estrada: [x, z, raio_plano, piso].
# piso = fracao minima de relevo (0 = zero cravado, 0.05 = leve ondulacao).
const PONTOS := [
	[0.0, 0.0, 55.0, 0.05],
	[108.0, 0.0, 55.0, 0.05],
	[-108.0, 0.0, 55.0, 0.05],
	[0.0, -108.0, 55.0, 0.05],
	[0.0, 108.0, 55.0, 0.05],
	[-108.0, 108.0, 55.0, 0.05],
	[108.0, -108.0, 55.0, 0.05],
	[0.0, 12.6, 55.0, 0.05],
	[-90.0, 0.7, 12.0, 0.0],
	[-72.0, 0.7, 12.0, 0.0],
	[-54.0, 0.7, 12.0, 0.0],
	[-36.0, 0.7, 12.0, 0.0],
	[-18.0, 0.7, 12.0, 0.0],
	[-4.5, 0.7, 12.0, 0.0],
]


# As plantacoes agora sao cenas reutilizaveis (cenarios/plantacao.tscn), que
# preparam o proprio solo e removem a vegetacao da area. O terreno nao tem mais
# retangulos fixos de terra para milho/soja: assim nao sobram demarcacoes
# antigas fora de lugar quando uma plantacao e movida.
# Piso do parque solar: zona de terra (igual as bases eolicas) que tira a
# vegetacao e deixa o chao imitando solo sob/ao redor dos paineis. [x, z, raio].
const PISO_SOLAR := [0.66, 44.66, 11.0]
# Bases das turbinas eolicas em coords de mundo [x, z, raio]: so o pe de
# cada torre e aplainado, sem retangulo.
const BASES_EOLICO := [
	[30.97, 89.9, 6.0],
	[32.77, 128.6, 6.0],
	[0.78, 110.64, 6.0],
	[-29.22, 134.64, 6.0],
	[-1.03, 71.9, 6.0],
	[-31.03, 95.9, 6.0],
]


func _ready() -> void:
	_gerar()


var _granulado: Texture2D


func _gerar() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	# Uma unica grade de alturas serve a malha e a colisao.
	var n := celulas + 1
	var passo := tamanho / float(celulas)
	var g := PackedFloat32Array()
	g.resize(n * n)
	for j in n:
		for i in n:
			g[j * n + i] = altura(-tamanho / 2.0 + float(i) * passo, -tamanho / 2.0 + float(j) * passo)
	# Malha visual indexada.
	var verts := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cores := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	normais.resize(n * n)
	uvs.resize(n * n)
	cores.resize(n * n)
	for j in n:
		for i in n:
			var x := -tamanho / 2.0 + float(i) * passo
			var z := -tamanho / 2.0 + float(j) * passo
			verts[j * n + i] = Vector3(x, g[j * n + i], z)
			normais[j * n + i] = _normal_grade(g, n, passo, i, j)
			uvs[j * n + i] = Vector2(x / tamanho + 0.5, z / tamanho + 0.5)
			cores[j * n + i] = _cor_zona(x, z, g[j * n + i])
	for j in celulas:
		for i in celulas:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, b, d, a, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_INDEX] = idx
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat_uso: Material = material
	if mat_uso == null:
		if _granulado == null:
			_granulado = _criar_granulado()
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.albedo_texture = _granulado
		std.uv1_scale = Vector3(160, 160, 160)
		std.roughness = 0.95
		std.roughness_texture = _granulado
		std.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat_uso = std
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = malha
	mi.material_override = mat_uso
	add_child(mi)
	_espalhar_zelda()
	# Colisao: o HeightMap tem passo de 1 m; a escala cobre o passo da grade.
	var mapa := PackedFloat32Array()
	mapa.resize(n * n)
	for k in n * n:
		mapa[k] = g[k] / passo
	var forma := HeightMapShape3D.new()
	forma.map_width = n
	forma.map_depth = n
	forma.map_data = mapa
	var col := CollisionShape3D.new()
	col.name = "Colisao"
	col.shape = forma
	col.scale = Vector3(passo, passo, passo)
	add_child(col)


func _normal_grade(g: PackedFloat32Array, n: int, passo: float, i: int, j: int) -> Vector3:
	var i0 := maxi(i - 1, 0)
	var i1 := mini(i + 1, n - 1)
	var j0 := maxi(j - 1, 0)
	var j1 := mini(j + 1, n - 1)
	var dx := g[j * n + i1] - g[j * n + i0]
	var dz := g[j1 * n + i] - g[j0 * n + i]
	var ex := float(i1 - i0) * passo
	var ez := float(j1 - j0) * passo
	return Vector3(-dx, ex, -dz).normalized() if ex > 0.0 and ez > 0.0 else Vector3.UP


## Altura estilo Zelda: relevo ondulado com cadeia de 4 montanhas imponentes
## espalhadas equilibradamente pelos quadrantes do mapa, todas escaláveis:
## 1. Pico da Nebulosa (Noroeste): O cume supremo do mapa (~54m) com neve e vista de pássaro.
## 2. Morro do Silo (Sudeste): Platô rochoso panorâmico (~36m).
## 3. Montanha do Mirante (Nordeste): Crista em espiral clássica (~32m).
## 4. Serra do Horizonte (Norte Central: X ≈ 0, Z ≈ -175): Formação montanhosa de ~40m.
## A área da caverna (X ≈ -130, Z ≈ 45) é aplainada para a gruta de pedra.
func altura(x: float, z: float) -> float:
	var mascara := _mascara_plano(x, z)
	if mascara <= 0.001:
		return 0.0

	var ondulacao := fbm(x, z) * 1.6
	var r := Vector2(x, z).length()
	var borda := smoothstep(165.0, 210.0, r)
	var borda_montanhas := borda * (6.0 + fbm(x * 0.5 + 31.0, z * 0.5 - 17.0) * 3.5)

	# ─── 1. PICO DA NEBULOSA (SUPER MONTANHA - Noroeste: X ≈ -135, Z ≈ -125) ───
	# O pico supremo do mapa: 54 metros de altura com neve
	var mx1 := -135.0
	var mz1 := -125.0
	var dist_m1 := Vector2(x - mx1, z - mz1).length()
	var h_pico1 := 0.0
	if dist_m1 < 95.0:
		var t1 := clampf(dist_m1 / 86.0, 0.0, 1.0)
		var perfil1 := pow(1.0 - t1, 1.45)
		h_pico1 = perfil1 * 54.0
		var rocha1 := fbm(x * 1.5 - 10.0, z * 1.5 + 20.0) * (1.0 - t1) * 5.0
		h_pico1 += rocha1
		var angulo1 := atan2(z - mz1, x - mx1)
		var raio_trilha1 := lerpf(12.0, 78.0, (angulo1 + PI) / TAU)
		var d_trilha1 := absf(dist_m1 - raio_trilha1)
		if d_trilha1 < 12.0:
			h_pico1 -= (1.0 - d_trilha1 / 12.0) * 3.5

	# ─── 2. MORRO DO SILO (Sudeste: X ≈ 125, Z ≈ -125) ────────────────────────
	# Montanha rochosa com mirante panorâmico: 36 metros de altura
	var mx2 := 125.0
	var mz2 := -125.0
	var dist_m2 := Vector2(x - mx2, z - mz2).length()
	var h_pico2 := 0.0
	if dist_m2 < 78.0:
		var t2 := clampf(dist_m2 / 70.0, 0.0, 1.0)
		var perfil2 := pow(1.0 - t2, 1.55)
		h_pico2 = perfil2 * 36.0
		var rocha2 := fbm(x * 1.7 + 35.0, z * 1.7 - 15.0) * (1.0 - t2) * 4.0
		h_pico2 += rocha2
		var angulo2 := atan2(z - mz2, x - mx2)
		var raio_trilha2 := lerpf(10.0, 62.0, (angulo2 + PI) / TAU)
		var d_trilha2 := absf(dist_m2 - raio_trilha2)
		if d_trilha2 < 10.0:
			h_pico2 -= (1.0 - d_trilha2 / 10.0) * 2.8

	# ─── 3. MONTANHA DO MIRANTE (Nordeste: X ≈ 130, Z ≈ 120) ───────────────────
	# Montanha clássica: 32 metros de altura
	var mx3 := 130.0
	var mz3 := 120.0
	var dist_m3 := Vector2(x - mx3, z - mz3).length()
	var h_pico3 := 0.0
	if dist_m3 < 75.0:
		var t3 := clampf(dist_m3 / 68.0, 0.0, 1.0)
		var perfil3 := pow(1.0 - t3, 1.6)
		h_pico3 = perfil3 * 32.0
		var rocha3 := fbm(x * 1.8 + 12.0, z * 1.8 - 45.0) * (1.0 - t3) * 3.8
		h_pico3 += rocha3
		var angulo3 := atan2(z - mz3, x - mx3)
		var raio_trilha3 := lerpf(8.0, 60.0, (angulo3 + PI) / TAU)
		var d_trilha3 := absf(dist_m3 - raio_trilha3)
		if d_trilha3 < 9.0:
			h_pico3 -= (1.0 - d_trilha3 / 9.0) * 2.2

	# ─── 4. SERRA DO HORIZONTE (Norte: X ≈ 0, Z ≈ -175) ────────────────────────
	# Cordilheira ao fundo norte: 40 metros de altura
	var mx4 := 0.0
	var mz4 := -175.0
	var dist_m4 := Vector2(x - mx4, z - mz4).length()
	var h_pico4 := 0.0
	if dist_m4 < 80.0:
		var t4 := clampf(dist_m4 / 72.0, 0.0, 1.0)
		var perfil4 := pow(1.0 - t4, 1.5)
		h_pico4 = perfil4 * 40.0
		var rocha4 := fbm(x * 1.6 - 25.0, z * 1.6 + 10.0) * (1.0 - t4) * 4.2
		h_pico4 += rocha4
		var angulo4 := atan2(z - mz4, x - mx4)
		var raio_trilha4 := lerpf(10.0, 64.0, (angulo4 + PI) / TAU)
		var d_trilha4 := absf(dist_m4 - raio_trilha4)
		if d_trilha4 < 10.0:
			h_pico4 -= (1.0 - d_trilha4 / 10.0) * 3.0

	# ─── 5. ÁREA DA CAVERNA (Sudoeste/Oeste: X ≈ -130, Z ≈ 45) ──────────────────
	# Sem montanha: a caverna é uma formação rochosa independente (caverna.tscn).
	# Aplainamos levemente a zona ao redor para que o jogador caminhe sem obstáculos
	# e as rochas da caverna assentem direto no chão.
	var cx_cav := -130.0
	var cz_cav := 45.0
	var dist_cav := Vector2(x - cx_cav, z - cz_cav).length()
	var rebaixo_cav := 0.0
	if dist_cav < 25.0:
		# Suaviza o terreno ao redor da caverna (mantém perto de 0)
		var t_cav := clampf(dist_cav / 25.0, 0.0, 1.0)
		rebaixo_cav = (1.0 - t_cav) * 0.85

	var max_montanhas := maxf(h_pico1, maxf(h_pico2, maxf(h_pico3, h_pico4)))
	var h_final := maxf((ondulacao * 0.6 + borda_montanhas) * mascara, max_montanhas * mascara)
	# Rebaixa suavemente a área da caverna para nivelar
	if rebaixo_cav > 0.0:
		h_final = lerpf(h_final, 0.0, rebaixo_cav)

	# ─── 6. BACIA DO LAGO (Sudeste médio: X ≈ 85, Z ≈ 65) ────────────────────
	# Depressão suave no terreno criando leito natural para a água.
	var lx := 85.0
	var lz := 65.0
	# Elipse: raio X=20, raio Z=17 para forma orgânica
	var dlx := (x - lx) / 20.0
	var dlz := (z - lz) / 17.0
	var dist_lago := Vector2(dlx, dlz).length()
	if dist_lago < 1.0:
		var bacia := smoothstep(1.0, 0.0, dist_lago)
		h_final -= bacia * 2.2

	return h_final



func _mascara_plano(x: float, z: float) -> float:
	var d_min := 9999.0
	for p in PONTOS:
		var dx := x - float(p[0])
		var dz := z - float(p[1])
		var d := Vector2(dx, dz).length() - float(p[2])
		d_min = minf(d_min, d)
	d_min = minf(d_min, _dist_zonas_terra(x, z))
	if d_min <= 0.0:
		return 0.0
	return clampf(d_min / 25.0, 0.0, 1.0)


## Menor distancia fora das zonas de terra (piso solar + bases eolicas).
func _dist_zonas_terra(x: float, z: float) -> float:
	var d := Vector2(x - float(PISO_SOLAR[0]), z - float(PISO_SOLAR[1])).length() - float(PISO_SOLAR[2])
	for b in BASES_EOLICO:
		var dx := x - float(b[0])
		var dz := z - float(b[1])
		d = minf(d, Vector2(dx, dz).length() - float(b[2]))
	return d


## Cor por zona (sem textura): terra no nucleo/spawn, grama variada fora,
## pedra no alto/inclinado e picos nevados.
func _cor_zona(x: float, z: float, h: float) -> Color:
	var grama_a := Color(0.14, 0.19, 0.06)
	var grama_b := Color(0.18, 0.23, 0.08)
	var terra := Color(0.44, 0.32, 0.21)
	var pedra_escura := Color(0.38, 0.40, 0.42)
	var pedra_clara := Color(0.66, 0.68, 0.70)
	var cume_neve := Color(0.92, 0.95, 0.98)

	var n := ruido(x * 0.15, z * 0.15) * 0.5 + 0.5
	var cor := grama_a.lerp(grama_b, n)
	var d_centro := Vector2(x, z).length()
	var m_terra := 1.0 - smoothstep(18.0, 34.0, d_centro)
	var m_ret := 1.0 - smoothstep(0.0, 4.0, _dist_zonas_terra(x, z))
	cor = cor.lerp(terra, maxf(m_terra * 0.9, m_ret * 0.95))

	# Transição para rocha conforme ganha altitude
	if h > 4.5:
		var m_pedra := smoothstep(4.5, 16.0, h)
		var tipo_pedra := pedra_escura.lerp(pedra_clara, n)
		cor = cor.lerp(tipo_pedra, m_pedra)

	# Cristas altas (acima de 20m)
	if h > 20.0:
		var m_alta := smoothstep(20.0, 32.0, h)
		cor = cor.lerp(pedra_clara, m_alta * 0.7)

	# Picos nevados no topo supremo (acima de 35m até 54m)
	if h > 34.0:
		var m_neve := smoothstep(34.0, 48.0, h)
		cor = cor.lerp(cume_neve, m_neve * 0.95)

	return cor




## Ruido de valor com 4 oitavas, deterministico (-1..1).
func fbm(x: float, z: float) -> float:
	var total := 0.0
	var amp := 0.55
	var freq := 1.0 / 70.0
	for _o in 4:
		total += amp * ruido(x * freq, z * freq)
		amp *= 0.5
		freq *= 2.0
	return clampf(total / 0.9375, -1.0, 1.0)


func ruido(x: float, z: float) -> float:
	var xi := floori(x)
	var zi := floori(z)
	var xf := x - float(xi)
	var zf := z - float(zi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := zf * zf * (3.0 - 2.0 * zf)
	var a := _hash(xi, zi)
	var b := _hash(xi + 1, zi)
	var c := _hash(xi, zi + 1)
	var d := _hash(xi + 1, zi + 1)
	return (lerpf(lerpf(a, b, u), lerpf(c, d, u), v) - 0.5) * 2.0


## Granulado 256px gerado em codigo (sem asset): macro + grão fino.
## Multiplica a cor por zona via vertex color; mipmaps cuidam da distancia.
func _criar_granulado() -> ImageTexture:
	var tam := 256
	var img := Image.create(tam, tam, false, Image.FORMAT_RGB8)
	for y in tam:
		for x in tam:
			var macro := ruido(float(x) * 0.12, float(y) * 0.12) * 0.5 + 0.5
			var fino := ruido(float(x) * 0.9 + 40.0, float(y) * 0.9 - 17.0) * 0.5 + 0.5
			var v := clampf(0.82 + macro * 0.10 + (fino - 0.5) * 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


func _hash(x: int, z: int) -> float:
	var n := x * 374761393 + z * 668265263 + seed * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


## Scatter com o pack Stylized Nature: grama, flores, moitas (com flor),
## pedras e arvores em MultiMesh por lotes, com culling por distancia.
## So desenha perto do jogador; longe some (a cor do chao cobre).
var _colisoes_pedra: Array = []


func _espalhar_zelda() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 99
	_colisoes_pedra.clear()
	# Vegetação rasteira: grama curta e densa cobrindo o chão como tapete.
	# Escala baixa (0.35–0.85) + y_flat 0.35 = moitas bem rentes ao solo.
	# 22 mil instâncias em MultiMesh é leve (1 draw call por lote de 35m).
	_espalhar_pack(rng, "GramaA", _partes_pack(PACK_GRAMA_A), qtd_grama / 2, 18.0, 3.5, 0.35, 0.85, 75.0, 35.0, -0.02, true, 0.35)
	_espalhar_pack(rng, "GramaB", _partes_pack(PACK_GRAMA_B), qtd_grama / 2, 18.0, 3.5, 0.35, 0.85, 75.0, 35.0, -0.02, true, 0.35)
	_espalhar_pack(rng, "FlorB", _partes_pack(PACK_FLOR_B), qtd_flores / 2, 26.0, 3.5, 0.7, 1.2, 75.0, 35.0, -0.02, true)
	_espalhar_pack(rng, "FlorGrupo", _partes_pack(PACK_FLOR_GRUPO), qtd_flores / 2, 26.0, 3.5, 0.7, 1.2, 75.0, 35.0, -0.02, true)
	_espalhar_pack(rng, "Samambaia", _partes_pack(PACK_SAMAMBAIA), qtd_samambaias, 26.0, 3.5, 0.4, 0.7, 75.0, 35.0, -0.02, true)
	_espalhar_pack(rng, "MoitaFlor", _partes_pack(PACK_MOITA_FLOR), qtd_moitas_flor, 28.0, 4.5, 0.6, 1.2, 95.0, 40.0, 0.0, false)

	# Pedras e pedregulhos
	_espalhar_pack(rng, "Pedra", _partes_pack(PACK_PEDRA), qtd_pedras / 3, 30.0, 99.0, 0.8, 2.2, 180.0, 60.0, 0.05, false, 1.0, true)
	_espalhar_pack(rng, "PedraB", _partes_pack(PACK_PEDRA_B), qtd_pedras / 3, 30.0, 99.0, 0.8, 2.2, 180.0, 60.0, 0.05, false, 1.0, true)
	_espalhar_pack(rng, "Pedrisco", _partes_pack(PACK_PEDRISCO), qtd_pedras / 3, 20.0, 3.5, 0.5, 1.2, 95.0, 40.0, 0.0, true)

	# ÁRVORES OTIMIZADAS:
	# Lotes menores de 45m (em vez de 100m) e visibilidade estendida para 320m com margem suave de fade de 45m.
	# Isso elimina completamente o "popping" de blocos gigantes de árvores aparecendo do nada na tela!
	_espalhar_pack(rng, "ArvoreA", _partes_pack(PACK_ARVORE_A), qtd_arvores / 3, 30.0, 16.0, 0.8, 1.4, 320.0, 45.0, -0.1, false)
	_espalhar_pack(rng, "ArvoreB", _partes_pack(PACK_ARVORE_B), qtd_arvores / 3, 30.0, 16.0, 0.8, 1.4, 320.0, 45.0, -0.1, false)
	_espalhar_pack(rng, "ArvoreC", _partes_pack(PACK_ARVORE_C), qtd_arvores / 3, 30.0, 16.0, 0.8, 1.4, 320.0, 45.0, -0.1, false)
	_construir_colisao_pedras()


func _partes_pack(pack: PackedScene) -> Array:
	var partes: Array = []
	var tmp := pack.instantiate() as Node
	if tmp == null:
		return partes
	for no in tmp.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi != null and mi.mesh != null:
			partes.append({"mesh": mi.mesh, "transform": mi.transform})
	tmp.free()
	return partes


func _espalhar_pack(rng: RandomNumberGenerator, nome: String, partes: Array, qtd: int, raio_livre: float, h_max: float, esc_min: float, esc_max: float, alcance: float, tam_lote: float, y_off: float, concentrar: bool, y_flat: float = 1.0, registrar_colisao: bool = false) -> void:
	if partes.is_empty() or qtd <= 0:
		return
	var lotes: Dictionary = {}
	var min_y_lote: Dictionary = {}
	var max_y_lote: Dictionary = {}

	var tent := 0
	var colocadas := 0
	while colocadas < qtd and tent < qtd * 15:
		tent += 1
		var x := 0.0
		var z := 0.0
		if concentrar and rng.randf() < 0.5:
			var cx := 0.0 if rng.randf() < 0.5 else -87.0
			var cz := 0.0 if cx == 0.0 else 0.66
			x = cx + rng.randf_range(-90.0, 90.0)
			z = cz + rng.randf_range(-90.0, 90.0)
		else:
			x = rng.randf_range(-195.0, 195.0)
			z = rng.randf_range(-195.0, 195.0)
		var d_perto := minf(Vector2(x, z).length(), Vector2(x + 87.0, z - 0.66).length())
		if Vector2(x, z).length() <= raio_livre:
			continue
		if _dist_zonas_terra(x, z) <= 0.0:
			continue
		# Impede vegetação dentro do lago (elipse X=85, Z=65)
		var _dlx := (x - 85.0) / 21.0
		var _dlz := (z - 65.0) / 18.0
		if Vector2(_dlx, _dlz).length() < 1.0:
			continue
		if concentrar and d_perto > 110.0 and rng.randf() < (d_perto - 110.0) / 150.0:
			continue
		var h := altura(x, z)
		if h > h_max:
			continue
		var s := rng.randf_range(esc_min, esc_max)
		var base := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * y_flat, s)), Vector3(x, h + y_off, z))
		if registrar_colisao:
			_colisoes_pedra.append({"pos": base.origin, "s": s})
		var cel := Vector2i(floori((x + 200.0) / tam_lote), floori((z + 200.0) / tam_lote))
		if not lotes.has(cel):
			lotes[cel] = []
			min_y_lote[cel] = h
			max_y_lote[cel] = h
		else:
			min_y_lote[cel] = minf(float(min_y_lote[cel]), h)
			max_y_lote[cel] = maxf(float(max_y_lote[cel]), h)
		(lotes[cel] as Array).append(base)
		colocadas += 1

	for parte in partes:
		var malha := (parte as Dictionary)["mesh"] as Mesh
		var t_parte := (parte as Dictionary)["transform"] as Transform3D
		for cel in lotes:
			var lista: Array = lotes[cel]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = malha
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, (lista[i] as Transform3D) * t_parte)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [nome, (cel as Vector2i).x, (cel as Vector2i).y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = alcance
			mmi.visibility_range_end_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

			# AABB preciso por célula considerando a elevação real do relevo
			var metade := tam_lote * 0.5
			var ccx := -200.0 + (float((cel as Vector2i).x) + 0.5) * tam_lote
			var ccz := -200.0 + (float((cel as Vector2i).y) + 0.5) * tam_lote
			var y_base := float(min_y_lote.get(cel, 0.0)) - 2.0
			var y_altura := maxf(float(max_y_lote.get(cel, 10.0)) - y_base + 18.0, 15.0)
			mmi.custom_aabb = AABB(Vector3(ccx - metade, y_base, ccz - metade), Vector3(tam_lote, y_altura, tam_lote))
			add_child(mmi)



func _construir_colisao_pedras() -> void:
	if _colisoes_pedra.is_empty():
		return
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoPedras"
	for item in _colisoes_pedra:
		var d := item as Dictionary
		var s := float(d.get("s", 1.0))
		var col := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(2.8 * s, 2.2 * s, 2.8 * s)
		col.shape = caixa
		col.position = (d.get("pos", Vector3.ZERO) as Vector3) + Vector3(0, 0.8 * s, 0)
		corpo.add_child(col)
	add_child(corpo)
