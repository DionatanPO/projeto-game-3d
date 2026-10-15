extends Node3D
## VegetacaoMundo: espalha Plant_1..Plant_4 por todo o mapa.
## 4 MultiMeshes (1 por especie) = milhares de plantas com 4 draws.
## Evita cenarios, estrada, spawn e galpao. Segue o relevo do Terreno.

const PACKS := [
  preload("res://assets/models/Plant_1.fbx"),
  preload("res://assets/models/Plant_2.fbx"),
  preload("res://assets/models/Plant_3.fbx"),
  preload("res://assets/models/Plant_4.fbx"),
]

const GRUPOS := 45
const POR_GRUPO := 16
const RAIO_GRUPO := 9.0
const ESC_MIN := 2.0
const ESC_MAX := 3.4
const SEED := 777
const LIMITE := 135.0

# [x, z, raio] a manter limpo (cenarios + estrada + galpao)
const EXCLUIR := [
  [0.0, 0.0, 55.0], [120.0, 0.0, 55.0], [-120.0, 0.0, 55.0],
  [0.0, -120.0, 55.0], [0.0, 120.0, 55.0], [-120.0, 120.0, 55.0],
  [120.0, -120.0, 55.0], [0.0, 14.0, 55.0],
  [-100.0, 0.7, 12.0], [-80.0, 0.7, 12.0], [-60.0, 0.7, 12.0],
  [-40.0, 0.7, 12.0], [-20.0, 0.7, 12.0], [-5.0, 0.7, 12.0],
  [-6.5, -59.6, 22.0],
]

func _ready() -> void:
  var rng := RandomNumberGenerator.new()
  rng.seed = SEED
  for pi in PACKS.size():
    var malha := _extrair_malha(PACKS[pi])
    if malha == null:
      push_error("VegetacaoMundo: malha Plant_%d nao encontrada." % (pi + 1))
      continue
    var lista: Array[Transform3D] = []
    var grupos_ok := 0
    var tent := 0
    while grupos_ok < GRUPOS and tent < GRUPOS * 40:
      tent += 1
      var cx := rng.randf_range(-LIMITE, LIMITE)
      var cz := rng.randf_range(-LIMITE, LIMITE)
      if _excluido(cx, cz):
        continue
      grupos_ok += 1
      if grupos_ok == 1 and pi == 0:
        print("VEGETACAO_DEBUG_CENTRO=", cx, ",", cz)
      for k in POR_GRUPO:
        var x := cx + rng.randf_range(-RAIO_GRUPO, RAIO_GRUPO)
        var z := cz + rng.randf_range(-RAIO_GRUPO, RAIO_GRUPO)
        if _excluido(x, z):
          continue
        var s := rng.randf_range(ESC_MIN, ESC_MAX)
        var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s)), Vector3(x, _altura(x, z) - 0.05, z))
        lista.append(t)
    print("VEGETACAO_Plant_", pi + 1, "=", lista.size(), " grupos=", grupos_ok)
    _multi(malha, lista)

func _excluido(x: float, z: float) -> bool:
  for e in EXCLUIR:
    var dx := x - float(e[0])
    var dz := z - float(e[1])
    if dx * dx + dz * dz < float(e[2]) * float(e[2]):
      return true
  return false

func _altura(x: float, z: float) -> float:
  var t := get_parent().get_node_or_null("Terreno") as StaticBody3D
  if t != null and t.has_method("altura"):
    return float(t.call("altura", x, z))
  return 0.0

func _extrair_malha(pack: PackedScene) -> Mesh:
  var tmp := (pack as PackedScene).instantiate() as Node
  var achados := tmp.find_children("*", "MeshInstance3D", true, false)
  var malha: Mesh = null
  if achados.size() > 0:
    malha = (achados[0] as MeshInstance3D).mesh
  tmp.queue_free()
  return malha

func _multi(malha: Mesh, lista: Array[Transform3D]) -> void:
  if lista.is_empty():
    return
  var mm := MultiMesh.new()
  mm.transform_format = MultiMesh.TRANSFORM_3D
  mm.mesh = malha
  mm.instance_count = lista.size()
  for i in lista.size():
    mm.set_instance_transform(i, lista[i])
  var mmi := MultiMeshInstance3D.new()
  mmi.multimesh = mm
  mmi.custom_aabb = AABB(Vector3(-260, -30, -260), Vector3(520, 90, 520))
  add_child(mmi)
