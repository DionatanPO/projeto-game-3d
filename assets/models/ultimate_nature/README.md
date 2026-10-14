# Ultimate Stylized Nature — importado para o projeto

Pack original: "Ultimate Stylized Nature - May 2022" (63 modelos + 23 texturas).
Formato canônico adotado: **FBX** (glTF/OBJ eram o mesmo conteúdo triplicado e foram descartados).
Fonte Blender preservada em `AllModels.blend`. Licença em `LICENSE.txt`. Referência visual em `Preview.jpg`.

## Onde está cada coisa

- Modelos: `assets/models/ultimate_nature/FBX/*.fbx`
- Texturas: `assets/models/ultimate_nature/Textures/*.png|*.jpg`
- Helper de código: `res://scripts/world/nature_props.gd`

## Catálogo por categoria

### Árvores (35)
- Birch: `BirchTree_1` … `BirchTree_5`
- Maple: `MapleTree_1` … `MapleTree_5`
- Normal: `NormalTree_1` … `NormalTree_5`
- Pine: `PineTree_1` … `PineTree_5`
- Palm: `PalmTree_1` … `PalmTree_5`
- Secas/mortas: `DeadTree_1` … `DeadTree_10`

### Rochas (5)
- `Rock_1` … `Rock_5` (textura `Rocks.png`)

### Vegetação baixa (23)
- Arbustos: `Bush`, `Bush_Flowers`, `Bush_Large`, `Bush_Large_Flowers`, `Bush_Small`, `Bush_Small_Flowers`
- Grama: `Grass_Large`, `Grass_Large_Extruded`, `Grass_Small`
- Plantas: `Plant_1`, `Plant_2`, `Plant_Flowers`
- Flores: `Flower_1`, `Flower_1_Clump`, `Flower_2`, `Flower_2_Clump`, `Flower_3_Clump`, `Flower_4_Clump`, `Flower_5_Clump`
- Pétalas: `Petals_1` … `Petals_4`

## Como usar no editor

1. Arraste um `.fbx` da pasta `FBX/` para a cena aberta — o Godot importa como cena herdada.
2. Para colisão: com o nó raiz selecionado, menu `Cena > Adicionar colisão` ou embrulhe num `StaticBody3D`.
3. Folhagem/grama usam texturas com alfa — se ficar opaco, no material marque `Transparency > Alpha` (o FBX já vem com `Flowers.png`, `Grass.png`, `Bush_Leaves.png` etc.).

## Como usar por código

```gdscript
const NatureProps = preload("res://scripts/world/nature_props.gd")
var rocha: Node3D = NatureProps.instanciar("Rock_3")
add_child(rocha)
```

Dica de performance: `Grass_*`, `Flower_*` e `Petals_*` são baratos — use `MultiMeshInstance3D` para espalhar dezenas deles em vez de centenas de nós.
