# horror-indie
Joc horror/comedie 3D, story-driven (~30 min), cu grafică de PS2. Făcut în Godot 4.7.

## Cum îl pornești
Deschide Godot → Import → alege `project.godot` din folderul ăsta → F5.

Controale: WASD = mers, Shift = fugă, mouse = privit, E = interacționezi / treci la replica următoare, F = lanterna, Esc = eliberează mouse-ul.

## Ce e unde
- `shaders/ps2.gdshader` — materialul 3D de PS2 (tremurul vârfurilor, texturi pixelate). Pune-l pe orice obiect nou.
- `shaders/ps2_ecran.gdshader` + `scenes/efect_ps2.tscn` — filtrul peste tot ecranul (puține culori, dithering, vignetă, grăunte). Pornit automat (autoload `EfectPS2`).
- Rezoluția jocului e 480×270, mărită pixelat la fereastră (Project Settings → Display → Window).
- `scripts/jucator.gd` + `scenes/jucator.tscn` — jucătorul la persoana întâi.
- `scripts/interactabil.gd` — pune-l pe un StaticBody3D, scrie `indiciu` și `replici` în Inspector și gata, se poate examina.
- `scripts/dialog.gd` — caseta de text de jos (autoload `Dialog`): `Dialog.spune(["replica 1", "replica 2"])`.
- `scripts/lumina_palpaie.gd` — bec care pâlpâie.
- `scenes/nivel_test.tscn` — camera de test (cameră + hol, bilet, manechin).
