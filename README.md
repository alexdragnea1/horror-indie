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
| Click stânga | tragi cu pistolul roz (după ce ți-l dă Head Witch) |
| F | lanterna |
| Tab | deschide / închide inventarul (5 sloturi + sarcina curentă) |
| Esc | în joc: **meniul de pauză** (Resume, Go to main menu, Settings, Quit; jocul stă pe loc) / închide inventarul / în meniuri: înapoi |
| F11 | ecran complet (merge oriunde) |

## Povestea până acum
1. Te trezești în camera ta de vrăjitoare. Când încerci să ieși, îți alegi numele... și jocul te întreabă dacă nu cumva te cheamă „little bitch”.
2. În bucătărie vorbești cu **Mom**: azi împlinești 16 ani și trebuie să devii vrăjitoare. Primești sarcina **„Meet with the coven.”** (o vezi oricând cu Tab).
3. Abia acum se deschide ușa de la intrare. Ecranul se face negru, cobori scările blocului și ajungi afară, în fața blocului **M7, scara B**, la 11:57 PM.
4. Pe bancă stă o **babă** care are câteva lucruri de spus despre mama ta.
5. La 5 secunde după ce termini cu baba (sarcina: **„Catch the night bus.”**) apare din ceață **autobuzul de noapte 13** („13 Trivale”), frânează și oprește în stația din dreapta blocului. Ușile se deschid cu un șuierat; urci cu E.
6. În autobuz stai pe scaun, la geam, și te poți uita în jur. Te gândești la mama ta și la cum ai putea vinde iarbă în loc de vrăjitorie. Afară e pădurea. Când te uiți spre pădure, o **arătare palidă și slabă** aleargă pe lângă autobuz, fără alt sunet decât pașii ei grei și umezi, ține pasul o clipă chiar sub geamul tău și se uită la tine, apoi țâșnește și dispare printre copaci. O recunoști: e bunica, iar și-a uitat pastilele.
7. La 6 secunde după ce dispare, ecranul se întunecă și cobori la **stația de la marginea pădurii Trivale** (12:00 AM). Autobuzul închide ușile și pleacă. Rămâi singur pe șosea, cu sarcina „Find the coven in Trivale Forest.”
8. Poteca trece pe lângă **bariera forestieră** („NO ENTRY”, încuiată, dar o ocolești pe lângă stâlp; lângă ea, panoul verde cu mesajul pădurarului) și urcă spre deal. La bifurcație, un indicator: **dreapta** („PLATEAU”) urcă pe un platou în mijlocul pădurii, unde ceața se ridică și se văd stelele și luna. De pe la jumătatea urcușului se aude muzică, întâi înfundată, apoi tot mai clar: sus, pe un buștean, un băiat mort de beat ascultă la boombox, cu zece beri în jur. Dacă vorbești cu el îți oferă o bere: dacă zici Yes, o bei și 5 secunde vezi dublu; **stânga** (numele e zgâriat cu cuțitul) coboară într-o vale tot mai creepy: copacii mor, ceața devine roșie și grea, apar cruci și păpuși de paie atârnate de crăci.
9. În fundul văii, într-un cerc de cruci cu lumânări, e **coven-ul**: cinci vrăjitoare cu ochii aprinși descântă peste un cazan uriaș, iar **Head Witch** te așteaptă între două torțe. Îți spune că pentru puterile tale trebuie un sacrificiu uman și îți dă un **pistol roz** (sarcina „Make a human sacrifice.”).
10. Cu pistolul poți omorî dintr-un glonț doar pe cine trebuie: la început doar **bețivul** de pe platou. Cade pe spate peste buștean, moale ca o cârpă, și îl iei în inventar cu E. Dar dacă te duci la el cu pistolul, ridică mâinile: „Wait!”. Îți spune că vrăjitoarele fac asta de ani de zile și te roagă să împuști una de-a lor în locul lui. După asta poți împușca **orice vrăjitoare din cerc** (pe Head Witch nu), o iei în inventar („Witch”) și o arunci în cazan în locul bețivului. Dar poți omorî **o singură persoană**: după primul mort (bețivul sau o vrăjitoare), gloanțele nu mai omoară pe nimeni. Și dacă te enervează muzica, poți trage în **boombox**: sar scântei, iese fum, muzica se îneacă și tace de tot (rămâne stricat și la Continue).
11. Îl arunci în cazan: poțiunea se face verde, din cazan pleacă spre cer o undă de lumină, apoi țâșnesc scântei roșii. Vraja e gata.
12. Head Witch te trimite acasă la culcare; autobuzul vine abia la 6 dimineața, așa că te duce ea pe mătură. Urcați peste pădure, spre lună... și te trezești pe iarbă în fața blocului. Baba nu mai e pe bancă. Sarcina: „Go home and rest.”
13. Urmează: ce se întâmplă acasă.

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
- `scripts/pauza.gd` – meniul de pauză (Esc în joc, sau singur când dai Alt+Tab): Resume, Go to main menu, Settings, Quit. Ecranul de Settings e același ca în meniul principal (`scripts/panou_setari.gd`), deci ce schimbi acolo se vede în ambele.
- `scripts/meniu_nume.gd` – meniul în care îți scrii numele (apare prima dată când încerci să ieși din cameră). Textele lui se schimbă din `@export`-urile de sus.
- `scripts/inventar.gd` – fereastra de inventar (Tab). `Stare.seteaza_sarcina("...")` schimbă sarcina curentă și o arată sus 5 secunde.
- `scenes/usa_intrare.tscn` – ușa de la intrare. În Inspector, la `Usa`: `marcaj_necesar` = ce trebuie să se fi întâmplat ca să se deschidă (acum `a_vorbit_cu_mom`), `replici_fara_marcaj` = ce zici până atunci.
- `scenes/nivel_test.tscn` – prima scenă, casa: camera ta, holul (cu trei tablouri vechi — doar cel de lângă ușa bucătăriei se poate examina — și cuierul cu papucii pentru musafiri), ușa de la intrare, bucătăria cu Mom. Începi în camera ta.
- `scenes/bucatarie.tscn` – bucătăria de bloc (mică și înghesuită, ca una adevărată de bloc): aragaz cu oala de sarmale (capacul saltă), chiuvetă cu perdeluță, faianță, neon care pâlpâie, masă cu mușama în carouri, taburete, cutia de biscuiți cu ațe, icoană cu ștergar și candelă, borcane, punga cu pungi, calendarul din 2009, damigeana. E merge doar pe frigider și pe Mom; restul e decor.
- `scripts/tablou.gd` – tablou pe perete: alegi poza în `imagine` (Inspector). Pozele tale stau în `textures/Tablouri/`; în joc intră copiile mici, în culorile paletei (`textures/tablou_*.png`).
- `scenes/afara_bloc.tscn` – afară, în fața blocului tău (BL. M7, scara B), noaptea: grădină cu copaci de toamnă, frunze care cad, ceață, felinare care pâlpâie, o babă pe bancă (vorbește cu tine despre mama ta), tomberonul, bătătorul cu covor, stația autobuzului 13 (în dreapta). Ajungi aici când deschizi ușa de la intrare, printr-un ecran negru în care auzi cum cobori scările și ușa blocului trântindu-se.
- `scripts/tranzitie.gd` – trecerea dintre scene prin ecran negru: `Tranzitie.mergi_la("res://scenes/...tscn", "Numele locului", [sunete])`. La orice ușă (`usa.gd`) completezi în Inspector, la „Iesire din scena”: `scena_urmatoare`, `titlu_locatie` și `sunete_tranzitie`.
- `scripts/acustica.gd` – pune câte unul în fiecare nivel: cât ecou au sunetele acolo (în casă puțin, afară aproape deloc).
- `scenes/statie.tscn` – stația de autobuz: copertină, bancă, afiș, orarul, un geam spart, plăcuța liniei 13 (nimic cu E).
- `scenes/autobuz.tscn` + `scripts/autobuz.gd` – autobuzul (un Ikarus vechi, cu salon mobilat și șofer). Îl muți din alt script și el se descurcă singur: roțile se învârt, motorul turează după viteză, caroseria se leagănă și se apleacă la frână. Ușile: `deschide_usi()` / `inchide_usi()`.
- `scripts/sosire_autobuz.gd` – nodul `SosireAutobuz` din `afara_bloc.tscn`: când vine autobuzul (`intarziere`, implicit 5 s după baba), de unde vine, cât de repede merge și frânează, unde oprește.
- `scenes/autobuz_drum.tscn` + `scripts/drum_autobuz.gd` – scena din autobuz: drumul prin pădure, creatura și dialogul. În Inspector: `viteza`, cât de deasă e pădurea, când apare creatura (`armare`, `momeala`, `fortat`), cât stă lângă geam (`timp_alaturi`), replicile (grupul „Replici”: le schimbi direct acolo; `intarziere_replici` = după câte secunde de la apariția creaturii zici replicile cu bunica, acum 2,5), `dupa_disparitie` (după câte secunde de la dispariția creaturii ajungi în pădure, acum 6) și `scena_urmatoare` (pădurea). Pașii creaturii (cât de des, cât de tare) se reglează în `scenes/creatura.tscn`.
- `scenes/padure.tscn` – pădurea Trivale: stația de la marginea pădurii, autobuzul care pleacă (`PlecareAutobuz`: cât așteaptă, cât de repede pleacă, ce sarcină primești), bariera, panoul verde de lângă barieră (cu mesajul pădurarului), indicatorul de la bifurcație, platoul și valea. Ce e pus de mână stă sub nodul `PePamant`: în editor muți obiectele doar pe orizontală, iar jocul le pune singur pe pământ. În pădure se apasă cu E doar panoul verde de lângă barieră.
- `scripts/teren_padure.gd` (nodul `Teren`) – terenul, făcut din cod: cât de înalt e dealul, cât de adâncă e valea, unde sunt platoul și potecile (lista de puncte a fiecărei poteci), cât de lată e poteca. Schimbi o valoare în Inspector și la următoarea pornire terenul e altul.
- `scripts/vegetatie_padure.gd` (nodul `Vegetatie`) – copacii: cât de deasă e pădurea, ce copaci cresc, unde nu crește nimic (`zone_libere`). Cu cât cobori în vale, cu atât sunt mai morți. Pietrele și buștenii de pe marginea potecii au coliziune.
- `scripts/semne_vale.gd` (nodul `SemneVale`) – crucile, păpușile și lumânările din valea din stânga (lista `SEMNE` din script).
- `scenes/betiv.tscn` – bețivul de pe platou, cu bușteanul, boombox-ul și berile. Pe nodul `Personaj`: replicile (`replici`, `intrebare`, `optiuni`), cât de beat ești după bere (`durata_beat`, acum 5 s), cât își ridică brațul. Conversația cu mâinile sus e în `replici_pistol`, iar cât de sus le ridică în `maini_sus`. Pe `Boombox`: de unde începe să se audă muzica (`departe`, 38 m ≈ jumătatea dealului), de unde se aude tare (`aproape`, 14 m), volumul (`volum_db`). Modelele lui sunt în `tools/blender/deal.py`. În grupul „Moarte” al `Personaj`: `omorabil` (poate fi împușcat), cât de tare îl împinge glonțul (`forta_glont`), cum se cheamă în inventar (`nume_cadavru`).
- `scenes/coven.tscn` – coven-ul din fundul văii. Pe `HeadWitch`: replicile (`replici` până la „Here.”, `replici_pistol` după ce îți dă pistolul, `replici_acasa` la sfârșit), sarcina, cât își ridică brațul, cât de sus plutește mătura și unde stați pe ea, după câte secunde de la decolare se face negru (`dupa_decolare`, acum 3) și titlul de la bloc (`titlu_acasa`). Pe `Cazan`: culorile poțiunii (mov la început, verde după vrajă), culoarea particulelor, cât stă unda pe cer (`durata_unda`, acum 2 s). Fiecare vrăjitoare din cerc are `faza` și `viteza` (cum descântă). Modelele: `tools/blender/coven.py`. Pe fiecare `Vrajitoare1..5`, în grupul „Moarte”: cât de tare o împinge glonțul (`forta_glont`) și numele din inventar (`nume_cadavru`).
- `scripts/pistol.gd` – pistolul din mâna ta: unde îl ții pe ecran (`pozitie`), cât de departe bate (`bataie`), cât aștepți între gloanțe (`pauza`). Rozul vine din `shaders/material_roz.tres` (`culoare`).
- `scripts/ragdoll.gd` – corpul care cade moale când moare cineva. Merge cu orice model făcut din bucăți separate, cu originea fiecărei bucăți în încheietură.
- `scripts/intoarcere_acasa.gd` (nodul `IntoarcereAcasa` din `afara_bloc.tscn`) – trezirea în fața blocului după zbor: unde te trezești (`loc_trezire`), încotro te uiți, ce sarcină primești.
- `scripts/limite_padure.gd` (nodul `ZidInvizibil`) – zidul invizibil din pădure: poți ieși de pe potecă printre copaci, dar doar cam 8 m (`departe_de_poteca`); pe platou (`raza_platou`) și în poiana din vale (`raza_vale`) ai loc mai mult. Bifează `arata` ca să-l vezi roșu când testezi.
- La orice model pus în scenă fără coliziune (o piatră, o ladă) poți bifa în Inspector, la `ModelPS2`, `coliziune` = Cilindru sau Cutie.
- `scripts/atmosfera_padure.gd` (nodul `Atmosfera`) – cum se schimbă ceața, lumina, cerul și sunetele în pădure, pe platou și în vale (grupurile „Pădure”, „Platou”, „Vale” din Inspector).
- `scripts/calator.gd` – tu, așezat: te uiți în jur cu mouse-ul, dar nu te miști. `scenes/creatura.tscn` + `scripts/creatura.gd` – arătarea care aleargă (cât de repede pășește, cât e de aplecată).

