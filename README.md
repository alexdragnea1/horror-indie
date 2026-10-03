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
| Tab | deschide / închide inventarul (5 sloturi + sarcina curentă) |
| Esc | închide inventarul / eliberează mouse-ul |

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
- `scripts/personaj.gd` – personaj cu care vorbești (ex. Mom, baba de pe bancă). În `replici` scrii `NUME: text`, iar numele apare deasupra casetei. Debifează `se_intoarce` la cei care stau jos: atunci se uită după tine doar cu capul.
- `scenes/mama.tscn`, `scenes/frigider.tscn`, `scenes/bec.tscn` – Mom, frigiderul (se deschide) și becul care pâlpâie și se leagănă. Le tragi în nivel din FileSystem.
- `scenes/dormitor.tscn` – camera ta, de vrăjitoare: pat, ceaun, raft cu cărți de vrăji, covor cu pentagramă și lumânări, glob de cristal, mătură. Mută lucrurile din ea cu mouse-ul în editor.
- `scripts/meniu_nume.gd` – meniul în care îți scrii numele (apare prima dată când încerci să ieși din cameră). Textele lui se schimbă din `@export`-urile de sus.
- `scripts/inventar.gd` – fereastra de inventar (Tab). `Stare.seteaza_sarcina("...")` schimbă sarcina curentă și o arată sus 5 secunde.
- `scenes/usa_intrare.tscn` – ușa de la intrare. În Inspector, la `Usa`: `marcaj_necesar` = ce trebuie să se fi întâmplat ca să se deschidă (acum `a_vorbit_cu_mom`), `replici_fara_marcaj` = ce zici până atunci.
- `scenes/nivel_test.tscn` – prima scenă, casa: camera ta, holul cu ușa de la intrare, bucătăria cu Mom, frigiderul și becurile. Începi în camera ta.
- `scenes/afara_bloc.tscn` – afară, în fața blocului tău (BL. M7, scara B), noaptea: grădină cu copaci de toamnă, frunze care cad, ceață, felinare care pâlpâie, o babă pe bancă (vorbește cu tine despre mama ta), tomberonul, bătătorul cu covor, mașina vecinului. Ajungi aici când deschizi ușa de la intrare, printr-un ecran negru în care auzi cum cobori scările și ușa blocului trântindu-se.
- `scripts/tranzitie.gd` – trecerea dintre scene prin ecran negru: `Tranzitie.mergi_la("res://scenes/...tscn", "Numele locului", [sunete])`. La orice ușă (`usa.gd`) completezi în Inspector, la „Iesire din scena”: `scena_urmatoare`, `titlu_locatie` și `sunete_tranzitie`.
- `scripts/acustica.gd` – pune câte unul în fiecare nivel: cât ecou au sunetele acolo (în casă puțin, afară aproape deloc).

## Modele 3D
Modelele din `models/*.glb` sunt făcute în Blender **din cod**: `tools/blender/modele.py` (casa), `dormitor.py` (camera ta) și `afara.py` (blocul, copacii și curtea). Toate culorile vin din paleta ta, `textures/paleta culori.hex`, și se scriu ca `p("7b383a")`. O culoare din afara paletei oprește scriptul cu o eroare. Ca să schimbi o culoare sau o mărime, editezi acolo și rulezi:
```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools/blender/modele.py
```
Godot reimportă singur modelele când revii în editor.

## Sunet
Pachetul tău de sunete stă în `Sound/Soundpack` (Godot și git îl ignoră). Sunetele alese de acolo, curățate și transformate în `.ogg`, sunt în `sunete/`. Le refaci cu:
```
bash tools/sunete.sh
```
Ce se aude acum:
- **pași** pe podeaua de lemn (uneori scârțâie), mai moi pe covorul cu pentagramă, pe beton afară și foșnind prin frunze uscate în grădină; clic la lanternă;
- **bâzâit** la becuri, care tace când becul se stinge; **frigiderul** bâzâie, iar la deschidere și închidere se aud garnitura și borcanele;
- **ușa camerei** scârțâie lung când o deschizi; **ceaunul** fierbe și gâlgâie din când în când; **ceasul** din bucătărie ticăie (e oprit la 11:55);
- **vânt** afară, iar din când în când un scârțâit sau un ciocănit din pereți, și foarte rar ceva... mai rău; în fața blocului, uneori, cineva fluieră departe în întuneric sau se aude o tablă lovită;
- **tranziția** spre afară: pașii pe scara blocului, cu ecou, și ușa metalică a scării trântită;
- în dialog, un bip la câteva litere („vocea”): Mom are vocea groasă, tu subțire;
- la meniul cu numele: clicuri și o lovitură dramatică la „Are you sure your name is little bitch?”.

Volumele se reglează din Inspector, la fiecare nod de sunet (`volume_db`), sau pe canale, în panoul **Audio** de jos (`Efecte`, `Ambianta`, `Interfata`). ⚠️ Pachetul e de pe Guru3D: verifică licența înainte de Steam.

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
5. ⏳ Sunet (✅ ambianță, pași, obiecte, interfață; urmează jumpscare-uri și muzică)
6. Monstrul, jumpscare-uri, comedie
7. Meniu, salvare, final
8. Playtest și build
