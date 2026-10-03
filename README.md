# horror-indie

Joc **horror/comedie 3D**, story-driven (~30 de minute), cu grafică în stil **PS2**: pixelat, ceață, lumină slabă, texturi care tremură. Făcut în **Godot 4.7**. Jocul e în **engleză** (codul și comentariile sunt în română).

## Cum îl pornești
1. Deschide Godot 4.7 → **Import** → alege `project.godot` din folderul ăsta.
2. Apasă **F5**. Pornește meniul principal: Start / Continue, Select Save File (3 fișiere), Settings (ecran complet, volum Music și Effects, taste), Quit.

## Controale
| Tastă | Ce face |
|---|---|
| WASD | mers |
| Shift | fugă |
| Mouse | privit |
| E / click | interacționezi / treci la replica următoare |
| F | lanterna |
| Tab | deschide / închide inventarul (5 sloturi + sarcina curentă) |
| Esc | închide inventarul / eliberează mouse-ul / în meniul principal: înapoi |
| F11 | ecran complet (merge oriunde) |

## Povestea până acum
1. Te trezești în camera ta de vrăjitoare. Când încerci să ieși, îți alegi numele... și jocul te întreabă dacă nu cumva te cheamă „little bitch”.
2. În bucătărie vorbești cu **Mom**: azi împlinești 16 ani și trebuie să devii vrăjitoare. Primești sarcina **„Meet with the coven.”** (o vezi oricând cu Tab).
3. Abia acum se deschide ușa de la intrare. Ecranul se face negru, cobori scările blocului și ajungi afară, în fața blocului **M7, scara B**, la 11:57 PM.
4. Pe bancă stă o **babă** care are câteva lucruri de spus despre mama ta.
5. La 5 secunde după ce termini cu baba (sarcina: **„Catch the night bus.”**) apare din ceață **autobuzul de noapte 13** („13 PADURE”), frânează și oprește în stația din dreapta blocului. Ușile se deschid cu un șuierat; urci cu E.
6. În autobuz stai pe scaun, la geam, și te poți uita în jur. Te gândești la mama ta și la cum ai putea vinde iarbă în loc de vrăjitorie. Afară e pădurea. Când te uiți spre pădure, o **arătare palidă și slabă** aleargă pe lângă autobuz, ține pasul o clipă chiar sub geamul tău și se uită la tine, apoi țâșnește și dispare printre copaci. O recunoști: e bunica, iar și-a uitat pastilele. Autobuzul oprește la capăt de linie, „Forest Road”.
7. Urmează: pădurea și întâlnirea cu coven-ul (deocamdată, după autobuz scrie „To be continued...” și te întorci în meniu).

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
- `scripts/meniu_principal.gd` – meniul principal (în spate e curtea blocului, cu baba pe bancă). Tastele, volumul și ecranul complet le ține `scripts/setari.gd`, iar salvările `scripts/salvare.gd`: jocul se salvează singur (când intri într-un loc, când se întâmplă ceva în poveste, la fiecare minut și când închizi), în fișierul ales din meniu. Fișierele stau în `%APPDATA%\Godot\app_userdata\Horror Indie\`.
- `scripts/meniu_nume.gd` – meniul în care îți scrii numele (apare prima dată când încerci să ieși din cameră). Textele lui se schimbă din `@export`-urile de sus.
- `scripts/inventar.gd` – fereastra de inventar (Tab). `Stare.seteaza_sarcina("...")` schimbă sarcina curentă și o arată sus 5 secunde.
- `scenes/usa_intrare.tscn` – ușa de la intrare. În Inspector, la `Usa`: `marcaj_necesar` = ce trebuie să se fi întâmplat ca să se deschidă (acum `a_vorbit_cu_mom`), `replici_fara_marcaj` = ce zici până atunci.
- `scenes/nivel_test.tscn` – prima scenă, casa: camera ta, holul (cu trei tablouri vechi — doar cel de lângă ușa bucătăriei se poate examina — și cuierul cu papucii pentru musafiri), ușa de la intrare, bucătăria cu Mom. Începi în camera ta.
- `scenes/bucatarie.tscn` – bucătăria de bloc: aragaz cu oala de sarmale (capacul saltă), chiuvetă cu perdeluță, faianță, neon care pâlpâie, masă cu mușama în carouri, taburete, cutia de biscuiți cu ațe, icoană cu ștergar și candelă, borcane, punga cu pungi, calendarul din 2009, damigeana. E merge doar pe frigider și pe Mom; restul e decor.
- `scripts/tablou.gd` – tablou pe perete: alegi poza în `imagine` (Inspector). Pozele tale stau în `textures/Tablouri/`; în joc intră copiile mici, în culorile paletei (`textures/tablou_*.png`).
- `scenes/afara_bloc.tscn` – afară, în fața blocului tău (BL. M7, scara B), noaptea: grădină cu copaci de toamnă, frunze care cad, ceață, felinare care pâlpâie, o babă pe bancă (vorbește cu tine despre mama ta), tomberonul, bătătorul cu covor, stația autobuzului 13 (în dreapta, cu orarul pe care se poate citi ceva zgâriat). Ajungi aici când deschizi ușa de la intrare, printr-un ecran negru în care auzi cum cobori scările și ușa blocului trântindu-se.
- `scripts/tranzitie.gd` – trecerea dintre scene prin ecran negru: `Tranzitie.mergi_la("res://scenes/...tscn", "Numele locului", [sunete])`. La orice ușă (`usa.gd`) completezi în Inspector, la „Iesire din scena”: `scena_urmatoare`, `titlu_locatie` și `sunete_tranzitie`.
- `scripts/acustica.gd` – pune câte unul în fiecare nivel: cât ecou au sunetele acolo (în casă puțin, afară aproape deloc).
- `scenes/statie.tscn` – stația de autobuz: copertină, bancă, afiș, orarul (se poate citi), un geam spart, plăcuța liniei 13.
- `scenes/autobuz.tscn` + `scripts/autobuz.gd` – autobuzul (un Ikarus vechi, cu salon mobilat și șofer). Îl muți din alt script și el se descurcă singur: roțile se învârt, motorul turează după viteză, caroseria se leagănă și se apleacă la frână. Ușile: `deschide_usi()` / `inchide_usi()`.
- `scripts/sosire_autobuz.gd` – nodul `SosireAutobuz` din `afara_bloc.tscn`: când vine autobuzul (`intarziere`, implicit 5 s după baba), de unde vine, cât de repede merge și frânează, unde oprește.
- `scenes/autobuz_drum.tscn` + `scripts/drum_autobuz.gd` – scena din autobuz: drumul prin pădure, creatura și dialogul. În Inspector: `viteza`, cât de deasă e pădurea, când apare creatura (`armare`, `momeala`, `fortat`), cât stă lângă geam (`timp_alaturi`), replicile (grupul „Replici”: le schimbi direct acolo; `intarziere_replici` = după câte secunde de la apariția creaturii zici replicile cu bunica, acum 2,5), și `scena_urmatoare` (când facem pădurea, o pui aici în loc de „To be continued”).
- `scripts/calator.gd` – tu, așezat: te uiți în jur cu mouse-ul, dar nu te miști. `scenes/creatura.tscn` + `scripts/creatura.gd` – arătarea care aleargă (cât de repede pășește, cât e de aplecată).

## Modele 3D
Modelele din `models/*.glb` sunt făcute în Blender **din cod**: `tools/blender/modele.py` (casa), `dormitor.py` (camera ta), `afara.py` (blocul, copacii și curtea), `bucatarie.py` (bucătăria, ramele tablourilor, cuierul) și `autobuz.py` (autobuzul, stația, șoferul, creatura, brazii și stâlpii de pe drum). Toate culorile vin din paleta ta, `textures/paleta culori.hex`, și se scriu ca `p("7b383a")`. O culoare din afara paletei oprește scriptul cu o eroare. Ca să schimbi o culoare sau o mărime, editezi acolo și rulezi:
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
- **autobuzul**: motorul diesel (sintetizat; turează după viteză), scârțâitul frânei și „pfff”-ul frânei de aer, ușile pneumatice, huruitul drumului și zornăitul salonului; creatura: pași repezi prin frunze, un vâjâit când trece pe lângă geam, crengi rupte când intră în pădure;
- în dialog, un bip la câteva litere („vocea”): Mom are vocea groasă, baba puțin mai subțire, tu subțire;
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
3. ✅ Uși, chei, inventar, sarcini, tranziții între scene
4. ⏳ Niveluri (✅ casa, ✅ curtea blocului, ✅ drumul cu autobuzul; urmează pădurea), modele low-poly făcute din cod
5. ⏳ Sunet (✅ ambianță, pași, obiecte, interfață; urmează jumpscare-uri și muzică)
6. Monstrul, jumpscare-uri, comedie
7. Meniu, salvare, final
8. Playtest și build
