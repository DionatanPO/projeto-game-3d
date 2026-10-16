extends Node3D
## PlantacaoMilho: pes Corn_1 (nascendo) e Corn_2 (com milho) em fileiras
## alternadas. 2 MultiMeshes = centenas de plantas com 2 draws.
## Semente fixa = layout deterministico.

const PACK_1 := preload("res://assets/models/Corn_1.fbx")
const PACK_2 := preload("res://assets/models/Corn_2.fbx")

const X0 := -12.0
const X1 := 54.0
const PASSO_F := 2.4
const Z0 := -20.0
const Z1 := 4.0
const PASSO_P := 2.2
const SEED := 42
const BASE_Y := 0.0

func _ready() -> void:
  _apagar_sombra_solo()
  var dados1 := _extrair_malha(PACK_1)
  var dados2 := _extrair_malha(PACK_2)
  if dados1.is_empty() or dados2.is_empty():
    push_error("PlantacaoMilho: malha do milho nao encontrada.")
    return
  var rng := RandomNumberGenerator.new()
  rng.seed = SEED
  var t1: Array[Transform3D] = []
  var t2: Array[Transform3D] = []
  var x := X0
  var fileira := 0
  while x <= X1:
    var z := Z0
    while z <= Z1:
      var pos := Vector3(x + rng.randf_range(-0.25, 0.25), BASE_Y, z + rng.randf_range(-0.25, 0.25))
      var s := rng.randf_range(1.1, 1.4)
      var base := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s)), pos)
      if fileira % 2 == 0:
        t1.append(base * dados1["transform"])
      else:
        t2.append(base * dados2["transform"])
      z += PASSO_P
    fileira += 1
    x += PASSO_F
  print("MILHO_NASCENDO=", t1.size(), " MILHO_COM_ESPIGA=", t2.size())
  _multi(dados1["mesh"], t1)
  _multi(dados2["mesh"], t2)

func _apagar_sombra_solo() -> void:
  for f in get_children():
    if "Solo" in f.name:
      for mi in f.find_children("*", "MeshInstance3D", true, false):
        (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _extrair_malha(pack: PackedScene) -> Dictionary:
  var tmp := (pack as PackedScene).instantiate() as Node
  var achados := tmp.find_children("*", "MeshInstance3D", true, false)
  var dados := {}
  if achados.size() > 0:
    var instancia := achados[0] as MeshInstance3D
    dados = {"mesh": instancia.mesh, "transform": instancia.transform}
  tmp.free()
  return dados

func _multi(malha: Mesh, lista: Array[Transform3D]) -> void:
  if lista.is_empty():
    return
  const LARGURA_LOTE := 24.0
  const PROFUNDIDADE_LOTE := 16.0
  var lotes: Dictionary = {}
  for transform in lista:
    var celula := Vector2i(floori(transform.origin.x / LARGURA_LOTE), floori(transform.origin.z / PROFUNDIDADE_LOTE))
    if not lotes.has(celula):
      lotes[celula] = []
    lotes[celula].append(transform)
  for celula in lotes:
    var transforms: Array = lotes[celula]
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = malha
    mm.instance_count = transforms.size()
    for i in transforms.size():
      mm.set_instance_transform(i, transforms[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.name = "MilhoMultiMesh_%d_%d" % [celula.x, celula.y]
    mmi.multimesh = mm
    mmi.custom_aabb = AABB(Vector3(celula.x * LARGURA_LOTE - 3.0, -3.0, celula.y * PROFUNDIDADE_LOTE - 3.0), Vector3(LARGURA_LOTE + 6.0, 20.0, PROFUNDIDADE_LOTE + 6.0))
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)
