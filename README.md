# AgroBrasil 3D

Jogo digital educativo 3D sobre o agronegócio brasileiro, tecnologia agrícola e
sustentabilidade no campo. Protótipo base (Godot 4.7, GDScript).

> Projeto de extensão: experiência interativa de exploração de uma propriedade
> rural fictícia, com pontos educativos, missões, diálogos e diário de
> descobertas. Otimizado para computadores de capacidade moderada
> (renderizador GL Compatibility).

## Requisitos

- Godot 4.7 (versão de mesa + export templates para Windows, se for exportar)
- Renderizador: GL Compatibility (padrão do projeto)

## Como abrir

1. Godot → Importar → selecione `project.godot` desta pasta.
2. Abra `scenes/world/mundo.tscn` (cena principal) e pressione F5.
3. Na primeira execução, ative o plugin **Godot MCP** em
   Projeto → Configurações do Projeto → Plugins (integração com IA).

## Controles

| Ação      | Tecla               |
|-----------|---------------------|
| Mover     | W A S D / setas     |
| Correr    | Shift               |
| Pular     | Espaço              |
| Olhar     | clique + mouse      |
| Interagir | E (perto da placa)  |
| Diário    | Tab                 |
| Soltar mouse | Esc              |

## Estrutura

```
project.godot
icon.svg
data/
  conteudos.json   # textos educativos das placas (título, texto, fonte)
  missoes.json     # definição das missões (pontos exigidos)
scenes/
  ui/hud.tscn           # HUD + diálogo + diário
  world/mundo.tscn      # cena principal: mundo com os 4 cenarios
  mundo/fazenda.tscn    # propriedade rural: plantação, celeiro, lagoa, placas
  player/jogador.tscn   # personagem terceira pessoa
  interagiveis/ponto_educativo.tscn  # placa educativa (reutilizável)
scripts/
  systems/  # autoloads: InputSetup, SaveSystem, Missoes, Jogo
  player/   # jogador.gd
  mundo/    # fazenda.gd (gera fileiras de plantas)
  interagiveis/  # ponto_educativo.gd
  ui/       # hud.gd
addons/godot_mcp/  # ponte MCP (Godot ↔ assistente de IA)
Documentos/  # proposta do projeto
```

## Sistemas (protótipo)

- **Exploração 3D**: personagem em terceira pessoa (SpringArm + câmera com zoom
  por colisão), pulo, corrida, gravidade.
- **Pontos educativos**: 5 placas (solo, soja, milho, água, tecnologia). Chegue
  perto e pressione E para ler.
- **Missões**: 3 missões em `data/missoes.json`, concluídas ao visitar placas.
- **Diário**: Tab abre o diário com descobertas e progresso das missões.
- **Save local**: `user://savegame.json` (descobertas, missões, posição).
  O menu oferece Continuar quando há progresso.

## Como adicionar conteúdo novo

1. **Nova placa**: em `data/conteudos.json`, adicione uma entrada
   (`titulo`, `texto`, `fonte`). Instancie `ponto_educativo.tscn` na fazenda e
   ajuste `conteudo_id` + `titulo_placa` + posição.
2. **Nova missão**: em `data/missoes.json`, adicione o item com os
   `pontos_ids` exigidos. O HUD passa a exibi-la automaticamente.
3. Textos devem citar fonte técnica (ex.: Embrapa) e evitar sugerir que uma
   prática serve para todas as regiões.

## Otimização (PCs moderados)

- GL Compatibility, sem pós-processamento pesado; céu procedural simples.
- Vegetação/plantas geradas por código com malhas e materiais compartilhados.
- Texturas: preferir compressão ETC2/ASTC para export mobile futuro.

## Roadmap (conforme proposta)

- [x] Base: mundo explorável, jogador, interação, missões, diálogo, diário, save
- [ ] Mais culturas e áreas temáticas (solo, água, mecanização, preservação)
- [ ] Atividades com objetivo de aprendizagem + feedback por decisão
- [ ] Acessibilidade (áudio, tamanho de texto, contraste) e testes em escola
- [ ] Export Windows + documentação de testes