## Modele 3D
Modelele din `models/*.glb` sunt făcute în Blender **din cod**: `tools/blender/modele.py` (casa), `dormitor.py` (camera ta), `afara.py` (blocul, copacii și curtea), `bucatarie.py` (bucătăria, ramele tablourilor, cuierul) , `autobuz.py` (autobuzul, stația, șoferul, creatura, brazii și stâlpii de pe drum) și `padure.py` (stația din pădure, bariera, panoul, indicatorul, copacii morți, crucile, păpușile), `deal.py` (bețivul, boombox-ul, berile) și `coven.py` (vrăjitoarele, Head Witch, cazanul, pistolul roz, mătura, torța). Toate culorile vin din paleta ta, `textures/paleta culori.hex`, și se scriu ca `p("7b383a")`. O culoare din afara paletei oprește scriptul cu o eroare. Ca să schimbi o culoare sau o mărime, editezi acolo și rulezi:
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
- **muzică** în fața blocului: piesa ta „Block” (din `Sound/Music`), în buclă; pornește încet când ieși din casă și o reglezi cu glisorul Music. Dacă schimbi piesa, rulează iar `bash tools/sunete.sh`;
- **boombox-ul** de pe deal: piesa ta „Deal” (din `Sound/Music`), în buclă; de departe se aude doar basul, de aproape tot. Dacă tragi în el cu pistolul se strică: plasticul crapă, sar scântei, muzica se îneacă și tace. Berea: clinchet, înghițituri, râgâit;
- **coven-ul**: vrăjitoarele murmură un cântec grav, cazanul fierbe, focul de sub el trosnește; pistolul bubuie cu ecou prin pădure, corpul cade cu o bufnitură, în cazan face pleosc; unda de lumină urcă cu un vâjâit tot mai ascuțit, apoi bubuie; mătura apare cu un vâjâit, iar la decolare vântul crește;
- **ușa camerei** scârțâie lung când o deschizi; **ceaunul** fierbe și gâlgâie din când în când; **ceasul** din bucătărie ticăie (e oprit la 11:55);
- **vânt** afară, iar din când în când un scârțâit sau un ciocănit din pereți, și foarte rar ceva... mai rău; în fața blocului, uneori, cineva fluieră departe în întuneric sau se aude o tablă lovită;
- **tranziția** spre afară: pașii pe scara blocului, cu ecou, și ușa metalică a scării trântită;
- **autobuzul**: motorul diesel (sintetizat; turează după viteză), scârțâitul frânei și „pfff”-ul frânei de aer, ușile pneumatice, huruitul drumului și zornăitul salonului; creatura: pași repezi prin frunze, un vâjâit când trece pe lângă geam, crengi rupte când intră în pădure;
- **pădurea**: pașii pe potecă scrâșnesc a pietriș, iar prin frunze foșnesc; vânt și, din când în când, o bufniță; pe platou greieri; în vale vântul tace și crește un huruit jos, ca o inimă, peste care se aud ciocănituri, crengi rupte și... pași grei;
- **creatura** din autobuz nu mai face niciun sunet în afară de pași: grei, umezi, în galop șchiop, cu oase care pocnesc;
- în dialog, un bip la câteva litere („vocea”): Mom are vocea groasă, baba puțin mai subțire, bețivul și Head Witch groase, tu subțire;
- la meniul cu numele: clicuri și o lovitură dramatică la „Are you sure your name is little bitch?”.

