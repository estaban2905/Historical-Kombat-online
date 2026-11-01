# Perfiles de los luchadores

Cada luchador tiene su propio ritmo de golpes normales según su arma y personalidad, un golpe
**alto** (overhead: solo se bloquea de pie, más lento) o **bajo** (solo se bloquea agachado) y dos
combos propios que se enlazan con cancelaciones. Se define en `PROFILES`, `STYLE_MODS` y `TWEAKS`
de `tools/generate_fighters.py` (y se regenera con `python tools/generate_fighters.py`).

- Los estilos con arma (espada, lanza, hacha) alcanzan más y se recuperan más despacio; los pesados pegan
  fuerte y lento; los veloces al revés; los eruditos tienen golpes normales débiles y viven de sus poderes.
- Los golpes **altos** quedan fuera de los combos (son demasiado lentos para enlazarlos): sirven para sorprender
  a quien bloquea agachado. Los **bajos** sí pueden abrir combos.
- Frames: `startup/recuperación` de puño débil, puño fuerte, patada débil y patada fuerte.
- Si un combo termina en un especial, hay que tener su energía; el bono se cobra aunque sea un proyectil o poder.

| Luchador | Estilo | Golpe propio | Frames (PD / PF / KD / KF) | Combos |
|---|---|---|---|---|
| DONALD TRUMP | pesado | ALTO: Patada Presidencial (patada fuerte) | 5/8  11/17  6/10  17/19 | TUIT (puño débil › patada débil › puño fuerte, +3.5); DECRETO (puño débil › patada débil › puño fuerte, +6.0) |
| KIM JONG-UN | pesado | ALTO: Patada de Desfile (patada fuerte) | 6/9  12/18  7/11  18/20 | PARADA (patada débil › puño débil › puño fuerte, +4.0); LANZAMIENTO (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| VLADIMIR PUTIN | peleador | BAJO: Barrido de Judo (patada débil) | 3/5  8/13  6/8  11/17 | LLAVE (patada débil › puño débil › puño fuerte, +3.5); IPPON (puño débil › patada débil › puño fuerte › patada fuerte, +6.0) |
| XI JINPING | pesado | ALTO: Patada del Dragón (patada fuerte) | 6/9  12/18  7/11  18/20 | ARMONÍA (patada débil › puño débil › puño fuerte, +4.0); GRAN MURALLA (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| NICOLÁS MADURO | peleador | BAJO: Patada de Salsa (patada débil) | 4/7  9/15  7/9  12/18 | SALSA (patada débil › puño débil › puño fuerte, +3.0); CUMBIA (puño débil › patada débil › puño fuerte › patada fuerte, +6.0) |
| ADOLF HITLER | veloz | BAJO: Barrido Veloz (patada débil) | 3/5  6/12  4/6  9/14 | RÁFAGA (puño débil › patada débil › puño fuerte, +3.0); RELÁMPAGO (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| JOSEPH STALIN | pesado | ALTO: Mazazo de Acero (puño fuerte) | 6/9  17/19  7/11  14/20 | QUINQUENAL (patada débil › puño débil › patada fuerte, +4.5); PURGA (patada débil › puño débil › patada fuerte › esp. 2, +8.0) |
| BENITO MUSSOLINI | peleador | ALTO: Patada de Balcón (patada fuerte) | 3/6  8/14  5/8  15/17 | DISCURSO (patada débil › puño débil › puño fuerte, +3.5); MARCHA (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| SADDAM HUSSEIN | peleador | BAJO: Barrido del Desierto (patada débil) | 3/6  8/14  6/8  11/17 | DUNA (patada débil › puño débil › puño fuerte, +3.0); TORMENTA (puño débil › patada débil › puño fuerte › esp. 1, +6.5) |
| OSAMA BIN LADEN | veloz | BAJO: Patada Sombra (patada débil) | 3/5  6/12  4/6  9/14 | SOMBRA (puño débil › patada débil › patada fuerte, +3.0); EMBOSCADA (patada débil › puño débil › puño fuerte › esp. 2, +7.0) |
| NAPOLEÓN BONAPARTE | espada / sable | ALTO: Sablazo Imperial (puño fuerte) | 4/8  13/16  5/8  12/18 | ESTRATEGIA (puño débil › patada fuerte › esp. 1, +4.0); CAMPAÑA (patada débil › puño débil › patada fuerte, +6.0) |
| GENGIS KAN | espada / sable | ALTO: Tajo de Jinete (patada fuerte) | 3/7  8/15  4/7  15/17 | HORDA (patada débil › puño débil › puño fuerte, +4.0); GALOPE (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| FIDEL CASTRO | peleador | BAJO: Patada Guerrillera (patada débil) | 3/7  9/15  6/8  11/17 | SIERRA (patada débil › puño débil › puño fuerte, +3.0); REVOLUCIÓN (puño débil › patada débil › puño fuerte › patada fuerte, +6.0) |
| CLEOPATRA | veloz | BAJO: Barrido de Sandalia (patada débil) | 3/5  6/12  4/6  9/13 | NILO (puño débil › patada débil › patada fuerte, +3.0); ÁSPID (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| JULIO CÉSAR | espada / sable | ALTO: Gladio Descendente (puño fuerte) | 4/7  13/16  5/8  12/18 | VENI VIDI (patada débil › puño débil › patada fuerte, +4.0); VICI (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| ALEJANDRO MAGNO | espada / sable | ALTO: Tajo Macedonio (patada fuerte) | 3/7  8/15  4/7  14/17 | FALANGE (patada débil › puño débil › puño fuerte, +4.0); GAUGAMELA (patada débil › puño débil › puño fuerte › esp. 2, +7.0) |
| REINA ISABEL II | controlador | ALTO: Golpe de Cetro (puño fuerte) | 5/8  13/15  6/9  12/18 | PROTOCOLO (patada débil › puño débil › patada fuerte, +3.5); CORONACIÓN (patada débil › puño débil › patada fuerte › esp. 1, +6.5) |
| ABRAHAM LINCOLN | hacha / arma pesada | ALTO: Hachazo Presidencial (puño fuerte) | 6/9  16/18  7/10  14/19 | EMANCIPACIÓN (patada débil › puño débil › patada fuerte, +4.0); GETTYSBURG (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| JESÚS DE NAZARET | místico (bastón) | ALTO: Vara del Pastor (puño fuerte) | 4/7  13/15  5/8  11/17 | PARÁBOLA (patada débil › puño débil › patada fuerte, +3.0); MILAGRO (patada débil › puño débil › patada fuerte › esp. 2, +7.0) |
| BUDA | místico (bastón) | BAJO: Patada del Loto (patada débil) | 5/8  10/16  7/9  12/18 | LOTO (patada débil › puño débil › puño fuerte, +3.0); NIRVANA (puño débil › patada débil › puño fuerte › esp. 1, +7.0) |
| PAPA FRANCISCO | controlador | ALTO: Golpe de Báculo (puño fuerte) | 4/8  12/14  5/8  11/17 | BENDICIÓN (patada débil › puño débil › patada fuerte, +3.0); ÁNGELUS (patada débil › puño débil › patada fuerte › esp. 1, +6.5) |
| GRIGORI RASPUTÍN | místico (bastón) | ALTO: Báculo Hipnótico (puño fuerte) | 5/8  14/16  6/9  12/18 | HIPNOSIS (patada débil › puño débil › patada fuerte, +4.0); MALDICIÓN (patada débil › puño débil › patada fuerte › esp. 2, +7.0) |
| PABLO ESCOBAR | peleador | BAJO: Patada de Sicario (patada débil) | 3/6  8/14  6/8  11/17 | PLATA (patada débil › puño débil › puño fuerte, +3.0); PLOMO (puño débil › patada débil › puño fuerte › esp. 1, +6.5) |
| ALBERT EINSTEIN | erudito | BAJO: Patada Relativa (patada débil) | 4/8  8/16  6/9  11/18 | ECUACIÓN (puño débil › puño fuerte › patada fuerte, +3.0); RELATIVIDAD (patada débil › puño débil › puño fuerte › esp. 1, +6.5) |
| NIKOLA TESLA | erudito | ALTO: Descarga en Arco (puño fuerte) | 4/8  12/16  5/9  11/18 | ARCO (patada débil › puño débil › patada fuerte, +3.5); CORRIENTE (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| LEONARDO DA VINCI | erudito | ALTO: Trazo Descendente (puño fuerte) | 3/7  12/15  4/8  10/17 | BOCETO (patada débil › puño débil › patada fuerte, +3.0); OBRA MAESTRA (patada débil › puño débil › patada fuerte › esp. 2, +7.0) |
| MARIE CURIE | erudito | BAJO: Barrido Radiante (patada débil) | 4/8  8/16  6/9  12/19 | ISÓTOPO (patada débil › puño débil › puño fuerte, +3.0); RADIACIÓN (puño débil › patada débil › puño fuerte › esp. 1, +6.5) |
| GALILEO GALILEI | erudito | ALTO: Golpe de Telescopio (puño fuerte) | 4/8  12/16  5/9  11/18 | ÓRBITA (patada débil › puño débil › patada fuerte, +3.0); EPPUR SI MUOVE (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| CHARLES DARWIN | erudito | BAJO: Patada Primate (patada débil) | 5/9  9/17  7/10  12/19 | ADAPTACIÓN (patada débil › puño débil › puño fuerte, +3.0); SELECCIÓN (puño débil › patada débil › puño fuerte › esp. 1, +6.5) |
| CRISTÓBAL COLÓN | espada / sable | ALTO: Tajo de Capitán (patada fuerte) | 3/7  8/16  4/8  15/17 | RUMBO (patada débil › puño débil › puño fuerte, +3.5); TIERRA A LA VISTA (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| JANEQUEO | lanza / bastón largo | BAJO: Lanzada Baja (patada débil) | 3/7  8/15  5/7  11/17 | WEICHAN (puño débil › puño fuerte › patada fuerte, +4.0); NEWEN (patada débil › puño débil › puño fuerte › esp. 1, +7.0) |
| LAUTARO | lanza / bastón largo | BAJO: Lanzada Rasante (patada débil) | 3/7  8/15  5/7  11/17 | TOQUI (puño débil › puño fuerte › patada fuerte, +4.0); MALÓN (patada débil › puño débil › puño fuerte › esp. 2, +7.0) |
| PACHACÚTEC | pesado | ALTO: Cetro Solar (puño fuerte) | 6/9  16/18  7/11  14/20 | INTI (patada débil › puño débil › patada fuerte, +4.0); TAHUANTINSUYO (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| IVÁN EL TERRIBLE | pesado | ALTO: Bastón de Hierro (puño fuerte) | 6/9  15/18  7/11  14/20 | ZAR (patada débil › puño débil › patada fuerte, +4.5); TERROR (patada débil › puño débil › patada fuerte › esp. 2, +8.0) |
| BOUDICA | lanza / bastón largo | ALTO: Lanza Descendente (puño fuerte) | 5/9  14/17  6/9  13/19 | ICENOS (patada débil › puño débil › patada fuerte, +4.0); REBELIÓN (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| JUANA DE ARCO | espada / sable | ALTO: Tajo Sagrado (puño fuerte) | 4/8  13/16  5/8  12/18 | FE (patada débil › puño débil › patada fuerte, +3.5); ORLEANS (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
| AUGUSTO PINOCHET | peleador | BAJO: Patada de Cuartel (patada débil) | 3/6  9/14  6/8  11/17 | MANDO (patada débil › puño débil › puño fuerte, +3.5); TOQUE (puño débil › patada débil › puño fuerte › esp. 1, +6.5) |
| SALVADOR ALLENDE | controlador | ALTO: Golpe de Tribuna (puño fuerte) | 4/7  12/13  5/8  11/17 | DISCURSO (patada débil › puño débil › patada fuerte, +3.5); PUEBLO (patada débil › puño débil › patada fuerte › esp. 1, +6.5) |
| ARTURO PRAT | espada / sable | ALTO: Sablazo de Abordaje (puño fuerte) | 4/8  13/17  5/8  12/19 | ABORDAJE (patada débil › puño débil › patada fuerte, +4.0); ESMERALDA (patada débil › puño débil › patada fuerte › esp. 1, +7.0) |
