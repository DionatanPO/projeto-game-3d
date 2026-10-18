# Simulação de Chuva no AgroBrasil 3D

Este documento explica a implementação do sistema de simulação de chuva adicionado ao projeto.

## Como Funciona

O sistema de chuva foi implementado como uma extensão do script `Mundo` (`scripts/world/mundo.gd`) e inclui:

1. **Ativação/Desativação**: Pressione **F1** para alternar o modo de chuva
2. **Efeitos Visuais**:
   - Escurecimento do ambiente (luz ambiente reduzida, céus mais escuros)
   - Aumento leve da néblina para simular um dia chuvoso
   - Sistema de partículas de chuva (getas caindo)
   - Efeitos de relâmpago (flash de luz branca intensa)
3. **Efeitos Sonoros**: Preparado para áudio de chuva e trovão (arquivos necessários precisam ser adicionados)

## Implementação Técnica

### Sistema de Partículas
- Utiliza `GPUParticles3D` para máxima eficiência (processamento na GPU)
- 300 partículas (valor balanceado entre visual e performance)
- Partículas pequenas e alongadas simulando getas de chuva
- Queda principalmente no eixo Y com pequena variabilidade em X e Z
- Sistema posicionado acima do jogador e segue seus movimentos

### Efeito de Relâmpago
- Aumenta brevemente a intensidade da luz solar direcional
- Duração do flash: ~0.1 segundos
- Intervalo entre relâmpagos: aleatório entre 5-15 segundos
- Implementado usando `Timer` e `call_deferred` para não travar a execução

### Adaptação Ambiental
- Modifica o `WorldEnvironment` através do nó `MundoCeu`
- Reduz `ambient_light_color` e `ambient_light_energy`
- Escurece `background_color`
- Aumenta ligeiramente `fog_density`

### Seguimento do Jogador
- O sistema de partículas segue a posição do jogador (grupo "jogador")
- Mantém-se sempre 30 unidades acima do jogador para cobertura ideal

## Considerações de Performance

O sistema foi projetado para minimizar impacto no FPS:

1. **GPUParticles3D**: Processamento na GPU, muito mais eficiente que CPU particles
2. **Contagem Moderada de Partículas**: 300 partículas é baixo para efeitos de chuva
3. **Processo Simples**: Sem colisões, rotações complexas ou shaders pesados
4. **Efeito de Relâmpago Barato**: Apenas modifica propriedades de luz, sem spawn de nós
5. **Atualização Eficiente**: Posicionamento atualizado apenas quando necessário

### Otimizações Possíveis
Se necessário reduzir ainda mais o impacto:
- Reduzir `amount` para 200 ou 150 partículas
- Diminuir `lifetime` para 1.0 segundos
- Aumentar ligeiramente o `spread` para reduzir a densidade visual necessária

## Requisitos de Áudio

Para completar a experiência, são necessários arquivos de áudio:
- Loop de som de chuva suave (chuva_loop.wav)
- Efeitos de trovão (thunder_close.wav, thunder_distant.wav)

Estes devem ser colocados em `assets/audio/` e referenciados no script:
```gdscript
_rain_sound.stream = load("res://assets/audio/chuva_loop.wav")
# Para trovão, poderia usar um AudioStreamPlayer separado tocado aleatoriamente
```

## Personalização

A tecla de ativação está definida como F1 em `scripts/autoload/input_setup.gd`:
```gdscript
"chuva": [KEY_F1],
```

Para alterar, modifique esta linha ou adicione outras teclas no array.

## Integração com o Jogo

O sistema é totalmente integrado ao mundo do jogo e:
- Funciona em todos os cenários (sede, plantações, etc.)
- Não interfere nos sistemas existentes de missão, jogador, etc.
- Pode ser ativado/desativado a qualquer momento durante o gameplay