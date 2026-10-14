# Mapa do mundo — cenários

Um mundo só, modelado em arquivos separados. Cada cenário tem origem própria
no mundo; o `mundo.tscn` instancia os 4 juntos (sol/céu compartilhados).

| Cenário | Arquivo | Origem no mundo | Conteúdo previsto |
|---|---|---|---|
| Sede | `sede_fazenda.tscn` | (0, 0, 0) | casa + elementos próximos |
| Milho | `plantacao_milho.tscn` | (120, 0, 0) | plantação de milho |
| Soja | `plantacao_soja.tscn` | (-120, 0, 0) | plantação de soja |
| Silo | `estrutura_silo.tscn` | (0, 0, -120) | silo, galpão e trator |
| Solar | `parque_solar.tscn` | (0, 0, 120) | parque de energia solar |
| Eolico | `parque_eolico.tscn` | (-120, 0, 120) | parque eolico (3 turbinas com rotor girando) |
| Galpao | `galpao.tscn` | (120, 0, -120) | galpao + trator + colhedeira |

Regras:

- Modele DENTRO do arquivo do cenário, perto da origem local (o `Referencia`
  marca o ponto 0,0,0 — pode apagar quando não precisar mais).
- Não passe de ~50 m da origem do seu cenário (o vizinho começa a 120 m).
- O mundo tem um Terreno com relevo procedural compartilhado (chao 500x500 com grama e colisao, gerado por scripts/world/terreno.gd): fica quase plano num raio de ~55 m das origens dos cenarios (leve ondulacao de +-0,5 m) e com morros de +-10 m no resto. Se um cenario precisar de relevo proprio, modele por cima dele no arquivo do cenario.
- Para levar o jogador a um cenário por código ou missão:
  `get_node("/root/Mundo").teleportar_para("milho")`.
- A fase antiga `environment/fazenda.tscn` continua existindo e não foi
  alterada — o mundo novo convive com ela.
