extends Node3D
## EstradaSede: estrada de terra procedural do portal ate a casa da sede.
## - faixa 3.6m com 2 sulcos de pneu + faixa central de arrasto
## - vertex color (base terra, pneu escuro, arrasto claro, borda desbotada)
## - pedras espalhadas nas bordas (MultiMesh, sem colisao para nao travar o player)
## - segue o relevo do Terreno (plano ~0 no corredor, usa altura() se existir)

@export var largura := 3.6
@export var altura_offset := 0.07
@export var pedras_qtd := 140
@export var seed := 4103

# caminho em XZ do portal ate a frente da casa (mundo)
const PONTOS := [
  Vector2(-101.5, 0.73),
  Vector2(-85.0, 0.70),
  Vector2(-65.0, 0.70),
  Vector2(-45.0, 0.70),
  Vector2(-25.0, 0.70),
  Vector2(-15.0, 0.90),
  Vector2(-9.0, 1.50),
  Vector2(-5.5, 2.60),
]

const COR_TERRA := Color(0.58, 0.47, 0.34)
const COR_PNEU := Color(0.30, 0.24, 0.18)
const COR_ARRASTO := Color(0.68, 0.58, 0.42)
const COR_BORDA := Color(0.52, 0.44, 0.33)

func _ready() -> void:
  _gerar()

func altura_chao(x: float, z: float) -> float:
  var t := get_parent().get_node_or_null("Terreno") as StaticBody3D
  if t != null and t.has_method("altura"):
    return float(t.call("altura", x, z))
  return 0.0

func _gerar() -> void:
  for c in get_children():
    remove_child(c)
    c.queue_free()
  var rng := RandomNumberGenerator.new()
  rng.seed = seed
  # curva suavizada por Catmull-Rom amostrado
  var amostras: Array[Vector2] = []
  var divis := 14
  for i in range(PONTOS.size() - 1):
    var p0: Vector2 = PONTOS[maxi(i - 1, 0)]
    var p1: Vector2 = PONTOS[i]
    var p2: Vector2 = PONTOS[i + 1]
    var p3: Vector2 = PONTOS[mini(i + 2, PONTOS.size() - 1)]
    for j in range(divis):
      var tt := float(j) / float(divis)
      amostras.append(_catmull(p0, p1, p2, p3, tt))
  amostras.append(PONTOS[PONTOS.size() - 1])
  var n := amostras.size()
  var faixas := 9 # vertices por secao transversal (-1.8 .. +1.8)
  var verts := PackedVector3Array()
  var cores := PackedColorArray()
  var uvs := PackedVector2Array()
  var idx := PackedInt32Array()
  verts.resize(n * faixas)
  cores.resize(n * faixas)
  uvs.resize(n * faixas)
  var dist_ac := 0.0
  for i in range(n):
    var p: Vector2 = amostras[i]
    var q: Vector2 = amostras[mini(i + 1, n - 1)]
    var q0: Vector2 = amostras[maxi(i - 1, 0)]
    if i > 0:
      dist_ac += p.distance_to(amostras[i - 1])
    var dir := (q - q0)
    if dir.length() < 0.001:
      dir = Vector2(1, 0)
    dir = dir.normalized()
    var normal := Vector2(-dir.y, dir.x)
    var y0 := altura_chao(p.x, p.y) + altura_offset
    for k in range(faixas):
      var f := float(k) / float(faixas - 1) * 2.0 - 1.0 # -1..1
      var xz := p + normal * (f * largura * 0.5)
      var y := altura_chao(xz.x, xz.y) + altura_offset
      # sulco do pneu: afunda 3cm nas trilhas
      var af := absf(absf(f) - 0.45)
      if af < 0.13:
        y -= 0.03 * (1.0 - af / 0.13)
      # cor: pneu / arrasto / base com ruido
      var ruido := _hash_ruido(xz.x * 3.1, xz.y * 3.1 + dist_ac * 0.15)
      var cor := COR_TERRA.lerp(COR_BORDA, absf(f) * 0.55)
      cor = cor.lerp(Color(0.62, 0.52, 0.38), ruido * 0.25)
      if af < 0.13:
        var banda := 1.0 - af / 0.13
        # listras do pneu a cada 0.55m
        var listra := 0.75 + 0.25 * sin(dist_ac * 11.4 + f * 4.0)
        cor = cor.lerp(COR_PNEU, banda * 0.85 * listra)
      var ac := absf(f)
      if ac < 0.17:
        var arr := (1.0 - ac / 0.17) * (0.55 + 0.45 * sin(dist_ac * 7.3 + ruido * 6.0))
        cor = cor.lerp(COR_ARRASTO, arr * 0.7)
      # borda desbotada some na grama
      if absf(f) > 0.85:
        cor.a = 1.0
      verts[i * faixas + k] = Vector3(xz.x, y, xz.y)
      cores[i * faixas + k] = cor
      uvs[i * faixas + k] = Vector2(dist_ac * 0.25, f * 0.5 + 0.5)
  for i in range(n - 1):
    for k in range(faixas - 1):
      var a := i * faixas + k
      var b := a + 1
      var c := a + faixas
      var d := c + 1
      idx.append_array([a, c, b, b, c, d])
  var arr := []
  arr.resize(Mesh.ARRAY_MAX)
  arr[Mesh.ARRAY_VERTEX] = verts
  arr[Mesh.ARRAY_COLOR] = cores
  arr[Mesh.ARRAY_TEX_UV] = uvs
  arr[Mesh.ARRAY_INDEX] = idx
  var malha := ArrayMesh.new()
  malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
  var mat := StandardMaterial3D.new()
  mat.vertex_color_use_as_albedo = true
  mat.roughness = 0.96
  mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  malha.surface_set_material(0, mat)
  var mi := MeshInstance3D.new()
  mi.name = "Faixa"
  mi.mesh = malha
  add_child(mi)
  _gerar_pedras(rng, amostras)

