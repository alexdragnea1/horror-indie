# CLAUDE.md

Ghid pentru Claude (și oricine lucrează la proiect).

## Proiectul
Joc **horror/comedie 3D la persoana întâi**, story-driven, de **~30 de minute**, cu grafică în stil **PS2**: rezoluție mică, pixelată, ceață, lumină slabă. Godot **4.7**, renderer Forward+, GDScript.

Owner-ul e **începător**: îi răspunzi **în română** și îl îndrumi pas cu pas. Explici pe scurt ce s-a schimbat și ce „butoane” (variabile `@export`, parametri de shader) poate regla singur din Inspector.

## Reguli de cod
- GDScript cu **TAB-uri**, tipuri explicite (`var x: bool = ...`, nu `:=`, când valoarea vine din ceva netipat, ca `event`, altfel e parse error).
- Numele (variabile, funcții, noduri, fișiere) și comentariile sunt **în română, fără diacritice în identificatori**. Comentariile pot avea diacritice.
- **Jocul e în engleză**: tot textul pe care îl vede jucătorul (replici, indicii „[E] …”, inventar, mesaje) se scrie în **engleză**. Codul (identificatori, comentarii) rămâne în română.
- Ce trebuie să poată regla owner-ul se face `@export`, cu un comentariu `##` deasupra.
- Commit-urile sunt în română, direct pe `main`. **Push doar când owner-ul cere explicit.**

