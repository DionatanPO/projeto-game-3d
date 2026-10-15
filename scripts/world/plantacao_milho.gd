extends Node3D
## PlantacaoMilho: pes Corn_1 (nascendo) e Corn_2 (com milho) em fileiras
## alternadas. 2 MultiMeshes = centenas de plantas com 2 draws.
## Semente fixa = layout deterministico.

const PACK_1 := preload("res://assets/models/Corn_1.fbx")
const PACK_2 := preload("res://assets/models/Corn_2.fbx")

const X0 := -12.0
const X1 := 54.0
const PASSO_F := 1.5
const Z0 := -20.0
const Z1 := 4.0
const PASSO_P := 1.5
const SEED := 42
const BASE_Y := 0.0

func _ready() -> void:
  var m1 := _extrair_malha(PACK_1)
  var m2 := _extrair_malha(PACK_2)
  if m1 == null or m2 == null:
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
      var s := rng.randf_range(0.9, 1.15)
      var base := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s)), pos)
      if fileira % 2 == 0:
        t1.append(base)
      else:
        t2.append(base)
      z += PASSO_P
    fileira += 1
    x += PASSO_F
  print("MILHO_NASCENDO=", t1.size(), " MILHO_COM_ESPIGA=", t2.size())
  _multi(m1, t1)
  _multi(m2, t2)

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
  mmi.custom_aabb = AABB(Vector3(-40, -5, -40), Vector3(120, 30, 120))
  add_child(mmi)