func _gerar_pedras(rng: RandomNumberGenerator, amostras: Array[Vector2]) -> void:
  var pedra := BoxMesh.new()
  pedra.size = Vector3(0.16, 0.10, 0.13)
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.38, 0.36, 0.33)
  mat.roughness = 0.98
  pedra.material = mat
  var mm := MultiMesh.new()
  mm.transform_format = MultiMesh.TRANSFORM_3D
  mm.mesh = pedra
  mm.instance_count = pedras_qtd
  for i in range(pedras_qtd):
    var s: Vector2 = amostras[rng.randi_range(0, amostras.size() - 1)]
    var t2: Vector2 = amostras[mini(rng.randi_range(0, amostras.size() - 1), amostras.size() - 1)]
    var dir := (t2 - s)
    if dir.length() < 0.01:
      dir = Vector2(1, 0)
    dir = dir.normalized()
    var normal := Vector2(-dir.y, dir.x)
    var lado := 1.0 if rng.randf() > 0.5 else -1.0
    var fora := rng.randf_range(1.9, 2.9)
    var dentro := rng.randf() < 0.18 # poucas pedras no meio (arrasto joga pedra)
    var off := rng.randf_range(-0.9, 0.9) if dentro else lado * fora + rng.randf_range(-0.4, 0.4)
    var xz := s + normal * off
    var y := altura_chao(xz.x, xz.y) + altura_offset + 0.02
    var e := Vector3(rng.randf_range(0.5, 1.8), rng.randf_range(0.4, 1.1), rng.randf_range(0.5, 1.8))
    var tr := Transform3D(Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(e), Vector3(xz.x, y, xz.y))
    mm.set_instance_transform(i, tr)
  var mmi := MultiMeshInstance3D.new()
  mmi.name = "Pedras"
  mmi.multimesh = mm
  add_child(mmi)

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
  var t2 := t * t
  var t3 := t2 * t
  return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _hash_ruido(x: float, z: float) -> float:
  return absf(sin(x * 12.9898 + z * 78.233) * 43758.5453) - floor(absf(sin(x * 12.9898 + z * 78.233) * 43758.5453))