## Arhitectura
| Fișier | Rol |
|---|---|
| `project.godot` | Viewport 480×270, stretch `viewport` (mărire pixelată), fereastră 1440×810, filtru nearest. Acțiuni: `inainte/inapoi/stanga/dreapta/alearga/interact/lanterna`. |
| `shaders/ps2.gdshader` | Materialul pentru **orice** obiect 3D: textură nearest **cu mipmap-uri** (fără ele podeaua face moiré când te miști). Tremurul vârfurilor (`rezolutie_tremur`) și texturile affine (`deformare_textura`) sunt **oprite implicit (0)**, la cererea owner-ului: pe pereții mari din CSG texturile „fugeau” urât. `uv_din_lume = true` pentru CSG/pereți lungi (altfel textura se întinde); `repetare_uv` = de câte ori pe metru. |
| `shaders/ps2_ecran.gdshader` + `scenes/efect_ps2.tscn` | Post-procesare (autoload `EfectPS2`, CanvasLayer 1): cuantizare culori + dithering Bayer 4×4, vignetă, grăunte. |
| `scripts/dialog.gd` | Autoload `Dialog` (CanvasLayer 10). `Dialog.spune(PackedStringArray)`, `Dialog.activ`, semnal `terminat`. Avansează cu E/click și consumă input-ul. |
| `scripts/interactabil.gd` | `class_name Interactabil` (StaticBody3D): `indiciu`, `replici`, `o_singura_data`, semnal `folosit`. Jucătorul îl găsește cu RayCast-ul. |
| `scripts/jucator.gd` + `scenes/jucator.tscn` | FPS: CharacterBody3D → `Cap` → `Camera3D` → `Lanterna` (SpotLight) + `RazaInteractiune` (2,2 m). HUD (CanvasLayer 5): punct + `Indiciu`. Mouse-ul folosește `screen_relative` (nu `relative`, care e scalat de viewport-ul mic). |
| `scripts/lumina_palpaie.gd` | OmniLight3D care pâlpâie; opțional `sticla` (mesh) care strălucește odată cu lumina, prin `instance uniform stralucire` din `ps2.gdshader`. |
| `scripts/pendul.gd` | Leagănă ușor nodul în jurul originii (becul de pe fir). |
| `scripts/model_ps2.gd` | `class_name ModelPS2`: pus pe rădăcina unui `.glb` instanțiat, dă `material_override` = `shaders/material_model.tres` tuturor mesh-urilor (`umbre = false` la bec). |
| `scripts/personaj.gd` | `class_name Personaj` (extinde `Interactabil`): la E se întoarce spre jucător (modelele privesc spre **+Z**) și spune replicile; capul (`cap`) urmărește jucătorul; respiră (scale Y pe `Model`). După prima conversație: `marcaj_dupa`, `sarcina_noua`, iar data următoare spune `replici_dupa`. Mom: `a_vorbit_cu_mom` → „Meet with the coven.”. |
| `scripts/frigider.gd` | Extinde `Interactabil`: deschide `usa` (tween pe rotation.y), aprinde `lumina`, spune replicile, închide după `Dialog.terminat`. |
| `scenes/bec.tscn`, `scenes/frigider.tscn`, `scenes/mama.tscn` | Modelele gata de pus în nivel (fiecare cu `Model` = `.glb` + `ModelPS2`). |
| `tools/blender/modele.py` + `unelte.py` + `dormitor.py` | **Sursa modelelor** `models/*.glb` (`dormitor.py` = mobila camerei jucătorului, chemat din `modele.py`). Folderul `tools/` are `.gdignore`. |
| `scenes/dormitor.tscn` | **Camera jucătorului** (tema: vrăjitoare), instanțiată în nivel la (3.7, 0, -11.7), coordonatele copiilor sunt relative la centrul camerei. Pat cu pălărie, noptieră cu glob de cristal (`ModelPS2.stralucitoare`), raft cu cărți/poțiuni/craniu, ceaun cu lichid care strălucește (lumină verde cu umbre), covor cu pentagramă + 5 × `lumanare.tscn` pe vârfuri (raza 0,92), mătură, `usa_dormitor.tscn`. Podeaua are fața de sus la y = 0,02, deci obiectele stau la 0,02. |
| `scripts/meniu_nume.gd` | `class_name MeniuNume` (CanvasLayer 20, construit din cod, temă din paletă): nume (LineEdit, max 16) → „Are you sure your name is little bitch?” OK/No → semnal `ales(nume)`. Pune `Stare.meniu_deschis` (jucătorul stă pe loc) și arată/ascunde mouse-ul. |
| `scripts/usa_dormitor.gd` | Extinde `Usa`: prima dată → `MeniuNume`, salvează `Stare.nume_jucator`, marcaj `si_a_ales_numele`, replica „Ok little bitch, go talk to your mother.”, apoi se deschide (+95° în cameră). |
| `scripts/stare.gd` | Autoload `Stare` (CanvasLayer 6): inventar de **5 locuri** (`adauga_obiect` întoarce `false` și zice „Inventory full” dacă e plin; `are_obiect/scoate_obiect`), marcaje de poveste (`marcheaza/e_marcat`), **sarcina curentă** (`seteaza_sarcina(text)` → „Task: …” centrat sus 5 s + cutie muzicală), mesaj „Picked up: …”. **Tab** deschide/închide inventarul (Esc închide), prin `_input` ca să prindă tasta înaintea jucătorului; cât e deschis, `meniu_deschis = true`. |
| `scripts/inventar.gd` | `class_name Inventar` (Control construit din cod): 5 sloturi cu numele obiectului (numerotate) + „CURRENT TASK” în dreapta. `actualizeaza(obiecte, sarcina)`. ⚠️ Label cu autowrap într-un container: **nu** pune `clip_text` (iese înalt de 1 px); folosește `max_lines_visible`. Și un Label întins pe lățime se face cu `set_anchors_and_offsets_preset`, nu cu `set_anchors_preset` (ăla lasă lățimea 0). |
| `scripts/obiect_luat.gd` | `class_name ObiectLuat` (extinde `Interactabil`): `id_obiect`, `nume_obiect`; la E intră în inventar și dispare. |
| `scripts/usa.gd` | `class_name Usa` (extinde `Interactabil`): originea nodului = balamaua; `cheie_necesara`, `replici_incuiata`, `marcaj_necesar` + `replici_fara_marcaj` (blocată până se întâmplă ceva în poveste), `sunet_incuiata`, `unghi_deschidere`. Folosit de `usa_dormitor.gd` și de `scenes/usa_intrare.tscn` (ușa roșie de la capătul holului, deschisă doar după marcajul `a_vorbit_cu_mom`; are o lumină afară). |
| `scripts/declansator.gd` | `class_name Declansator` (Area3D): când intră un corp din grupul `jucator` → replici, `marcaj`, `de_aratat`/`de_ascuns`. **Scris, încă nefolosit în nivel.** |
| `scenes/nivel_test.tscn` | Prima scenă, **casa**: bucătăria (8×8, în origine), holul (spre -Z), camera jucătorului (din hol, pe dreapta, gol de ușă la x = 1,1, z = -11,7) — toate din CSG (`use_collision`; ordinea copiilor contează: întâi exterioarele, apoi golurile, apoi podelele). Bec în bucătărie și pe hol, frigider, **Mom** (primul dialog al poveștii), ușa de la intrare la capătul holului (gol CSG la z = -14,1; balamaua la x = -0,45), iar afară `Curte` (CSGBox separat, 60×60, top la y = 0) — deocamdată doar întuneric și ceață, pădurea urmează. Jucătorul pornește în camera lui. Pereții și podeaua au texturile adevărate din `textures/`; masa are încă `NoiseTexture2D`. |

