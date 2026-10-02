# horror-indie

Joc **horror/comedie 3D**, story-driven (~30 de minute), cu grafică în stil **PS2**: pixelat, ceață, lumină slabă, texturi care tremură. Făcut în **Godot 4.7**.

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
| Esc | eliberează mouse-ul |

## Ce e unde
- `shaders/ps2.gdshader` – materialul 3D de PS2 (tremurul vârfurilor, texturi pixelate). Pune-l pe orice obiect nou. Pentru pereți și podele bifează `uv_din_lume`.
- `shaders/ps2_ecran.gdshader` + `scenes/efect_ps2.tscn` – filtrul de peste tot ecranul (puține culori, dithering, vignetă, grăunte). Pornește automat.
- Rezoluția jocului e 480×270, mărită pixelat la fereastră (Project Settings → Display → Window).
- `scripts/jucator.gd` + `scenes/jucator.tscn` – jucătorul la persoana întâi.
- `scripts/interactabil.gd` – pune-l pe un StaticBody3D, completezi `indiciu` și `replici` în Inspector și obiectul se poate examina.
- `scripts/dialog.gd` – caseta de text de jos: `Dialog.spune(["replica 1", "replica 2"])`.
- `scripts/lumina_palpaie.gd` – bec care pâlpâie.
- `scenes/nivel_test.tscn` – camera de test (cameră + hol, bilet, manechin).

## Texturi
Acum texturile sunt generate din „zgomot” (`NoiseTexture2D`), doar ca înlocuitori. Pentru texturi adevărate:
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
