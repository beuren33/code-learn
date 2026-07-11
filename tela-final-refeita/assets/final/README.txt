ASSETS DA SEQUÊNCIA FINAL — EndingSequence.tscn / ending_sequence.gd
====================================================================
Formato: HORIZONTAL 16:9 (base 1920x1080).

ARQUIVOS USADOS PELA CENA:
    final_video.ogv    <- vídeo final em tela cheia (Theora, 1920x1080)
    credits_scene.png  <- imagem COMPLETA da cena de créditos (fundo sci-fi
                          COM o personagem já embutido à esquerda). É o fundo
                          da CreditsLayer. NÃO existe sprite de personagem
                          separado — o personagem faz parte desta imagem.
    ending_music.ogg   <- (OPCIONAL) trilha/ambientação final. Ainda NÃO existe.
                          Basta colocar um arquivo com esse nome aqui que a
                          cena toca automaticamente (com fade-in/out).

SOBRE O VÍDEO (barras pretas):
    O mp4 original ("Video Project 2.mp4") tinha ~106px de barra preta em
    cada lateral, embutidas no próprio arquivo. Na conversão para .ogv essas
    barras foram RECORTADAS e o vídeo foi reescalado em modo "cover" para
    preencher 1920x1080 sem distorcer (corta ~67px topo/base). Resultado:
    tela cheia, sem barras. O Godot só toca vídeo em .ogv (mp4 não funciona).

COMO A CENA CARREGA:
    O script (ending_sequence.gd) carrega estes arquivos EM TEMPO DE EXECUÇÃO,
    com verificação de existência. Se algum faltar, a cena NÃO quebra: usa um
    placeholder seguro (fundo escuro / sem vídeo / sem música). Por isso, no
    editor o nó CreditsBackground aparece vazio — a textura entra ao dar Play.
    (Se quiser ver no editor, arraste credits_scene.png para o campo "Texture".)

COMO TROCAR UM ASSET:
    Substitua o arquivo por outro com o MESMO nome, ou troque o caminho nas
    constantes VIDEO_PATH / BG_PATH / MUSIC_PATH no topo do script.
    Para trocar o vídeo por outro mp4, converta para .ogv antes.
