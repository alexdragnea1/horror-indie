# CLAUDE.md

Ghid pentru Claude (și oricine lucrează la proiect).

## Proiectul
Joc **horror/comedie 3D la persoana întâi**, story-driven, de **~30 de minute**, cu grafică în stil **PS2**: rezoluție mică, pixelată, ceață, lumină slabă. Godot **4.7**, renderer Forward+, GDScript.

Owner-ul e **începător**: îi răspunzi **în română** și îl îndrumi pas cu pas. Explici pe scurt ce s-a schimbat și ce „butoane” (variabile `@export`, parametri de shader) poate regla singur din Inspector.

## Reguli de cod
- GDScript cu **TAB-uri**, tipuri explicite (`var x: bool = ...`, nu `:=`, când valoarea vine din ceva netipat, ca `event`, altfel e parse error).
- Numele (variabile, funcții, noduri, fișiere) și comentariile sunt **în română, fără diacritice în identificatori**. Comentariile pot avea diacritice.
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
| `scripts/personaj.gd` | `class_name Personaj` (extinde `Interactabil`): la E se întoarce spre jucător (modelele privesc spre **+Z**) și spune replicile; capul (`cap`) urmărește jucătorul; respiră (scale Y pe `Model`). |
| `scripts/frigider.gd` | Extinde `Interactabil`: deschide `usa` (tween pe rotation.y), aprinde `lumina`, spune replicile, închide după `Dialog.terminat`. |
| `scenes/bec.tscn`, `scenes/frigider.tscn`, `scenes/mama.tscn` | Modelele gata de pus în nivel (fiecare cu `Model` = `.glb` + `ModelPS2`). |
| `tools/blender/modele.py` + `unelte.py` | **Sursa modelelor** `models/*.glb`. Folderul `tools/` are `.gdignore`. |
| `scripts/stare.gd` | Autoload `Stare` (CanvasLayer 6): inventar (`adauga_obiect/are_obiect/scoate_obiect`) + marcaje de poveste (`marcheaza/e_marcat`), mesaj „Ai luat: …”, lista pe **Tab** (acțiunea `inventar`). |
| `scripts/obiect_luat.gd` | `class_name ObiectLuat` (extinde `Interactabil`): `id_obiect`, `nume_obiect`; la E intră în inventar și dispare. |
| `scripts/usa.gd` | `class_name Usa` (extinde `Interactabil`): originea nodului = balamaua; `cheie_necesara`, `replici_incuiata`, `unghi_deschidere`. **Scris, încă nefolosit în nivel.** |
| `scripts/declansator.gd` | `class_name Declansator` (Area3D): când intră un corp din grupul `jucator` → replici, `marcaj`, `de_aratat`/`de_ascuns`. **Scris, încă nefolosit în nivel.** |
| `scenes/nivel_test.tscn` | Prima scenă, **casa** (camera e bucătăria): cameră + hol din CSG (`use_collision`), bec care pâlpâie, frigider, **Mom** (primul dialog al poveștii). Pereții și podeaua au texturile adevărate din `textures/`; masa are încă `NoiseTexture2D`. |

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

## Rulare și verificare
- Godot: `C:\Users\gheorghe dracu\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Import (după fișiere sau imagini noi): `"<godot>" --headless --path . --import`
- **Verificare vizuală:** o scenă de test temporară care instanțiază nivelul, așteaptă ~1 s și salvează `get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://poza.png"))`. Rulezi **cu fereastră** (headless randează negru). Pozele ies în `%APPDATA%\Godot\app_userdata\Horror Indie\`. Interacțiunea se simulează cu `InputEventAction` + `Input.parse_input_event`. Șterge scena de test după (și `.uid`-ul ei).

## Plan (roadmap)
1. ✅ Baza: aspect PS2, jucător, dialog, obiecte interactive.
2. ⏳ **Povestea**: premisa, personajele, 4–6 capitole de ~5 min (owner-ul o scrie, Claude ajută).
3. Uși, chei, inventar mic, triggere de poveste.
4. Niveluri: întâi blockout, apoi modele low-poly (PSX assets de pe itch.io / Kenney) cu `ps2.gdshader`.
5. Sunet: ambianță, pași, jumpscare-uri.
6. Monstrul/urmăritorul, jumpscare-uri, momentele de comedie.
7. Meniu, salvare, final, credite.
8. Playtest, build.

## Texturi
Surse recomandate: pachete „PSX textures” de pe itch.io, ambientCG / Poly Haven (CC0, micșorate la 128×128), poze proprii. **Verifică licența** (CC0 sau uz comercial permis), ca jocul să poată merge pe Steam. Se pun în `textures/` și se trag în parametrul `textura` al materialului, cu `culoare` albă.

Owner-ul aduce texturi mari (4096 px). Le micșorăm la **256×256 PNG** cu ffmpeg (`-vf scale=256:256:flags=area`) și le dăm nume în română (`perete_casa.png`, `podea_casa.png`). Originalele merg în `textures/originale/`, care are `.gdignore` (Godot nu le importă) și e în `.gitignore`. ffmpeg: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\ffmpeg-*\bin\ffmpeg.exe` (nu e în PATH).

Modele: de preferat `.glb`. Un `.obj` vine cu un `.mtl` (materialul) lângă el; fără el Godot dă eroare la import.
