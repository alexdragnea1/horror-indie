# horror-indie

Joc **horror/comedie 3D**, story-driven (~30 de minute), cu grafică în stil **PS2**: pixelat, ceață, lumină slabă, texturi care tremură. Făcut în **Godot 4.7**. Jocul e în **engleză** (codul și comentariile sunt în română).

## Cum îl pornești
1. Deschide Godot 4.7 → **Import** → alege `project.godot` din folderul ăsta.
2. Apasă **F5**.

## Controale
| Tastă | Ce face |
|---|---|
| WASD | mers |
| Shift | fugă |
| Mouse | privit |
| E / click | interacționezi / treci la replica următoare |
| F | lanterna |
| Tab (ține apăsat) | inventarul |
| Esc | eliberează mouse-ul |

## Ce e unde
- `shaders/ps2.gdshader` – materialul 3D de PS2 (tremurul vârfurilor, texturi pixelate). Pune-l pe orice obiect nou. Pentru pereți și podele bifează `uv_din_lume`.
- `shaders/ps2_ecran.gdshader` + `scenes/efect_ps2.tscn` – filtrul de peste tot ecranul (puține culori, dithering, vignetă, grăunte). Pornește automat.
- Rezoluția jocului e 480×270, mărită pixelat la fereastră (Project Settings → Display → Window).
- `scripts/jucator.gd` + `scenes/jucator.tscn` – jucătorul la persoana întâi.
- `scripts/interactabil.gd` – pune-l pe un StaticBody3D, completezi `indiciu` și `replici` în Inspector și obiectul se poate examina.
- `scripts/dialog.gd` – caseta de text de jos: `Dialog.spune(["replica 1", "replica 2"])`.
- `scripts/lumina_palpaie.gd` – bec care pâlpâie.
- `scripts/stare.gd` – inventarul și „ce s-a întâmplat” în poveste (autoload `Stare`).
- `scripts/obiect_luat.gd`, `scripts/usa.gd`, `scripts/declansator.gd` – obiect pe care îl iei, ușă (și încuiată, cu cheie), zonă care pornește o scenă când intri în ea.
- `scripts/personaj.gd` – personaj cu care vorbești (ex. Mom). În `replici` scrii `NUME: text`, iar numele apare deasupra casetei.
- `scenes/mama.tscn`, `scenes/frigider.tscn`, `scenes/bec.tscn` – Mom, frigiderul (se deschide) și becul care pâlpâie și se leagănă. Le tragi în nivel din FileSystem.
- `scenes/nivel_test.tscn` – prima scenă, casa: bucătăria cu Mom, frigiderul și becul, plus holul.

## Modele 3D
Modelele din `models/*.glb` sunt făcute în Blender **din cod**: `tools/blender/modele.py`. Toate culorile vin din paleta ta, `textures/paleta culori.hex`, și se scriu ca `p("7b383a")`. O culoare din afara paletei oprește scriptul cu o eroare. Ca să schimbi o culoare sau o mărime, editezi acolo și rulezi:
```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools/blender/modele.py
```
Godot reimportă singur modelele când revii în editor.

## Texturi
Pereții și podeaua casei au texturi adevărate (`textures/perete_casa.png`, `textures/podea_casa.png`, micșorate la 256×256; originalele mari stau în `textures/originale/`, ignorate de Godot și de git). Restul obiectelor au încă texturi din „zgomot”. De unde iei altele:
- caută **„PSX textures”** pe [itch.io](https://itch.io/game-assets/tag-psx);
- [ambientCG](https://ambientcg.com) și [Poly Haven](https://polyhaven.com/textures) (gratuite, CC0);
- pozele tale, tăiate pătrat și micșorate la 128×128.

Pui PNG-ul în `textures/`, apoi dai click pe obiect → **Material** → tragi PNG-ul în **Textura** și faci **Culoare** albă. ⚠️ Verifică licența (CC0 sau uz comercial permis).

## Plan
1. ✅ Baza: aspect PS2, jucător, dialog, obiecte interactive
2. ⏳ Povestea (premisă, personaje, 4–6 capitole de ~5 min)
3. Uși, chei, inventar, triggere de poveste
4. Niveluri: blockout, apoi modele low-poly
5. Sunet
6. Monstrul, jumpscare-uri, comedie
7. Meniu, salvare, final
8. Playtest și build