`Dialog`: o replică de forma `"NUME: text"` (nume de max. 14 caractere, fără `:` sau `"`) afișează numele într-o etichetă deasupra casetei; `NUME_JUCATOR` (`You/Tu/Eu`) e albăstrui, restul roșiatic. Replicile lui Mom sunt în engleză, cum le-a scris owner-ul; nu le traduce și nu le „corecta” (`gaf`, `allat`, `kirkenuinly` sunt intenționate).

## Modele 3D (Blender)
Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. Modelele se fac **din cod** în `tools/blender/modele.py` (cuburi, cilindri, sfere cu helper-ele din `unelte.py`), apoi:
`"<blender>" --background --factory-startup --python tools/blender/modele.py` → `models/*.glb`, apoi `--import` în Godot.
- Fiecare piesă are o culoare în **culorile vârfurilor** (atribut `Col`, exportat `COLOR_0`); `ps2.gdshader` face `ALBEDO = textură × culoare × COLOR`, iar textura din `material_model.tres` dă doar murdăria.
- **Paleta:** `textures/paleta culori.hex` (24 de culori, aleasă de owner). În `modele.py` culorile se scriu **doar** ca `p("7b383a")`; `unelte.py` oprește exportul dacă o piesă are o culoare din afara paletei. Și interfața (dialog, inventar, indiciu, punctul de țintire) și masa folosesc culori din paletă. Excepții: luminile, ceața și texturile owner-ului (pereți, podea).
- Blender: Z în sus, fața modelului spre **-Y** (în Godot devine +Z). Piesele care se mișcă sunt obiecte separate, cu originea în pivot (`uneste(..., origine)`): `UsaFrigider`/`UsaCongelator` (balamaua), `Cap` la Mom (gâtul), `Sticla` la bec.
- Ce iese bine: mobilă, obiecte, personaje rigide stil PS1. Personaje detaliate / animate → modele gata făcute.

Straturi CanvasLayer: 1 = filtrul PS2, 5 = HUD, 6 = inventar (`Stare`), 10 = dialog (HUD-ul și dialogul nu sunt dither-uite).

⚠️ În fișierele `.tscn` scrise de mână, `Transform3D(...)` primește bază pe **rânduri**, nu pe coloane. Pentru o rotație pe Y cu unghiul θ: `Transform3D(cosθ, 0, sinθ, 0, 1, 0, -sinθ, 0, cosθ, x, y, z)`.

