@tool
extends StaticBody3D
## Terreno: relevo procedural do mundo principal.
## Plano (altura 0) perto das origens dos cenarios, ondulado no resto,
## para dar realismo sem quebrar nada construido.
## A mesma funcao gera a malha visual e a colisao (HeightMapShape3D),
## entao o jogador pisa exatamente onde o chao aparece.

@export var tamanho := 300.0
@export var celulas := 100
@export var altura_max := 10.0
@export var seed := 20240
@export var material: Material

# Origens dos cenarios + corredor da estrada: [x, z, raio_plano, piso].
# piso = fracao minima de relevo (0 = zero cravado, 0.05 = leve ondulacao).
const PONTOS := [
	[0.0, 0.0, 55.0, 0.05],
	[120.0, 0.0, 55.0, 0.05],
	[-120.0, 0.0, 55.0, 0.05],
	[0.0, -120.0, 55.0, 0.05],
	[0.0, 120.0, 55.0, 0.05],
	[-120.0, 120.0, 55.0, 0.05],
	[120.0, -120.0, 55.0, 0.05],
	[0.0, 14.0, 55.0, 0.05],
	[-100.0, 0.7, 12.0, 0.0],
	[-80.0, 0.7, 12.0, 0.0],
	[-60.0, 0.7, 12.0, 0.0],
	[-40.0, 0.7, 12.0, 0.0],
	[-20.0, 0.7, 12.0, 0.0],
	[-5.0, 0.7, 12.0, 0.0],
]


func _ready() -> void:
	_gerar()


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
	var idx := PackedInt32Array()
	verts.resize(n * n)
	normais.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var x := -tamanho / 2.0 + float(i) * passo
			var z := -tamanho / 2.0 + float(j) * passo
			verts[j * n + i] = Vector3(x, g[j * n + i], z)
			normais[j * n + i] = _normal_grade(g, n, passo, i, j)
			uvs[j * n + i] = Vector2(x / tamanho + 0.5, z / tamanho + 0.5)
	for j in celulas:
		for i in celulas:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, d, b, a, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = malha
	if material != null:
		mi.material_override = material
	add_child(mi)
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


## Altura final: ruido * mascara (0 nos pontos, 1 longe).
func altura(x: float, z: float) -> float:
	var m := 1.0
	var piso := 1.0
	for p in PONTOS:
		var d := Vector2(x, z).distance_to(Vector2(p[0], p[1]))
		var mi := smoothstep(p[2], p[2] + 55.0, d)
		if mi < m:
			m = mi
			piso = p[3]
	return fbm(x, z) * altura_max * lerpf(piso, 1.0, m)


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


func _hash(x: int, z: int) -> float:
	var n := x * 374761393 + z * 668265263 + seed * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0
