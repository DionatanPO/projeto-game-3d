extends Node3D
## Colisao da sede: automatica e compartilhada (sem redundancia).
## Le os filhos da cena em _ready: cada cerca ganha a mesma forma
## (BoxShape 6.0m = tamanho real da Fence2 medido no FBX); cada predio
## ganha 1 caixa da malha real. Torres (agua/vento) usam coluna estreita
## para nao bloquear a area em volta. Editar a cena nao quebra nada.

const ALTURA_CERCA := 0.8


func _ready() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoSede"
	add_child(corpo)
	var cerca_forma := BoxShape3D.new()
	cerca_forma.size = Vector3(6.0, 1.6, 0.4)
	for filho in get_children():
		if filho == corpo or not (filho is Node3D):
			continue
		if filho is Area3D:
			continue
		if filho.is_in_group("jogador") or filho.is_in_group("drone_jogador") or filho.is_in_group("trator_jogador"):
			continue
		if "Cerca" in str(filho.name):
			var t := (filho as Node3D).transform
			var col := CollisionShape3D.new()
			col.shape = cerca_forma
			col.transform = Transform3D(t.basis, t.origin + Vector3(0, ALTURA_CERCA, 0))
			corpo.add_child(col)
		else:
			_caixa_predio(corpo, filho as Node3D)


func _caixa_predio(corpo: StaticBody3D, predio: Node3D) -> void:
	var caixa := AABB()
	var tem := false
	for no in predio.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a: AABB = predio.transform * mi.transform * mi.mesh.get_aabb()
		caixa = a if not tem else caixa.merge(a)
		tem = true
	if not tem:
		return
	if "WaterTower" in predio.name:
		_coluna(corpo, caixa, 1.4)
	elif "Windmill" in predio.name:
		_coluna(corpo, caixa, 2.0)
	else:
		var forma := BoxShape3D.new()
		forma.size = caixa.size
		var col := CollisionShape3D.new()
		col.shape = forma
		col.position = caixa.get_center()
		corpo.add_child(col)


## Torres: so o fuste/mastro colide; da para andar em volta e embaixo.
func _coluna(corpo: StaticBody3D, caixa: AABB, largura: float) -> void:
	var centro := caixa.get_center()
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura, caixa.size.y, largura)
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3(centro.x, caixa.position.y + caixa.size.y * 0.5, centro.z)
	corpo.add_child(col)
