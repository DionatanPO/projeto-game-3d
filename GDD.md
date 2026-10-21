# GAME DESIGN DOCUMENT (GDD) — AGROBRASIL 3D

> **Documento de Design de Jogo — Versão Técnica & Conceitual Atualizada**  
> **Motor:** Godot Engine 4.x (GL Compatibility / Forward+)  
> **Linguagem:** GDScript  
> **Gênero:** Simulação / Aventura Educativa em 3ª Pessoa / Mundo Aberto  
> **Plataforma Alvo:** PC (Windows / Linux), com foco em compatibilidade para computadores de perfil educacional e moderado.

---

## 1. VISÃO GERAL DO PROJETO

### 1.1 Premissa e Propósito
**AgroBrasil 3D** é um jogo educativo tridimensional que une simulação de exploração em ambiente rural aberto com rigor técnico-científico sobre o agronegócio sustentável brasileiro. O projeto desmistifica a produção agropecuária moderna, apresentando práticas conservacionistas, bioinsumos, fixação biológica de nitrogênio, transição energética e tecnologias de agricultura de precisão.

### 1.2 Pilares Centrais
1. **Educação Baseada em Evidências:** Dados fundamentados em fontes como **Embrapa** (Soja, Milho e Sorgo, Solos, Agricultura Digital) e **ANA**.
2. **Exploração Multimodal Dinâmica:** O jogador transita com liberdade entre locomoção **a pé**, condução de **trator agrícola** e pilotagem de **drone com telemetria e pulverização**.
3. **Imersão Audiovisual e Otimização:** Estética estilizada limpa (Low-Poly / Stylized Nature), áudio espacial dinâmico (som de vento sintetizado em tempo real, passos adaptativos, motor procedural) e técnicas avançadas de renderização para manter 60+ FPS em hardware integrado.

---

## 2. PERSONAGENS E MODOS DE CONTROLE

O jogo oferece três modos de movimentação independentes que compartilham a mesma câmera orbital com amortecimento por mola (`SpringArm3D`) e salvamento de estado de posição:

### 2.1 O Jogador (A Pé) — `jogador.gd`
- **Movimentação:** Caminhada e corrida contínua com interpolação de inércia (`aceleracao = 10.0`, `desaceleracao = 14.0`).
- **Animações (Mixamo):** Máquina de estados para `Idle`, `SadIdle` (gatilho por inatividade), `Walk`, `Run` e `Jump`.
- **Passos Procedurais:** Sistema randômico de áudio que alterna arquivos de passos sintetizados (`passo_1..6.wav`) sincronizados com a velocidade de deslocamento.
- **Interação:** Detecção por `Area3D` com destaque de contorno e tecla `[E]` para placas e veículos.

### 2.2 O Trator Agrícola — `trator_jogador.gd`
- **Controle Veicular:** Aceleração linear com marcha ré, rotação proporcional às rodas dianteiras e física de declive.
- **Áudio do Motor:** Pitch e volume atrelados dinamicamente às rotações por minuto (RPM) e velocidade.
- **Buzina e Luzes:** Feedback interativo sonoro e visual para condução noturna ou em tempestades.

### 2.3 O Drone Agrícola — `drone_jogador.gd`
- **Física de Voo 3D Completa:** Eixos de translação lateral, frontal e altitude independente (`Espaço` sobe, `C` desce).
- **Turbo e Sensação de Velocidade:**
  - Expansão dinâmica de FOV com o aumento de velocidade.
  - Vinheta radial de borda translúcida.
  - Micro-vibração de câmera (tremor leve) na velocidade máxima (`LB` / `Shift`).
  - Efeito sonoro de vento sintetizado em tempo real (passa-baixas procedurais) atenuado para conforto auditivo.
- **Neblina de Altitude:** Atenuação progressiva do solo conforme o drone atinge o teto de voo.

---

## 3. MUNDO, GEOGRAFIA E CENÁRIOS

O mapa do mundo principal (`mundo.tscn`) possui extensão de 420x420 metros, com relevo gerado proceduralmente por malha indexada e pontos de interesse arquitetônicos:

### 3.1 Geração Procedural do Terreno (`terreno.gd`)
- **Malha Única Sem Costuras:** Grade de 100x100 células gerando 160.000 vértices com texturização por vértice (`_cor_zona`) para transições suaves entre terra escura, grama, rocha de altitude e picos nevados.
- **Colisão Física Fiel:** Geração instantânea de `HeightMapShape3D` acoplada ao relevo.
- **Vegetação Zelda-Style (`MultiMeshInstance3D`):**
  - Mais de **22.000 instâncias** de vegetação (grama densa, flores, samambaias, arbustos, pedras e árvores).
  - Divisão espacial em células com AABB customizado para culling preciso.
  - Fade suave por distância (`visibility_range_end_margin`), eliminando o efeito de *pop-in*.

### 3.2 Zonas Temáticas e Cenários Principais
1. **Sede da Fazenda (`sede_fazenda.tscn`):** Casa principal, jardins, silos de armazenamento e ponto de partida do jogador.
2. **Lavoura de Soja & Milho (`plantacao.tscn`):** Culturas em linhas paralelas com solo sob Plantio Direto e rotação de culturas.
3. **Parque Solar Fotovoltaico (`parque_solar.tscn`):** Arranjos de placas solares demonstrando autonomia energética limpa no agronegócio.
4. **Complexo Eólico (`parque_eolico.tscn` / `torre_eolica.tscn`):** Aerogeradores com rotação atrelada à velocidade dinâmica do vento.
5. **Lago Semi-Realista (`lago.tscn`):**
   - Bacia em declive suave no terreno com shader de água personalizado (`agua_lago.gdshader`).
   - Reflexo de Fresnel, ondas com ruído procedural, profundidade cromática e espuma de contato com as margens.
   - Orla decorada com rochas e colisões físicas completas.