## Sunet
- **Pachetul brut** stă în `Sound/Soundpack` (~400 WAV, 87 MB, de pe Guru3D, licența neverificată): are `.gdignore` și e în `.gitignore`. În joc intră **doar** `sunete/*.ogg`, făcute de `bash tools/sunete.sh` (taie liniștea, vârf la -1 dB, mono pentru 3D, bucle fără cusătură prin crossfade coadă→început). Bâzâitul frigiderului și al becului e **sintetizat** acolo (nu există în pachet). După ce rulezi scriptul, buclele (`vant`, `ceaun_fierbe`, `ceas`, `frigider_bazait`, `bec_bazait`) au `loop=true` în `.ogg.import`; un `.ogg` nou nu are și trebuie pus de mână (apoi `--import`).
- **Canale** (`default_bus_layout.tres`): `Efecte` (reverb de cameră mică), `Ambianta` (bucle), `Interfata` (meniu, voce dialog, obiect luat).
- `scripts/sunet.gd` = autoload `Sunet`: `reda(stream, volum_db, variatie, bus, inaltime)` și `reda_la(stream, pozitie, ...)` (3D, `unit_size` 3). Playerele se șterg singure.
- Pașii: `jucator.gd` → un pas la fiecare ciclu de clătinare (`balans_frecventa` 4,2 ⇒ un pas la 1,5 m), suprafața o schimbă `ZonaSuprafata` (`zona_suprafata.gd`, Area3D: covorul din cameră); pe lemn, uneori scârțâit. Lanterna face clic.
- `Dialog`: bip `dialog_voce` la fiecare 4 litere, cu înălțimea din `INALTIME_VOCI` (`MOM` 0,62), jucătorul 1,25, fără nume 0,9.
- `lumina_palpaie.gd` → `bazait` (volumul urmărește lumina, tace când se stinge). `frigider.gd` → bâzâit mai tare cât e deschis, garnitură la deschidere, borcane la închidere. `usa.gd` → `sunet_deschidere` (scârțâit) / `sunet_inchidere` (la capătul închiderii).
- `sunete_aleatorii.gd`: sunete la întâmplare, la pauze aleatorii — gâlgâitul ceaunului (din locul lui), iar în nivel `Sperieturi` (scârțâit/ciocănit, 25–60 s) și `Fantoma` (120–240 s, foarte încet), din jurul jucătorului. `Vant` = ambianța de fundal.
- `scenes/ceas.tscn` + `scripts/ceas.gd`: ceas de perete în bucătărie oprit la **11:55** (aproape de miezul nopții = întâlnirea cu coven-ul); secundarul sare sincron cu tic-tacul din buclă.
- **Verificare audio:** `--write-movie x.avi --fixed-fps 30` înregistrează și sunetul; apoi `ffmpeg` (volumedetect, spectrogramă). Un log cu `Sunet.child_entered_tree` arată ce sunete pornesc și când.

## Rulare și verificare
- Godot: `C:\Users\gheorghe dracu\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Import (după fișiere sau imagini noi): `"<godot>" --headless --path . --import`
- **Verificare vizuală:** o scenă de test temporară care instanțiază nivelul, așteaptă ~1 s și salvează `get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://poza.png"))`. Rulezi **cu fereastră** (headless randează negru). Pozele ies în `%APPDATA%\Godot\app_userdata\Horror Indie\`. Interacțiunea se simulează cu `InputEventAction` + `Input.parse_input_event`. Șterge scena de test după (și `.uid`-ul ei).

## Plan (roadmap)
1. ✅ Baza: aspect PS2, jucător, dialog, obiecte interactive.
2. ⏳ **Povestea**: premisa, personajele, 4–6 capitole de ~5 min (owner-ul o scrie, Claude ajută).
3. Uși, chei, inventar mic, triggere de poveste.
4. Niveluri: întâi blockout, apoi modele low-poly (PSX assets de pe itch.io / Kenney) cu `ps2.gdshader`.
5. ⏳ Sunet: ✅ ambianță, pași, uși, obiecte, interfață, voce dialog; urmează jumpscare-uri și muzică.
6. Monstrul/urmăritorul, jumpscare-uri, momentele de comedie.
7. Meniu, salvare, final, credite.
8. Playtest, build.

## Texturi
Surse recomandate: pachete „PSX textures” de pe itch.io, ambientCG / Poly Haven (CC0, micșorate la 128×128), poze proprii. **Verifică licența** (CC0 sau uz comercial permis), ca jocul să poată merge pe Steam. Se pun în `textures/` și se trag în parametrul `textura` al materialului, cu `culoare` albă.

Owner-ul aduce texturi mari (4096 px). Le micșorăm la **256×256 PNG** cu ffmpeg (`-vf scale=256:256:flags=area`) și le dăm nume în română (`perete_casa.png`, `podea_casa.png`). Originalele merg în `textures/originale/`, care are `.gdignore` (Godot nu le importă) și e în `.gitignore`. ffmpeg: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\ffmpeg-*\bin\ffmpeg.exe` (nu e în PATH).

Modele: de preferat `.glb`. Un `.obj` vine cu un `.mtl` (materialul) lângă el; fără el Godot dă eroare la import.
