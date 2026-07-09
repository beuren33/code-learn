# Code Learn

Jogo educacional 2D para ensino de robótica (mecânica, eletrônica e programação), feito em Godot 4, alinhado ao programa Robótica Paraná (SEED-PR). Projeto acadêmico da UTFPR — Santa Helena, disciplina de Projeto Integrador I.

Documento de modelagem completo (narrativa, requisitos funcionais/não funcionais, casos de uso): ver `Doc_requisitos_CodeLearn` (versão vigente 3.0).

## Como rodar

1. Abrir a pasta do projeto no **Godot 4.6**.
2. Cena principal: `scenes/ui/Menu/MainMenu.tscn` (já configurada como `run/main_scene`).
3. Rodar com F5. Fluxo: **MainMenu** → START (`node_2d.tscn`, níveis), CREDITS ou OPTIONS.

Plataforma-alvo é Android (RNF-001); rodar direto no editor Desktop funciona igual para desenvolvimento/teste.

## Arquitetura

O jogo é conduzido por cenas (padrão Godot), sem banco de dados nem servidor:

- **`scripts/main_menu.gd`** — tela inicial (Start / Credits / Options).
- **`scenes/ui/levels/node_2d.tscn`** + **`characters/storyboard_director.gd`** — movimento automático do personagem pelos cenários LDtk, parando nos pontos de desafio.
- **`characters/gerenciador_jogo.gd`** — liga o storyboard aos quizzes (`interface_quiz.tscn`), minigames (`minigames/drone`, `minigames/led`, `minigames/fios`) e combate (`characters/combate/`), na ordem da narrativa.
- **`sistema_quiz/cenas/interface_quiz.gd`** — cena de quiz reaproveitada tanto nos níveis quanto no combate (`combate.gd`).
- **`scripts/Audio_Manager.gd`** (autoload `AudioManager`) — música e efeitos sonoros, com volume/mute persistido em `user://audio_config.cfg`.
- **`scripts/Transicao.gd`** (autoload `Transicao`) — troca de cena com fade, usado nas transições reais (menu → nível/créditos/opções).
- **`scenes/ui/Menu/OptionsMenu.tscn`** — tela de opções de áudio (volume/mudo), acessível pelo menu inicial.

## Removido do projeto (fora do escopo atual, v3.0 do documento)

O histórico do repositório carregava um backend inteiro em SQLite (addon `godot-sqlite`, `Save_Manager.gd`, `Game_Manager.gd`, `data/missions.json`, `data/items.json`, `data/badges.json`) de uma versão anterior do escopo (v1.0/v2.0), que previa banco de dados, loja de itens, avatar customizável, dashboard e conquistas. O documento de requisitos vigente (v3.0) **retirou** todas essas funcionalidades do escopo e definiu que a persistência deve usar só o sistema de arquivos da própria engine — por isso esse backend foi removido nesta correção, junto com o autoload correspondente. Se a equipe decidir reintroduzir loja/avatar/conquistas como "melhoria futura" (sugestão do próprio documento, seção 12), comece do zero com persistência via `FileAccess`/`ConfigFile`, não SQLite.

## Limitações conhecidas

- **RF-008/RF-009 (salvar e retomar progresso) não estão implementados.** Cada execução do jogo começa do zero em `node_2d.tscn`; não há gravação de progresso nem retomada ao reabrir. É um requisito Crítico/Alto do documento ainda pendente.
- **Sem trilha sonora/efeitos sonoros reais ainda.** `assets/audio/` está vazio; `Audio_Manager` está com a estrutura pronta (autoload, volume, mute) mas silenciosa até a equipe adicionar os arquivos `.ogg` em `assets/audio/music/` e `assets/audio/sfx/` (chaves esperadas em `scripts/Audio_Manager.gd`).
- Sem pausa ou retorno ao menu durante a fase (comportamento intencional, ver seção 13.4 do documento).
- Badges/conquistas, loja e sistema de pontuação: fora de escopo (ver seção acima).

## Versão do Godot

O projeto trava em **Godot 4.6** (`config/features` em `project.godot`). Ao abrir com outra versão, o editor reescreve esse valor — mantenha 4.6 para evitar diffs de versão a cada commit.