**Toate efectele au același volum**: fișierele sunt aduse la aceeași tărie de `tools/sunete.sh`, iar în joc toate efectele se redau la `Sunet.VOLUM_EFECTE` și toate buclele de fundal (vânt, bâzâit, motor...) la `Sunet.VOLUM_AMBIANTA` (-14 dB, ca să nu acopere efectele). Ca să faci totul mai tare sau mai încet, schimbi unul din cele două numere din `scripts/sunet.gd`, sau canalele din panoul **Audio** de jos (`Efecte`, `Ambianta`, `Interfata`). ⚠️ Pachetul e de pe Guru3D: verifică licența înainte de Steam.

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
4. ⏳ Niveluri (✅ casa, ✅ curtea blocului, ✅ drumul cu autobuzul, ✅ pădurea Trivale, ✅ bețivul, ✅ coven-ul și zborul acasă; urmează ce se întâmplă acasă), modele low-poly făcute din cod
5. ⏳ Sunet (✅ ambianță, pași, obiecte, interfață, toate la același volum, muzica la fel de tare ca efectele, muzica ta „Block” în fața blocului și „Deal” la bețiv, coven-ul; urmează jumpscare-uri și muzică în alte locuri)
6. ⏳ Monstrul (✅ prima apariție: creatura de lângă autobuz), jumpscare-uri, comedie
7. ⏳ Meniu, salvare (✅), final
8. Playtest și build