6. **Gruta / Caverna Independente (`caverna.tscn`):**
   - Formação rochosa natural com portal de arcos de pedra e câmara interna iluminada por tochas e partículas de fogo.
   - Relevo plano no interior e passagens largas desobstruídas para exploração a pé.
7. **Laboratório de Teste de Voo (`tutorial_drone.tscn`):**
   - Galpão fechado de treinamento com 10 portais holográficos fluorescentes, cronômetro regressivo e mecânica de pulverização localizada em milharal.

---

## 4. SISTEMAS DE JOGO (GAMEPLAY LOOP)

### 4.1 Loop Central
$$\text{Explorar o Território} \longrightarrow \text{Interagir com Placas/Descobertas} \longrightarrow \text{Ganhar XP \& Completar Missões} \longrightarrow \text{Consultar Diário} \longrightarrow \text{Avançar Tecnologias}$$

### 4.2 Caderno de Campo & Descobertas (`conteudos.json`)
Ao aproximar-se de totens e placas educativas, o jogador abre um pop-up educativo com informações científicas:
- **Solo:** Matéria orgânica, microorganismos benéficos e controle de erosão.
- **Soja:** Inoculação biológica com bactérias fixadoras de nitrogênio (dispensando adubação química pesada).
- **Milho:** Segunda safra (safrinha), cadeia de rações e bioenergia (etanol de milho).
- **Água:** Irrigação por gotejamento de alta precisão, preservação de matas ciliares e nascentes.
- **Tecnologia:** Sensores remotos, telemetria de drones e aplicação em taxa variável.

### 4.3 Sistema de Missões (`missoes.json` & `missoes.gd`)
- Missões sequenciais rastreadas automaticamente via Autoload.
- Diálogo de missão concluída com opção de continuar livremente ou avançar de etapa.

### 4.4 Perfil do Produtor e Sistema de XP (`xp_manager.gd` & `player_profile.gd`)
- **Card de Perfil Moderno (HUD Top-Left):** Avatar circular com máscara estilizada, nível atual (1 a 30) e barra de progresso de experiência com gradiente verde esmeralda.
- **Curva de Progressão:** Base de 100 XP por nível com progressão exponencial de $1.5\times$ a cada marco.

### 4.5 Diário de Bordo Multissistema (`hud.gd`)
Painel em abas acessado via tecla `[Tab]` ou botão `[Y]` do controle:
- **Aba Missão:** Lista de objetivos cumpridos e pendentes com marcadores visuais.
- **Aba Controles:** Guia interativo de teclas para teclado/mouse e joystick.
- **Aba Áudio:** Controle de volumes individuais para Master, Música e Efeitos Sonoros.
- **Aba Tela:** Alternância entre Janela e Tela Cheia, VSync e limite de taxa de quadros.
- **Aba Gráficos:** Níveis de sombras (Baixo, Médio, Alto) e seletor de escala de resolução (Performance / Equilibrado / Qualidade).

### 4.6 Sistema de Clima e Chuva Dinâmica
- Ciclos procedurais de chuva leve, média e pesada com alteração do céu (`WorldEnvironment`), neblina volumétrica e partículas de gotas.
- Sons ambientes de chuva com atenuação suave.

### 4.7 Sistema de Salvamento Local (`save_system.gd`)
- Persistência serializada em JSON (`user://savegame.json`).
- Armazena: posições do jogador, trator e drone; missões completas; descobertas lidas; configurações de acessibilidade e vídeo; XP e nível acumulados.

---

## 5. INTERFACE DO USUÁRIO (UI / UX)

- **Menu Principal Lateral AAA (`menu_principal.tscn`):** Estilo minimalista com destaque em slide lateral e barra esmeralda ao focalizar, opções de *"Continuar Jornada"*, *"Nova Jornada"* e *"Sair"*.
- **Tela de Carregamento Assíncrona (`loading.tscn`):**
  - Utiliza `ResourceLoader.load_threaded_request` em thread separada.
  - Dicas agrícolas rotativas que ensinam o jogador durante o carregamento.
  - Barra de progresso real acompanhada de anel giratório minimalista de alta velocidade (`anel_loading.gd`).
  - Transições de fade preto para mascarar instanciações de malha.
- **HUD Integrado (`hud.tscn`):**
  - Mostrador de FPS discreto no canto inferior esquerdo com leitura de milissegundos de quadro (`ms`).
  - Botão de abertura de menu, avisos contextuais de interação (`[E] Interagir`) e caixas de diálogo tipográficas com alto contraste.

---

## 6. DIRETRIZES TÉCNICAS E ARQUITETURA

### 6.1 Autoloads (Singletons Globais)
| Autoload | Responsabilidade |
|---|---|
| `InputSetup` | Configuração e mapeamento híbrido de controles (Teclado/Mouse/Gamepad Xbox). |
| `SaveSystem` | Serialização e desserialização atômica do progresso do jogador em disco. |
| `AudioConfig` | Barramentos de áudio (Master, Musica, Efeitos) e aplicação de volumes salvos. |
| `Jogo` | Leitura e cache dos arquivos de dados educativos (`conteudos.json`). |
| `Missoes` | Rastreamento e checagem de cumprimento de objetivos da jornada. |
| `XPManager` | Controle de experiência, subida de nível e disparo de sinais de level-up. |

### 6.2 Convenções e Boas Práticas
- **Renderizador Primário:** GL Compatibility (OpenGL 3.3) garantindo inicialização rápida em placas integradas Intel/AMD.
- **Tipagem Estática Forte:** Código 100% tipado (`var x: float`, `-> void`) para máxima velocidade de execução na VM do GDScript e facilidade de manutenção.
