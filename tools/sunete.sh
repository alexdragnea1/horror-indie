#!/usr/bin/env bash
# Pregătește sunetele jocului din pachetul brut (Sound/Soundpack, ignorat de Godot și de git)
# în sunete/*.ogg: taie liniștea de la început, aduce totul la aceeași tărie (-20 LUFS), mono pentru sunetele
# care vin dintr-un loc anume (3D) și face buclele să se lege fără cusătură.
# Rulare din folderul proiectului:   bash tools/sunete.sh
set -e
cd "$(dirname "$0")/.."
PACHET="Sound/Soundpack"
OUT="sunete"
mkdir -p "$OUT"

# Toate sunetele ies la aceeași tărie PERCEPUTĂ (loudness, ca la studiourile mari), nu doar la același
# vârf: un pas și o ușă trântită sună la fel de tare. Vârfurile care ar trece de -2 dB le prinde limitatorul (rezervă pentru comprimarea .ogg).
TINTA_LUFS=-20
LIMITATOR="alimiter=limit=0.79:attack=1:release=60:level=false"

# castig FISIER_INTRARE FILTRU -> câștigul (dB) care aduce tăria (LUFS integrat) la TINTA_LUFS după FILTRU.
# La sunetele foarte scurte măsurătoarea are nevoie de puțină liniște după (apad).
castig() {
	local i
	i=$(ffmpeg -hide_banner -i "$1" -af "$2,apad=pad_dur=0.5,ebur128" -f null - 2>&1 | grep -A2 "Integrated loudness" | grep -o "I: *[-0-9.]*" | grep -o "[-0-9.]*$")
	awk -v i="$i" -v t="$TINTA_LUFS" 'BEGIN { printf "%.2f", t - i }'
}

# castig_final FISIER_INTRARE FILTRU -> ca `castig`, dar măsoară din nou DUPĂ limitator și corectează
# (de două ori): sunetele cu vârfuri ascuțite (pași, ușa trântită) pierd tărie la limitator.
castig_final() {
	local g i k
	g=$(castig "$1" "$2")
	for k in 1 2; do
		i=$(ffmpeg -hide_banner -i "$1" -af "$2,volume=${g}dB,$LIMITATOR,apad=pad_dur=0.5,ebur128" -f null - 2>&1 | grep -A2 "Integrated loudness" | grep -o "I: *[-0-9.]*" | grep -o "[-0-9.]*$")
		g=$(awk -v g="$g" -v i="$i" -v t="$TINTA_LUFS" 'BEGIN { printf "%.2f", g + (t - i) }')
	done
	echo "$g"
}

# unic NUME SURSA [mono|stereo] [FILTRU_EXTRA] -> sunet scurt (pas, ușă, clic)
unic() {
	local nume="$1" sursa="$PACHET/$2" canale="${3:-mono}" extra="${4:-anull}"
	[ -f "$sursa" ] || sursa="$2"  # merge și cu un fișier din afara pachetului
	local ac=1; [ "$canale" = stereo ] && ac=2
	local f="silenceremove=start_periods=1:start_threshold=-50dB,$extra"
	local g; g=$(castig_final "$sursa" "$f")
	ffmpeg -v error -y -i "$sursa" -af "$f,volume=${g}dB,$LIMITATOR" -ac $ac -c:a libvorbis -q:a 5 "$OUT/$nume.ogg"
	echo "$nume.ogg  <- $2"
}

# bucla NUME SURSA SUPRAPUNERE [mono|stereo] [FILTRU_EXTRA] -> buclă fără cusătură:
# coada sunetului se topește în începutul lui, deci sfârșitul se leagă perfect de început.
bucla() {
	local nume="$1" sursa="$2" d="$3" canale="${4:-mono}" extra="${5:-anull}"
	# curba crossfade-ului: qsin pentru zgomot; tri pentru sunete periodice (motorul), altfel se adună peste 0 dB și pocnește
	local curba="${6:-qsin}"
	local ac=1; [ "$canale" = stereo ] && ac=2
	local tmp="$OUT/_tmp.wav"
	ffmpeg -v error -y -i "$sursa" -af "$extra" -ac $ac "$tmp"
	local g; g=$(castig_final "$tmp" "anull")
	ffmpeg -v error -y -i "$tmp" -filter_complex \
		"[0]atrim=start=$d,asetpts=PTS-STARTPTS[a];[0]atrim=end=$d,asetpts=PTS-STARTPTS[b];[a][b]acrossfade=d=$d:c1=$curba:c2=$curba,volume=${g}dB,$LIMITATOR" \
		-c:a libvorbis -q:a 5 "$OUT/$nume.ogg"
	rm -f "$tmp"
	echo "$nume.ogg  (buclă)"
}

# --- pași: podeaua de lemn a casei și covorul din camera ta
# Lemnul: pașii „vinyl” singuri sunau a tablă (tonuri care țiuie la 8–18 kHz). Le păstrăm doar tocul din mijloc
# (lowpass 1,8 kHz, puțin mai plin la 400 Hz, coada scurtată) și dedesubt bufnitura joasă a scândurii (digital_footstep_wood).
for i in 1 2 3 4; do
	ffmpeg -v error -y -i "$PACHET/Footsteps/foley_footstep_vinyl_$i.wav" -i "$PACHET/Footsteps/digital/digital_footstep_wood_$i.wav" -filter_complex \
		"[0]aformat=channel_layouts=mono,silenceremove=start_periods=1:start_threshold=-50dB,lowpass=f=1800,lowpass=f=1800,highpass=f=90,equalizer=f=400:t=q:w=1:g=4,afade=t=out:st=0.03:d=0.22:curve=exp[a];[1]silenceremove=start_periods=1:start_threshold=-50dB,volume=-3dB,afade=t=out:st=0.12:d=0.15[b];[a][b]amix=inputs=2:normalize=0" \
		-ac 1 "$OUT/_lemn.wav"
	unic "pas_lemn_$i" "$OUT/_lemn.wav"
	rm -f "$OUT/_lemn.wav"
	unic "pas_covor_$i" "Footsteps/foley_footstep_carpet_$i.wav"
done
unic scartait_podea "Footsteps/foley_creak_1.wav"

# --- uși, frigider, obiecte
unic usa_scartait "Environment/creaky_door_long.wav"
unic usa_inchisa "Environment/door_close.wav"
unic usa_incuiata "Environment/lock_quick.wav"
unic usa_intrare "Environment/door_open.wav"
unic frigider_deschis "Environment/air_burst.wav" mono "lowpass=f=2500"
unic frigider_inchis "Materials/ceramic_jar_close.wav" mono "asetrate=44100*0.85,aresample=44100"
unic obiect_luat "Items/item_equip.wav" stereo
unic lanterna_pornita "UI/toggle_on.wav" stereo
unic lanterna_oprita "UI/toggle_off.wav" stereo

# --- interfață și dialog
unic ui_peste "UI/select_1.wav" stereo
unic ui_clic "UI/pop_1.wav" stereo
unic ui_sting "Musical Effects/horror_sting.wav" stereo
unic sarcina_noua "Musical Effects/music_box_mystery.wav" stereo
unic inventar_deschis "Environment/zipper_down.wav" stereo
unic inventar_inchis "Environment/zipper_up.wav" stereo
unic dialog_voce "Retro/menu_blip.wav" mono "lowpass=f=2200,afade=t=out:st=0.05:d=0.04"

# --- sperieturi rare, din locuri la întâmplare
unic ciocanit "Other/subtle_knock.wav"
unic fantoma "Other/ghost_long.wav" mono "lowpass=f=3000"
unic gâlgâit "Environment/gurgling.wav" mono "asetrate=44100*0.8,aresample=44100"
mv -f "$OUT/gâlgâit.ogg" "$OUT/galgait.ogg"

# --- bucle de ambianță
bucla vant "$PACHET/Environment/ambient_wind.wav" 1.5 stereo
bucla ceaun_fierbe "$PACHET/Environment/water_boiling_loop.wav" 0.6 mono "asetrate=44100*0.75,aresample=44100,lowpass=f=4000"
g=$(castig_final "$PACHET/Environment/clock_ticking.wav" "anull")
ffmpeg -v error -y -i "$PACHET/Environment/clock_ticking.wav" -ac 1 -af "volume=${g}dB,$LIMITATOR" -c:a libvorbis -q:a 5 "$OUT/ceas.ogg"
echo "ceas.ogg  (buclă, 4 s = exact 4 tic-tacuri)"

# --- sintetizate (nu există în pachet)
# frigider: bâzâitul compresorului (50 Hz + armonice) peste zgomot maro, foarte jos
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.30*sin(2*PI*50*t)+0.22*sin(2*PI*100*t)+0.07*sin(2*PI*150*t)+0.04*sin(2*PI*200*t):s=44100:d=6" \
	-f lavfi -i "anoisesrc=c=brown:a=0.08:d=6:r=44100" -filter_complex "[0][1]amix=inputs=2:normalize=0,lowpass=f=900" -ac 1 "$OUT/_frig.wav"
bucla frigider_bazait "$OUT/_frig.wav" 0.8 mono
# bec: bâzâitul electric (100 Hz cu multe armonice, ca la un bec vechi pe ducă)
ARM=""; for n in 1 2 3 4 5 6 7 8 9 10 11 12; do ARM="$ARM+sin(2*PI*$((100 * n))*t)/$n"; done
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.15*(${ARM#+})*(1+0.15*sin(2*PI*6*t)):s=44100:d=4" -af "highpass=f=90,lowpass=f=5000" -ac 1 "$OUT/_bec.wav"
bucla bec_bazait "$OUT/_bec.wav" 0.5 mono
rm -f "$OUT/_frig.wav" "$OUT/_bec.wav"

# --- afară, la bloc
# pași pe beton (trotuar, alee) și pe frunze uscate: iarbă + o bucățică de hârtie mototolită (foșnetul)
for i in 1 2 3 4; do
	unic "pas_beton_$i" "Footsteps/foley_footstep_concrete_$i.wav"
	ffmpeg -v error -y -i "$PACHET/Footsteps/digital/digital_footstep_grass_$i.wav" \
		-ss "0.$((i * 2))" -t 0.22 -i "$PACHET/Materials/paper_scrunch.wav" \
		-filter_complex "[1]highpass=f=1200,volume=-6dB,afade=t=in:d=0.02,afade=t=out:st=0.1:d=0.12[f];[0][f]amix=inputs=2:normalize=0" \
		-ac 1 "$OUT/_frunze.wav"
	unic "pas_frunze_$i" "$OUT/_frunze.wav"
done
rm -f "$OUT/_frunze.wav"
# ușa metalică a scării de bloc: trântită, cu zăngănitul tablei după
ffmpeg -v error -y -i "$PACHET/Machines/industrial_door_close.wav" -i "$PACHET/Materials/metal_clang.wav" \
	-filter_complex "[1]adelay=60,volume=-8dB[c];[0][c]amix=inputs=2:normalize=0,lowpass=f=4000" -ac 1 "$OUT/_usa.wav"
unic usa_bloc "$OUT/_usa.wav"
rm -f "$OUT/_usa.wav"
# sperieturi de afară: cineva fluieră departe în întuneric, o tablă lovită
unic fluierat "Human/whistle.wav" mono "lowpass=f=1800,asetrate=44100*0.9,aresample=44100"
unic tabla_lovita "Materials/metal_blunt_tap.wav" mono "lowpass=f=2500"


# --- autobuzul de noapte (linia 13)
# motorul: diesel sintetizat (aprinderile la 35 Hz + armonice, „ciocănitul” = zgomot tăiat în ritmul
# aprinderilor) peste zgomot maro. Buclă de 4 s (35 Hz × 4 s = cicluri întregi). În joc pitch_scale = turația.
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.30*sin(2*PI*35*t)+0.24*sin(2*PI*70*t)+0.16*sin(2*PI*105*t)+0.1*sin(2*PI*140*t)+0.06*sin(2*PI*210*t)+0.08*sin(2*PI*17.5*t):s=44100:d=8" \
	-f lavfi -i "anoisesrc=c=white:a=0.5:d=8:r=44100" -f lavfi -i "aevalsrc=pow(0.5+0.5*sin(2*PI*35*t)\,10):s=44100:d=8" \
	-f lavfi -i "anoisesrc=c=brown:a=0.12:d=8:r=44100" -filter_complex \
	"[1]highpass=f=700,lowpass=f=2600[z];[z][2]amultiply,volume=0.35[c];[0][c][3]amix=inputs=3:normalize=0,lowpass=f=1800,highpass=f=25" \
	-ac 1 "$OUT/_motor.wav"
bucla motor_autobuz "$OUT/_motor.wav" 1.0 mono anull tri
# drumul simțit din salon: huruit grav + zgomotul roților pe asfalt vechi
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:a=0.4:d=8:r=44100" -f lavfi -i "anoisesrc=c=pink:a=0.08:d=8:r=44100" \
	-filter_complex "[0]lowpass=f=180[a];[1]bandpass=f=900:w=600[b];[a][b]amix=inputs=2:normalize=0,volume=1.5" -ac 2 "$OUT/_drum.wav"
bucla drum_rulare "$OUT/_drum.wav" 1.5 stereo
rm -f "$OUT/_motor.wav" "$OUT/_drum.wav"
# ușile pneumatice: șuierul aerului + pistonul, la închidere și bufnitura foilor
ffmpeg -v error -y -i "$PACHET/Environment/air_burst.wav" -i "$PACHET/Machines/hydraulic_down.wav" \
	-filter_complex "[0]lowpass=f=5000,asetrate=44100*0.8,aresample=44100[a];[1]adelay=120,volume=-4dB[b];[a][b]amix=inputs=2:normalize=0" -ac 1 "$OUT/_usi.wav"
unic usi_autobuz_deschise "$OUT/_usi.wav"
ffmpeg -v error -y -i "$PACHET/Environment/air_burst.wav" -i "$PACHET/Machines/hydraulic_up.wav" -i "$PACHET/Materials/metal_clang.wav" \
	-filter_complex "[0]lowpass=f=5000,asetrate=44100*0.75,aresample=44100[a];[1]adelay=100,volume=-4dB[b];[2]adelay=900,lowpass=f=1500,volume=-10dB[c];[a][b][c]amix=inputs=3:normalize=0" -ac 1 "$OUT/_usi.wav"
unic usi_autobuz_inchise "$OUT/_usi.wav"
rm -f "$OUT/_usi.wav"
# frâna: scârțâitul saboților (sintetizat, tremură) și „pfff”-ul frânei de aer la oprire
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.25*sin(2*PI*2350*t+3*sin(2*PI*9*t))+0.12*sin(2*PI*4700*t+5*sin(2*PI*9*t)):s=44100:d=1.8" \
	-i "$PACHET/Environment/air_burst.wav" -filter_complex \
	"[0]afade=t=in:d=0.25,afade=t=out:st=1.2:d=0.6,volume=-6dB[s];[1]asetrate=44100*0.7,aresample=44100,lowpass=f=4000,adelay=1700[a];[s][a]amix=inputs=2:normalize=0" \
	-ac 1 "$OUT/_frana.wav"
unic frana_autobuz "$OUT/_frana.wav"
rm -f "$OUT/_frana.wav"
# creatura: vâjâitul când trece pe lângă geam și crengile rupte când intră în pădure
unic vajait "Other/whoosh_2.wav" mono "lowpass=f=3500,asetrate=44100*0.85,aresample=44100"
ffmpeg -v error -y -i "$PACHET/Combat and Gore/crunch.wav" -i "$PACHET/Combat and Gore/crunch_quick.wav" \
	-filter_complex "[0]asetrate=44100*0.7,aresample=44100[a];[1]asetrate=44100*0.8,aresample=44100,adelay=250[b];[a][b]amix=inputs=2:normalize=0,lowpass=f=3000" -ac 1 "$OUT/_crengi.wav"
unic crengi "$OUT/_crengi.wav"
rm -f "$OUT/_crengi.wav"


# --- creatura: pași grei și umezi, cu o încheietură care pocnește (în loc de vâjâit și „sting”)
# iarbă încetinită (mai grea) + plescăit + un pocnet de os mic, toate înfundate
for i in 1 2 3 4; do
	ffmpeg -v error -y -i "$PACHET/Footsteps/digital/digital_footstep_grass_$i.wav" \
		-i "$PACHET/Combat and Gore/squelching_$i.wav" -i "$PACHET/Combat and Gore/bone_snap.wav" -filter_complex \
		"[0]asetrate=44100*0.68,aresample=44100[a];[1]atrim=end=0.25,afade=t=out:st=0.1:d=0.15,volume=-9dB[b];[2]asetrate=44100*(1.1+0.1*$i),aresample=44100,highpass=f=1500,adelay=$((20 + i * 15)),volume=-16dB[c];[a][b][c]amix=inputs=3:normalize=0,lowpass=f=3200" \
		-ac 1 "$OUT/_cp.wav"
	unic "creatura_pas_$i" "$OUT/_cp.wav"
done
rm -f "$OUT/_cp.wav"

# --- pădurea Trivale
# pași pe potecă (pietriș și pământ)
for i in 1 2 3 4; do
	unic "pas_poteca_$i" "Footsteps/foley_footstep_gravel_$i.wav" mono "lowpass=f=5000"
done
# greierii de pe platou: țârâit sintetizat (4,5 kHz, în rafale de câte 3), câțiva greieri decalați; buclă
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.25*sin(2*PI*4500*t)*gt(sin(2*PI*28*t)\,0.2)*gt(sin(2*PI*1.3*t)\,0.55)+0.18*sin(2*PI*4300*t)*gt(sin(2*PI*31*t)\,0.3)*gt(sin(2*PI*0.9*t+1.7)\,0.6)+0.12*sin(2*PI*4750*t)*gt(sin(2*PI*25*t)\,0.25)*gt(sin(2*PI*1.1*t+3.1)\,0.65):s=44100:d=12" \
	-af "highpass=f=3000,lowpass=f=6500,aecho=0.6:0.5:60|130:0.25|0.15" -ac 2 "$OUT/_greieri.wav"
bucla greieri "$OUT/_greieri.wav" 1.5 stereo
# bufnița: „hu... hu-hu” (sinus de ~400 Hz alunecând în jos, cu un pic de aer), cu ecou de pădure
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.5*sin(2*PI*(420-60*t)*t)*(between(t\,0\,0.45)*sin(PI*t/0.45))+0.4*sin(2*PI*(400-40*(t-0.8))*t)*(between(t\,0.8\,1.05)*sin(PI*(t-0.8)/0.25))+0.45*sin(2*PI*(390-50*(t-1.15))*t)*(between(t\,1.15\,1.6)*sin(PI*(t-1.15)/0.45)):s=44100:d=2.4" \
	-f lavfi -i "anoisesrc=c=pink:a=0.02:d=2.4:r=44100" -filter_complex "[0][1]amix=inputs=2:normalize=0,lowpass=f=1200,aecho=0.7:0.6:180|420:0.3|0.18" -ac 1 "$OUT/_bufnita.wav"
unic bufnita "$OUT/_bufnita.wav"
rm -f "$OUT/_greieri.wav" "$OUT/_bufnita.wav"
# zona din stânga: un huruit jos care bate ca o inimă rară + fâșâit, tot mai tare cu cât cobori; buclă
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.3*sin(2*PI*41*t)*(0.6+0.4*sin(2*PI*t/7))+0.18*sin(2*PI*61.7*t)*(0.5+0.5*sin(2*PI*t/11))+0.25*sin(2*PI*36*t)*pow(max(sin(2*PI*0.75*t)\,0)\,12):s=44100:d=22" \
	-f lavfi -i "anoisesrc=c=brown:a=0.05:d=22:r=44100" -filter_complex "[0][1]amix=inputs=2:normalize=0,lowpass=f=500" -ac 2 "$OUT/_drone.wav"
bucla drone_padure "$OUT/_drone.wav" 2 stereo anull tri
rm -f "$OUT/_drone.wav"

# --- muzica meniului principal: un drone grav (sintetizat) + cutia muzicală din pachet, încetinită,
# cu ecou lung, de trei ori, de fiecare dată mai jos. 36 s, buclă fără cusătură (crossfade 3 s).
CUTIE="$PACHET/Musical Effects/music_box_mystery.wav"
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.16*sin(2*PI*55*t)*(0.7+0.3*sin(2*PI*t/9))+0.10*sin(2*PI*82.41*t)*(0.6+0.4*sin(2*PI*t/18))+0.05*sin(2*PI*110.7*t)+0.025*sin(2*PI*164.8*t)*(0.5+0.5*sin(2*PI*t/36)):s=44100:d=36" \
	-f lavfi -i "anoisesrc=c=brown:a=0.03:d=36:r=44100" \
	-i "$CUTIE" -i "$CUTIE" -i "$CUTIE" -filter_complex \
	"[0][1]amix=inputs=2:normalize=0,lowpass=f=700[d];\
[2]asetrate=44100*0.72,aresample=44100,adelay=2500|2500[c1];\
[3]asetrate=44100*0.64,aresample=44100,adelay=14000|14000[c2];\
[4]asetrate=44100*0.68,aresample=44100,adelay=25000|25000,volume=-3dB[c3];\
[c1][c2][c3]amix=inputs=3:normalize=0,aecho=0.8:0.7:420|900:0.45|0.3,lowpass=f=3500,volume=-4dB[c];\
[d][c]amix=inputs=2:normalize=0,atrim=end=36" -ac 2 "$OUT/_meniu.wav"
bucla muzica_meniu "$OUT/_meniu.wav" 3 stereo
rm -f "$OUT/_meniu.wav"
# --- muzica din fața blocului (adusă de owner: Sound/Music/Block.mp3, „ranger's lament” de human gazpacho).
# Piesa se termină la 3:45, apoi sunt 3 s de liniște: le tăiem (cu o mică stingere), ca bucla să reînceapă repede.
# În Godot e buclă din import (loop=true).
unic muzica_bloc "Sound/Music/Block.mp3" stereo "atrim=end=226,afade=t=out:st=225.3:d=0.7"
# --- dealul din dreapta: boombox-ul bețivului (adusă de owner: Sound/Music/Deal.mp3, Ion feat. Herodot).
# Piesa se termină la 7:05, apoi sunt aproape 5 s de liniște: le tăiem, ca bucla să reînceapă repede.
unic muzica_deal "Sound/Music/Deal.mp3" stereo "atrim=end=426,afade=t=out:st=425.3:d=0.7"
# --- muzica locurilor (adusă de owner, toate în buclă din import): pădurea, curtea conacului, conacul pe dinăuntru,
# casa lui Lexy. Timpii de tăiere sunt după liniștea de la început (silenceremove): coada de liniște iese, ca bucla
# să reînceapă repede; pădurea n-are liniște la capăt, doar o stingere scurtă, să nu pocnească la reluare.
unic muzica_padure "Sound/Music/Forest.mp3" stereo "afade=t=out:st=359.2:d=0.35"
unic muzica_conac_afara "Sound/Music/Outside of the Manor.mp3" stereo "atrim=end=170.4,afade=t=out:st=169.7:d=0.7"
unic muzica_conac_interior "Sound/Music/Inside of the Manor.mp3" stereo "atrim=end=99.6,afade=t=out:st=98.9:d=0.7"
unic muzica_lexy "Sound/Music/Lexy's House.mp3" stereo "atrim=end=230.6,afade=t=out:st=229.9:d=0.7"
# --- berea de la bețiv: clinchetul sticlei, înghițiturile, râgâitul
unic bere_clinchet "Materials/glass_ping_small.wav"
unic bere_inghititura "Other/drink_slurp.wav"
unic bere_ragait "Human/belch_2.wav"
echo "Gata."

# --- coven-ul din vale: pistolul roz, cadavrul, cazanul, vraja, mătura
# împușcătura: pocnetul (zgomot alb care se stinge repede), bubuitul grav (sinus care coboară) și „shot_muffled”
# din pachet pentru corp, cu ecoul pădurii după
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=white:a=0.9:d=1.8:r=44100" \
	-f lavfi -i "aevalsrc=0.9*sin(2*PI*(45+260*exp(-t*35))*t)*exp(-t*9):s=44100:d=1.8" -i "$PACHET/Weapons/shot_muffled.wav" \
	-filter_complex "[0]volume='exp(-t*30)':eval=frame,highpass=f=300[c];[1]lowpass=f=400[b];[2]aformat=channel_layouts=mono,apad=pad_dur=1.8,atrim=end=1.8[m];[c][b][m]amix=inputs=3:normalize=0,aecho=0.8:0.6:140|360|780:0.35|0.22|0.12" \
	-ac 1 "$OUT/_impuscatura.wav"
unic pistol_impuscatura "$OUT/_impuscatura.wav"
unic pistol_primit "Weapons/weapon_pick_up.wav"
unic corp_cazut "Materials/clothing_thud.wav" mono "lowpass=f=1500,asetrate=44100*0.8,aresample=44100"
unic corp_luat "Materials/clothing_1.wav"
# --- sacrificiul din coven (cazan.gd): ca la trailerele de film, fiecare pas are sunetul lui și cresc unul din altul.
# Sunt CINEMATICE: ies la -13 LUFS (nu -20 ca restul), comprimate ca să fie „pline”, deci se aud clar peste pași și
# peste ambianță (pe care cazan.gd o și coboară cât ține vraja). Vârfurile le prinde limitatorul de pe Master.
# Cronologia din joc (cazan.gd): plescăit -> 0,9+0,5 s -> cor (4 s) -> la 1,5 s în cor, unda (exact 2,5 s, se termină cu
# o „gaură” de liniște) -> bubuitura. Dacă schimbi timpii din cazan.gd, schimbă și duratele de aici.
TINTA_NORMALA=$TINTA_LUFS
TINTA_LUFS=-13
DENS="acompressor=threshold=-26dB:ratio=3:attack=8:release=250:makeup=2"
# STEREO: mono -> stereo lat (Haas: dreapta întârziată 13 ms, ecouri diferite pe fiecare parte)
STEREO="asplit=2[st][dr];[st]aecho=0.8:0.6:230|520:0.25|0.15[st2];[dr]adelay=13,aecho=0.8:0.6:270|610:0.25|0.15[dr2];[st2][dr2]join=inputs=2:channel_layout=stereo"
# inima T AMPLITUDINE -> o bătaie de inimă „lub-dub” la secunda T: bufnitură joasă care cade de la 75 la 45 Hz (+ armonica a
# doua, ca să se audă și în căști mici), a doua bătaie la 0,17 s după, mai slabă
inima() {
	local T="$1" A="$2" T2 x
	T2=$(awk -v t="$T" 'BEGIN { printf "%.2f", t + 0.17 }')
	for x in "$T:$A" "$T2:$(awk -v a="$A" 'BEGIN { printf "%.3f", a * 0.65 }')"; do
		local t0="${x%%:*}" a="${x##*:}"
		local P="(45*(t-$t0)+1.2*(1-exp(-(t-$t0)*25)))"
		printf "+%s*gte(t\\\\,%s)*(sin(2*PI*%s)+0.35*sin(4*PI*%s))*exp(-(t-%s)*13)" "$a" "$t0" "$P" "$P" "$t0"
	done
}
# voce FRECVENTA FAZA_VIBRATO -> o voce de cor: ferăstrău blând (6 armonice) cu vibrato
voce() {
	local f="$1" ph="$2" s="" k
	for k in 1 2 3 4 5 6; do s="$s+sin(2*PI*$k*($f*t+$f*0.0025*sin(2*PI*5.3*t+$ph)))/$k"; done
	echo "(0$s)"
}

# 1. corpul cade în cazan (~2 s): pleoscăitul greu al poțiunii, carnea care se îneacă, o bufnitură joasă în pieptul tău,
# apoi poțiunea care „înghite” (bule mari, încetinite)
ffmpeg -v error -y -i "$PACHET/Environment/water_splashing.wav" -i "$PACHET/Combat and Gore/squelching_1.wav" -i "$PACHET/Weapons/harsh_thud.wav" \
	-f lavfi -i "aevalsrc='1.1*sin(2*PI*(60*t-14*t*t))*exp(-t*4.5)':s=44100:d=2" -i "$PACHET/Environment/gurgling.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.62,aresample=44100,lowpass=f=2600[a];[1]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,adelay=80,volume=0.7[b];[2]aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,lowpass=f=700,volume=1.1[c];[4]aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,lowpass=f=1200,atrim=end=1.3,afade=t=in:d=0.1,afade=t=out:st=0.9:d=0.4,adelay=550,volume=0.6[g];[a][b][c][3][g]amix=inputs=5:normalize=0:duration=longest,$DENS,aecho=0.7:0.5:110|260:0.3|0.18,atrim=end=2,afade=t=out:st=1.5:d=0.5" \
	-ac 1 "$OUT/_plescait.wav"
TINTA_LUFS=-15  # e 3D (vine din cazan, de la 1,4 m): puțin mai jos decât cele „de film”
unic cazan_plescait "$OUT/_plescait.wav"
TINTA_LUFS=-13

# 2. corul (3,9 s, se stinge înainte de liniștea din undă: poțiunea se face verde, vrăjitoarele ridică brațele): un cor de „aaa” pe un acord disonant (re, la, re, fa,
# sol diez = tritonul, dublat jos de un la grav), care se umflă de la nimic; sus, de la jumătate, două soprane la un semiton
# una de alta. Dedesubt o inimă care bate tot mai repede și mai tare (ritmul crește până la bubuitură) și un vuiet care urcă.
COR="0.13*($(voce 55 0.3)+$(voce 73.42 0)+$(voce 110 1.1)+$(voce 146.83 2.3)+$(voce 174.61 0.6)+$(voce 207.65 1.7))*pow(min(t/3.7\,1)\,1.8)"
SOPRANE="0.08*($(voce 587.33 0.4)+$(voce 622.25 2.0))*pow(max(0\,(t-1.6)/2.1)\,2)"
INIMA="0$(inima 0.30 0.25)$(inima 1.10 0.32)$(inima 1.80 0.40)$(inima 2.38 0.48)$(inima 2.86 0.56)$(inima 3.24 0.64)$(inima 3.55 0.72)"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$COR+$SOPRANE':s=44100:d=4" -f lavfi -i "aevalsrc='$INIMA':s=44100:d=4" \
	-f lavfi -i "anoisesrc=c=brown:a=0.8:d=4:r=44100:s=21" -i "$PACHET/Other/ghost_long.wav" \
	-filter_complex "[0]equalizer=f=700:t=q:w=1.2:g=8,equalizer=f=1150:t=q:w=1.5:g=5,lowpass=f=3200,chorus=0.6:0.9:40|55|70:0.4|0.35|0.3:0.3|0.4|0.5:2|2.5|1.7[c];[1]lowpass=f=300,volume=1.6[h];[2]lowpass=f=180,volume='pow(t/4\,2)*1.8':eval=frame[r];[3]aformat=channel_layouts=mono,areverse,asetrate=44100*0.7,aresample=44100,atrim=end=4,highpass=f=500,volume=0.35[g];[c][h][r][g]amix=inputs=4:normalize=0,$DENS,afade=t=in:d=0.6,$STEREO,afade=t=out:st=3.65:d=0.25,atrim=end=3.9" \
	-ac 2 "$OUT/_cor.wav"
unic vraja_cor "$OUT/_cor.wav" stereo

# 3. unda de lumină (EXACT 2,5 s, cât de la pornirea ei până la bubuitură în cazan.gd): lovitura „BRAAM” de film (un
# cluster de ferăstraie foarte jos, zdrențuit), pocnitura de aer de la pornire, sinusul care urcă (70 -> 600 Hz), șuieratul
# care crește și o explozie ÎNTOARSĂ care „trage aerul” spre bubuitură. La 2,42 s totul se taie: 80 ms de liniște
# absolută înainte de lovitură (trucul de trailer: liniștea face bubuitura să pară de două ori mai mare).
FINAL_UNDA=2.42
ffmpeg -v error -y -i "$PACHET/Retro/explosion_large.wav" -af "aformat=channel_layouts=mono,asetrate=44100*0.5,aresample=44100,areverse,lowpass=f=2500" "$OUT/_invers.wav"
L=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/_invers.wav")
INTARZIERE=$(awk -v l="$L" -v f="$FINAL_UNDA" 'BEGIN { d = (f - l) * 1000; if (d < 0) d = 0; printf "%d", d }')
TAIERE=$(awk -v l="$L" -v f="$FINAL_UNDA" 'BEGIN { s = l - f; if (s < 0) s = 0; printf "%.3f", s }')
BRAAM="0.24*($(voce 36.71 0)+$(voce 55 1)+$(voce 73.42 2)+$(voce 77.78 3))*min(t/0.02\,1)*exp(-t*0.8)"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$BRAAM':s=44100:d=2.5" \
	-f lavfi -i "aevalsrc=0.35*sin(2*PI*(70*t+106*t*t))*min(t*1.5\,1):s=44100:d=2.5" -f lavfi -i "anoisesrc=c=pink:a=0.35:d=2.5:r=44100:s=22" \
	-i "$PACHET/Retro/explosion_large.wav" -i "$PACHET/Musical Effects/horror_sting.wav" -i "$OUT/_invers.wav" \
	-filter_complex "[0]acrusher=bits=9:mix=0.35,lowpass=f=1400,volume=1.2[b];[1]tremolo=f=9:d=0.35,volume='0.6+0.6*t/2.4':eval=frame[s];[2]lowpass=f=2500,volume='pow(t/2.4\,2)*1.3':eval=frame[z];[3]aformat=channel_layouts=mono,asetrate=44100*0.45,aresample=44100,atrim=end=0.6,afade=t=out:st=0.2:d=0.4,lowpass=f=1000[x];[4]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,volume=0.6[h];[5]atrim=start=$TAIERE,asetpts=PTS-STARTPTS,adelay=$INTARZIERE,volume=1.3[w];[b][s][z][x][h][w]amix=inputs=6:normalize=0:duration=longest,$DENS,atrim=end=2.5,afade=t=out:st=$FINAL_UNDA:d=0.02,$STEREO,atrim=end=2.5" \
	-ac 2 "$OUT/_unda.wav"
# fără `unic`: acolo silenceremove i-ar mânca liniștea de la sfârșit? Nu (taie doar începutul), dar coada de ecou a lui
# STEREO ar umple gaura de liniște -> o golim din nou după normalizare.
g=$(castig_final "$OUT/_unda.wav" "anull")
ffmpeg -v error -y -i "$OUT/_unda.wav" -af "volume=${g}dB,$LIMITATOR,afade=t=out:st=$FINAL_UNDA:d=0.012" -ac 2 -c:a libvorbis -q:a 5 "$OUT/vraja_unda.ogg"
echo "vraja_unda.ogg  (2,5 s, liniște de la $FINAL_UNDA)"

# 4. bubuitura (~6,5 s): explozia mare (încetinită, și cea normală pentru pocnet), un bas care cade (75 -> 25 Hz) și se simte
# în piept, o lovitură de cor (tot acordul, atacat scurt, ca „stab”-urile din trailere), tunetul care se rostogolește prin
# pădure, alama de groază, carnea; apoi liniștea de după: inima ta, de două ori, rar, și vuietul care se stinge.
STAB="0.16*($(voce 55 0.3)+$(voce 73.42 0)+$(voce 110 1.1)+$(voce 146.83 2.3)+$(voce 207.65 1.7)+$(voce 293.66 0.9))*min(t/0.012\,1)*exp(-t*1.4)"
INIMA_DUPA="0$(inima 3.1 0.55)$(inima 4.3 0.4)"
ffmpeg -v error -y -i "$PACHET/Retro/explosion_large.wav" -f lavfi -i "aevalsrc='1.1*sin(2*PI*(75*t-5*t*t))*min(t/0.01\,1)*exp(-t*0.75)':s=44100:d=6.5" \
	-f lavfi -i "anoisesrc=c=brown:a=1:d=6.5:r=44100:s=23" -i "$PACHET/Musical Effects/brass_negative_long.wav" \
	-i "$PACHET/Musical Effects/horror_sting.wav" -i "$PACHET/Combat and Gore/crunch_splat.wav" \
	-f lavfi -i "aevalsrc='$STAB':s=44100:d=6.5" -f lavfi -i "aevalsrc='$INIMA_DUPA':s=44100:d=6.5" \
	-filter_complex "[0]aformat=channel_layouts=mono,asplit=2[e0][e1];[e0]asetrate=44100*0.5,aresample=44100,lowpass=f=1100,volume=1.2[e];[e1]highpass=f=200,volume=0.6[p];[2]lowpass=f=240,tremolo=f=2.7:d=0.45,volume='min(t/0.15\,1)*exp(-t*0.45)*1.7':eval=frame[t];[3]aformat=channel_layouts=mono,asetrate=44100*0.5,aresample=44100,lowpass=f=1500,adelay=150,volume=0.55[a];[4]aformat=channel_layouts=mono,asetrate=44100*0.45,aresample=44100,adelay=250,volume=0.45[h];[5]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,volume=0.4[g];[6]equalizer=f=700:t=q:w=1.2:g=8,equalizer=f=1150:t=q:w=1.5:g=5,lowpass=f=3500,chorus=0.6:0.9:40|55|70:0.4|0.35|0.3:0.3|0.4|0.5:2|2.5|1.7,volume=0.9[c];[7]lowpass=f=300,volume=1.5[i];[e][p][1][t][a][h][g][c][i]amix=inputs=9:normalize=0:duration=longest,$DENS,aecho=0.8:0.7:300|750|1300:0.35|0.25|0.15,atrim=end=6.5,afade=t=out:st=5:d=1.5,$STEREO" \
	-ac 2 "$OUT/_bum.wav"
unic vraja_bum "$OUT/_bum.wav" stereo
rm -f "$OUT"/_plescait.wav "$OUT"/_cor.wav "$OUT"/_unda.wav "$OUT"/_bum.wav "$OUT"/_invers.wav
TINTA_LUFS=$TINTA_NORMALA
unic matura_scoasa "Other/whoosh_1.wav" mono "lowpass=f=4000"
unic zbor_decolare "Other/whoosh_2.wav" mono "asetrate=44100*0.6,aresample=44100,lowpass=f=2500"
# cântecul vrăjitoarelor: un murmur grav din trei voci care se umflă și se sting, fiecare în ritmul ei
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.25*sin(2*PI*110*t)*(0.6+0.4*sin(2*PI*0.23*t)) + 0.2*sin(2*PI*164.8*t+0.4*sin(2*PI*5*t))*(0.5+0.5*sin(2*PI*0.17*t+1)) + 0.15*sin(2*PI*220.5*t+0.3*sin(2*PI*4.3*t))*(0.5+0.5*sin(2*PI*0.31*t+2)):s=44100:d=24" \
	-af "lowpass=f=900,chorus=0.6:0.9:50|60:0.4|0.32:0.25|0.4:2|1.3,aecho=0.7:0.6:300|700:0.3|0.2" -ac 1 "$OUT/_cant.wav"
bucla vrajitoare_cant "$OUT/_cant.wav" 2 mono anull tri
# focul de sub cazan: trosnete rare (impulsuri la întâmplare) peste un vuiet jos
ffmpeg -v error -y -f lavfi -i "aevalsrc='lt(random(1)\,0.0008)*(random(2)*2-1)':s=44100:d=10" \
	-f lavfi -i "anoisesrc=c=brown:a=0.12:d=10:r=44100" \
	-filter_complex "[0]highpass=f=700,aecho=0.6:0.4:20:0.3[t];[1]lowpass=f=400[v];[t][v]amix=inputs=2:normalize=0" -ac 1 "$OUT/_foc.wav"
bucla foc_trosnet "$OUT/_foc.wav" 1 mono
# --- boombox-ul împușcat: plasticul crapă, difuzorul pocnește, apoi scântei electrice și un bâzâit care se taie
ffmpeg -v error -y -i "$PACHET/Materials/cardboard_hit.wav" -i "$PACHET/Materials/pottery_clang.wav" \
	-f lavfi -i "aevalsrc='lt(random(1)\,0.02*exp(-t*2.5))*(random(2)*2-1)':s=44100:d=1.8" \
	-f lavfi -i "aevalsrc=0.25*sin(2*PI*100*t)*sgn(sin(2*PI*130*t))*lt(t\,0.9)*gt(sin(2*PI*7*t)\,-0.3):s=44100:d=1.8" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*1.25,aresample=44100,apad=pad_dur=1.8,atrim=end=1.8[p];[1]aformat=channel_layouts=mono,highpass=f=600,volume=0.5,apad=pad_dur=1.8,atrim=end=1.8[c];[2]highpass=f=1500,aecho=0.6:0.3:12:0.4,volume=0.8[s];[3]lowpass=f=3000,afade=t=out:st=0.6:d=0.3[b];[p][c][s][b]amix=inputs=4:normalize=0" \
	-ac 1 "$OUT/_boombox.wav"
unic boombox_stricat "$OUT/_boombox.wav"
rm -f "$OUT"/_boombox.wav
# --- antrenamentul cu mătura (afară, dimineața): vraja care nu prinde
# scantei_matura: o pârâitură de scântei + un „power up” care se îneacă la jumătate (o încercare ratată)
ffmpeg -v error -y -i "$PACHET/Retro/power_up.wav" \
	-f lavfi -i "aevalsrc='lt(random(1)\,0.05*exp(-t*4))*(random(2)*2-1)':s=44100:d=0.8" \
	-filter_complex "[0]aformat=channel_layouts=mono,atrim=end=0.35,afade=t=out:st=0.2:d=0.15,apad=pad_dur=0.8,atrim=end=0.8,volume=0.6[u];[1]highpass=f=1800,aecho=0.6:0.3:9:0.4[s];[u][s]amix=inputs=2:normalize=0" \
	-ac 1 "$OUT/_scantei.wav"
unic scantei_matura "$OUT/_scantei.wav"
# vraja_esuata: „power down” încetinit, ca un balon care se dezumflă, cu ultimele scântei
ffmpeg -v error -y -i "$PACHET/Retro/power_down.wav" \
	-f lavfi -i "aevalsrc='lt(random(1)\,0.015*exp(-t*1.5))*(random(2)*2-1)':s=44100:d=1.6" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,apad=pad_dur=1.6,atrim=end=1.6[d];[1]highpass=f=2000,volume=0.7[s];[d][s]amix=inputs=2:normalize=0" \
	-ac 1 "$OUT/_esuata.wav"
unic vraja_esuata "$OUT/_esuata.wav"
rm -f "$OUT"/_scantei.wav "$OUT"/_esuata.wav
# --- tomberonul din curte și bomboana găsită în el
# capacul de tablă care se ridică / cade la loc: zăngănit gros, înfundat
unic tomberon_capac "Materials/metal_clang.wav" mono "lowpass=f=2200,asetrate=44100*0.75,aresample=44100"
# răscolitul prin gunoi: hârtie mototolită, o cutie împinsă, la sfârșit o doză
ffmpeg -v error -y -i "$PACHET/Materials/paper_scrunch.wav" -i "$PACHET/Materials/cardboard_push.wav" -i "$PACHET/Materials/aluminium_can_pick_up.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono[h];[1]aformat=channel_layouts=mono,adelay=250,volume=0.7[c];[2]aformat=channel_layouts=mono,adelay=1000,lowpass=f=3500,volume=0.6[d];[h][c][d]amix=inputs=3:normalize=0,atrim=end=1.6,afade=t=out:st=1.3:d=0.3" \
	-ac 1 "$OUT/_rascolit.wav"
unic tomberon_rascolit "$OUT/_rascolit.wav"
rm -f "$OUT"/_rascolit.wav
# ambalajul desfăcut: celofan (hârtie mototolită, mai sus și mai scurt)
unic bomboana_ambalaj "Materials/paper_scrunch.wav" mono "highpass=f=1500,asetrate=44100*1.4,aresample=44100,atrim=end=0.6,afade=t=out:st=0.45:d=0.15"
# bomboana tare ronțăită (o mușcătură; în joc se cântă de mai multe ori, cu altă înălțime)
unic bomboana_ronta "Combat and Gore/crunch_quick.wav" mono "highpass=f=300,asetrate=44100*1.25,aresample=44100,lowpass=f=5000"
# --- telefonul (mesajul de la Lexy): sintetizate, în afară de buzunar
# vibrația: motorașul (165 Hz, „pătrat”, înfundat de buzunar), de două ori
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.5*sgn(sin(2*PI*165*t))*(lt(t\,0.38)+gt(t\,0.55)*lt(t\,0.93))*(0.85+0.15*sin(2*PI*9*t))':s=44100:d=1.1" \
	-af "lowpass=f=650,highpass=f=90" -ac 1 "$OUT/_vibratie.wav"
unic telefon_vibratie "$OUT/_vibratie.wav" stereo
# scos / băgat în buzunarul gecii: foșnet de haine
unic telefon_buzunar "Materials/clothing_1.wav" stereo "atrim=end=0.5,afade=t=out:st=0.35:d=0.15"
# notificarea: două note scurte, ca un clopoțel de telefon
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.4*sin(2*PI*1318*t)*exp(-t*22)+0.4*gt(t\,0.085)*sin(2*PI*1975*(t-0.085))*exp(-(t-0.085)*14)+0.1*sin(2*PI*2636*t)*exp(-t*30)':s=44100:d=0.5" \
	-ac 1 "$OUT/_notificare.wav"
unic telefon_notificare "$OUT/_notificare.wav" stereo
# tastele: un „tic” scurt de sticlă (zgomot de 6 ms + un sinus înalt)
ffmpeg -v error -y -f lavfi -i "aevalsrc='(random(0)*2-1)*exp(-t*700)*0.6+0.3*sin(2*PI*2400*t)*exp(-t*400)':s=44100:d=0.05" \
	-af "highpass=f=1200" -ac 1 "$OUT/_tasta.wav"
unic telefon_tasta "$OUT/_tasta.wav" stereo
# mesaj trimis: un „fâș” care urcă
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.5*sin(2*PI*(500*t+3500*t*t))*exp(-t*16)':s=44100:d=0.25" -ac 1 "$OUT/_trimis.wav"
unic telefon_trimis "$OUT/_trimis.wav" stereo
# mesaj primit (cu conversația deschisă): un „pop” care coboară
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.5*sin(2*PI*(1100*t-1800*t*t))*exp(-t*20)':s=44100:d=0.2" -ac 1 "$OUT/_primit.wav"
unic telefon_primit "$OUT/_primit.wav" stereo
rm -f "$OUT"/_vibratie.wav "$OUT"/_notificare.wav "$OUT"/_tasta.wav "$OUT"/_trimis.wav "$OUT"/_primit.wav
# --- la Lexy: jointul, pizza, canapeaua, televizorul cu știrile
# tras din joint: un șuierat de aer care crește (zgomot roz filtrat) și pârâitul hârtiei care arde
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.5:d=1.4:r=44100" \
	-f lavfi -i "aevalsrc='lt(random(1)\,0.006)*(random(2)*2-1)*0.8':s=44100:d=1.4" \
	-filter_complex "[0]bandpass=f=1400:t=h:w=1800,afade=t=in:st=0:d=0.9,afade=t=out:st=1.15:d=0.25,volume=0.7[a];[1]highpass=f=2500,afade=t=in:st=0.1:d=0.5,afade=t=out:st=1.0:d=0.4[c];[a][c]amix=inputs=2:normalize=0" \
	-ac 1 "$OUT/_tras.wav"
unic fum_tras "$OUT/_tras.wav"
# suflat: aer care iese lung și se stinge (mai jos decât trasul)
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.5:d=1.7:r=44100" \
	-af "bandpass=f=900:t=h:w=1200,afade=t=in:st=0:d=0.12,afade=t=out:st=0.3:d=1.35,volume=0.8" -ac 1 "$OUT/_suflat.wav"
unic fum_suflat "$OUT/_suflat.wav"
# jointul strivit în scrumieră: hârtia mototolită scurt + un sfârâit
ffmpeg -v error -y -i "$PACHET/Materials/paper_scrunch.wav" -f lavfi -i "anoisesrc=c=white:a=0.3:d=0.6:r=44100" \
	-filter_complex "[0]aformat=channel_layouts=mono,atrim=end=0.35,afade=t=out:st=0.25:d=0.1,highpass=f=800,apad=pad_dur=0.6,atrim=end=0.6[h];[1]highpass=f=3500,afade=t=out:st=0.05:d=0.5,adelay=120,atrim=end=0.6,volume=0.6[s];[h][s]amix=inputs=2:normalize=0" \
	-ac 1 "$OUT/_stins.wav"
unic joint_stins "$OUT/_stins.wav"
# o mușcătură de pizza: o bucată scurtă din molfăitul din pachet
unic pizza_muscatura "Other/munching_food.wav" mono "atrim=end=0.7,afade=t=out:st=0.5:d=0.2"
# te lași pe canapea: bufnitura hainelor, mai joasă (perne moi)
unic canapea_asezat "Materials/clothing_thud.wav" mono "asetrate=44100*0.8,aresample=44100,lowpass=f=2500"
# știrile de la televizor (buclă): o voce „de crainic” înfundată = zgomot filtrat pe benzile vocii, tăiat în
# silabe și fraze, prin difuzorul mic al televizorului, peste un fond muzical de știri foarte încet
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.6:d=12:r=44100" \
	-f lavfi -i "aevalsrc='(0.55+0.45*sin(2*PI*4.7*t+2*sin(2*PI*0.9*t)))*gt(sin(2*PI*0.23*t)+0.55\,0)*gt(sin(2*PI*0.61*t+1)+0.8\,0)':s=44100:d=12" \
	-f lavfi -i "aevalsrc='0.05*sin(2*PI*110*t)*(0.6+0.4*sin(2*PI*0.5*t))+0.03*sin(2*PI*165*t)+0.025*sin(2*PI*220*t)*gt(sin(2*PI*1*t)\,0)':s=44100:d=12" \
	-filter_complex "[0]bandpass=f=1000:t=h:w=1600,highpass=f=250[v];[v][1]amultiply[vo];[vo]equalizer=f=2500:t=q:w=1:g=6,lowpass=f=3200,highpass=f=280[voce];[2]lowpass=f=900[m];[voce][m]amix=inputs=2:normalize=0,aecho=0.6:0.4:18:0.2" \
	-ac 1 "$OUT/_stiri.wav"
bucla tv_stiri "$OUT/_stiri.wav" 1.5 mono
rm -f "$OUT"/_tras.wav "$OUT"/_suflat.wav "$OUT"/_stins.wav "$OUT"/_stiri.wav
# --- obiecte aruncate pe jos și puse pe raft
unic obiect_aruncat "Materials/wood_small_drop.wav"
unic obiect_pus "Materials/wood_small_hollow.wav" stereo
# --- jaful de la Lexy și gardul cimitirului
# bancnota scoasă din buzunar și întinsă: un foșnet scurt de hârtie
unic bancnota "Materials/paper_move.wav" mono "highpass=f=400"
# Lexy ridică mâinile, speriată: un foșnet scurt de haine, repede
unic maini_sus "Materials/clothing_2.wav" mono "atrim=end=0.45,afade=t=out:st=0.3:d=0.15,asetrate=44100*1.15,aresample=44100"
# corpul atinge vârfurile gardului de fier când trece peste el: un zăngănit înfundat
unic gard_zanganit "Materials/metal_clang.wav" mono "lowpass=f=2200,asetrate=44100*0.85,aresample=44100,afade=t=out:st=0.35:d=0.2"
rm -f "$OUT"/_impuscatura.wav "$OUT"/_unda.wav "$OUT"/_cant.wav "$OUT"/_foc.wav
# --- conacul coven-ului: mingea de foc (vraja Fireball) și vorba vrăjitoarelor din living room
# focul se aprinde în palmă: chibritul care ia foc, mai jos și mai plin
unic minge_foc_aprinsa "Environment/fire_lighting.wav" mono "asetrate=44100*0.8,aresample=44100,lowpass=f=3500"
# o arunci: un vâjâit scurt peste o pufăitură de flacără
ffmpeg -v error -y -i "$PACHET/Other/whoosh_2.wav" -i "$PACHET/Environment/fire_lighting.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*1.1,aresample=44100[w];[1]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,atrim=end=0.8,afade=t=out:st=0.5:d=0.3,volume=0.8[f];[w][f]amix=inputs=2:normalize=0,lowpass=f=4000" \
	-ac 1 "$OUT/_aruncata.wav"
unic minge_foc_aruncata "$OUT/_aruncata.wav"
# în zbor (buclă): vuietul flăcării = zgomot maro care fâlfâie, cu pârâituri rare
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:a=0.7:d=6:r=44100:s=7" \
	-f lavfi -i "aevalsrc='lt(random(3)\,0.004)*(random(4)*2-1)':s=44100:d=6" \
	-filter_complex "[0]lowpass=f=700,tremolo=f=11:d=0.45[v];[1]highpass=f=1200,aecho=0.5:0.3:6:0.4,volume=0.6[c];[v][c]amix=inputs=2:normalize=0" \
	-ac 1 "$OUT/_zbor.wav"
bucla minge_foc_zbor "$OUT/_zbor.wav" 1 mono
# lovește: o bubuitură joasă și flacăra care se umflă
ffmpeg -v error -y -i "$PACHET/Retro/explosion_medium.wav" -i "$PACHET/Environment/fire_lighting.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,lowpass=f=1400[b];[1]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,volume=0.7[f];[b][f]amix=inputs=2:normalize=0,aecho=0.7:0.5:90|210:0.25|0.15" \
	-ac 1 "$OUT/_bum.wav"
unic minge_foc_bum "$OUT/_bum.wav"
# vorba din living room (buclă): patru „voci” de femei (zgomot pe benzile vocii, tăiat în silabe, fiecare cu ritmul și
# înălțimea ei), care vorbesc una peste alta, într-o sală mare de lemn
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.6:d=14:r=44100:s=3" \
	-f lavfi -i "aevalsrc='(0.5+0.5*sin(2*PI*5.3*t+2*sin(2*PI*0.7*t)))*gt(sin(2*PI*0.19*t)+0.3\,0)':s=44100:d=14" \
	-f lavfi -i "anoisesrc=c=pink:a=0.6:d=14:r=44100:s=4" \
	-f lavfi -i "aevalsrc='(0.5+0.5*sin(2*PI*4.6*t+1+2*sin(2*PI*0.5*t)))*gt(sin(2*PI*0.23*t+2)+0.2\,0)':s=44100:d=14" \
	-f lavfi -i "anoisesrc=c=pink:a=0.6:d=14:r=44100:s=5" \
	-f lavfi -i "aevalsrc='(0.5+0.5*sin(2*PI*6.1*t+2+2*sin(2*PI*0.9*t)))*gt(sin(2*PI*0.17*t+4)+0.4\,0)':s=44100:d=14" \
	-filter_complex "[0]bandpass=f=1100:t=h:w=1200[a0];[a0][1]amultiply[a];[2]bandpass=f=1400:t=h:w=1300[b0];[b0][3]amultiply[b];[4]bandpass=f=900:t=h:w=1000[c0];[c0][5]amultiply[c];[a][b][c]amix=inputs=3:normalize=0,lowpass=f=2600,highpass=f=300,aecho=0.7:0.6:60|140|260:0.35|0.25|0.15" \
	-ac 1 "$OUT/_murmur.wav"
bucla conac_murmur "$OUT/_murmur.wav" 2 mono
rm -f "$OUT"/_aruncata.wav "$OUT"/_zbor.wav "$OUT"/_bum.wav "$OUT"/_murmur.wav

# --- pisica neagră din dormitorul conacului: torsul (buclă). În pachet nu e, așa că e sintetizat: ~25 de „bătăi” pe
# secundă de zgomot jos, expirația mai tare și mai lungă decât inspirația. 4 respirații de 2,2 s: lungimea e multiplu și
# de respirație, și de bătaie, deci bucla se leagă singură (fără crossfade și fără tăiat liniștea de la început).
ffmpeg -v error -y -f lavfi -i "aevalsrc='(random(0)*2-1)*pow(max(sin(2*PI*25*t)\,0)\,3)*if(lt(mod(t\,2.2)\,1.3)\,sqrt(sin(PI*mod(t\,2.2)/1.3))\,0.45*sqrt(sin(PI*(mod(t\,2.2)-1.3)/0.9)))':s=44100:d=8.8" \
	-af "lowpass=f=450,lowpass=f=450,highpass=f=30,equalizer=f=70:t=q:w=1:g=6" -ac 1 "$OUT/_tors.wav"
g=$(castig_final "$OUT/_tors.wav" "anull")
ffmpeg -v error -y -i "$OUT/_tors.wav" -af "volume=${g}dB,$LIMITATOR" -c:a libvorbis -q:a 5 "$OUT/pisica_tors.ogg"
rm -f "$OUT/_tors.wav"
echo "pisica_tors.ogg  (buclă)"

# --- pisica moartă, ceaunul de acasă care explodează și demonul de pe pentagramă (ceaun_acasa.gd, demon.gd)
# pisica împușcată: un miorlăit de durere, sintetizat (în pachet nu e nicio pisică): fundamentala urcă repede de la
# 650 la 950 Hz („mia-”), apoi coboară lung spre 450 („-uuu”), cu vibrato; armonicele trec prin „formanții” unei guri mici
FAZA="(if(lt(t\,0.15)\,650*t+1000*t*t\,120+950*(t-0.15)-384.6*(t-0.15)*(t-0.15))+0.4*sin(2*PI*7*t))"
ffmpeg -v error -y -f lavfi -i "aevalsrc='(sin(2*PI*$FAZA)+sin(4*PI*$FAZA)/2+sin(6*PI*$FAZA)/3+sin(8*PI*$FAZA)/4+sin(10*PI*$FAZA)/5)*min(1\,t/0.03)*if(gt(t\,0.55)\,max(0\,(0.85-t)/0.3)\,1)+(random(0)*2-1)*0.08*min(1\,t/0.03)*max(0\,1-t/0.85)':s=44100:d=0.85" \
	-af "equalizer=f=1200:t=q:w=1.5:g=9,equalizer=f=2700:t=q:w=2:g=5,highpass=f=350,lowpass=f=6500,aecho=0.6:0.3:25:0.2" -ac 1 "$OUT/_miau.wav"
unic pisica_moare "$OUT/_miau.wav"
# ceaunul se încinge (~4 s): fierberea tot mai repede, un huruit care crește și metalul care pocnește și scârțâie
ffmpeg -v error -y -i "$PACHET/Environment/water_boiling_loop.wav" -f lavfi -i "anoisesrc=c=brown:a=0.8:d=4.3:r=44100:s=11" \
	-i "$PACHET/Materials/metal_clang.wav" -i "$PACHET/Materials/pottery_clang.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,atrim=end=3.2,asetrate=44100*1.35,aresample=44100,afade=t=in:d=0.5,volume='0.5+0.5*t/2.4':eval=frame[f];[1]lowpass=f=160,volume='pow(t/4.3\,2)*2.2':eval=frame[h];[2]aformat=channel_layouts=mono,asplit=2[c0][c1];[c0]asetrate=44100*0.55,aresample=44100,lowpass=f=1800,adelay=1600,volume=0.45[m1];[3]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,lowpass=f=2500,adelay=3000,volume=0.5[m2];[c1]asetrate=44100*0.45,aresample=44100,lowpass=f=1200,adelay=3700,volume=0.6[m3];[f][h][m1][m2][m3]amix=inputs=5:normalize=0,atrim=end=4.3,afade=t=out:st=4.1:d=0.2" \
	-ac 1 "$OUT/_incins.wav"
unic ceaun_incins "$OUT/_incins.wav"
# explozia ceaunului: bubuitura mare (încetinită), fonta care se sparge, poțiunea care plesnește, apoi cioburile care
# cad prin cameră și un vuiet lung care se stinge, cu ecoul camerei
ffmpeg -v error -y -i "$PACHET/Retro/explosion_large.wav" -i "$PACHET/Materials/metal_clang.wav" \
	-i "$PACHET/Combat and Gore/crunch_splat.wav" -i "$PACHET/Materials/pottery_clang.wav" -f lavfi -i "anoisesrc=c=brown:a=1:d=3.5:r=44100:s=12" \
	-i "$PACHET/Materials/metal_blunt_tap.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,lowpass=f=1600[b];[1]aformat=channel_layouts=mono,asplit=2[k0][k1];[k0]asetrate=44100*0.8,aresample=44100,volume=0.7[m];[2]aformat=channel_layouts=mono,asetrate=44100*0.75,aresample=44100,volume=0.6[s];[3]aformat=channel_layouts=mono,asetrate=44100*1.1,aresample=44100,adelay=650,volume=0.35[c1];[k1]asetrate=44100*1.4,aresample=44100,adelay=900,volume=0.25[c2];[5]aformat=channel_layouts=mono,asetrate=44100*1.2,aresample=44100,adelay=1250,volume=0.3[c3];[4]lowpass=f=220,volume='exp(-t*1.3)*1.6':eval=frame[v];[b][m][s][c1][c2][c3][v]amix=inputs=7:normalize=0,aecho=0.7:0.5:70|160:0.3|0.2,atrim=end=3.5,afade=t=out:st=2.7:d=0.8" \
	-ac 1 "$OUT/_explozie.wav"
unic ceaun_explozie "$OUT/_explozie.wav"
# țiuitul din urechi după explozie: două sinusuri înalte, apropiate (bat ușor între ele), care se sting în 3,5 s
ffmpeg -v error -y -f lavfi -i "aevalsrc='(sin(2*PI*3700*t)+0.6*sin(2*PI*3745*t))*min(1\,t/0.05)*exp(-t*0.9)':s=44100:d=3.5" \
	-af "afade=t=out:st=2.8:d=0.7" -ac 1 "$OUT/_tiuit.wav"
unic tiuit "$OUT/_tiuit.wav"
# chemarea demonului (~8 s): un bas adânc care urcă din podea (două sinusuri joase care bat, zgomot maro), peste o
# fantomă întoarsă și încetinită, tot mai tare, cu un val la sfârșit
ffmpeg -v error -y -f lavfi -i "aevalsrc='(sin(2*PI*(38+6*t/8)*t)+0.7*sin(2*PI*(57+9*t/8)*t)+0.4*sin(2*PI*76*t))*min(1\,t/2.5)':s=44100:d=8" \
	-f lavfi -i "anoisesrc=c=brown:a=0.8:d=8:r=44100:s=13" -i "$PACHET/Other/ghost_long.wav" \
	-filter_complex "[0]volume=0.5,tremolo=f=0.6:d=0.3[s];[1]lowpass=f=260,volume='0.3+0.9*t/8':eval=frame[z];[2]aformat=channel_layouts=mono,areverse,asetrate=44100*0.55,aresample=44100,lowpass=f=1500,adelay=1200,volume=0.8[g];[s][z][g]amix=inputs=3:normalize=0,aecho=0.6:0.5:90|200:0.3|0.2,atrim=end=8,afade=t=in:d=1.5,afade=t=out:st=6.8:d=1.2" \
	-ac 1 "$OUT/_chemare.wav"
unic demon_chemare "$OUT/_chemare.wav"
# răcnetul demonului: o voce de bărbat încetinită de 2,5-3 ori, dublată de un mârâit (zgomot pe benzile vocii, „frânt” de
# un tremolo rapid) și un bas, cu ecoul camerei
ffmpeg -v error -y -i "$PACHET/Human/man_6.wav" -i "$PACHET/Human/man_4.wav" -f lavfi -i "anoisesrc=c=pink:a=0.8:d=2.2:r=44100:s=14" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.38,aresample=44100,lowpass=f=2000[v1];[1]aformat=channel_layouts=mono,asetrate=44100*0.32,aresample=44100,lowpass=f=1500,volume=0.8[v2];[2]bandpass=f=400:t=h:w=500,tremolo=f=38:d=0.9,volume='if(lt(t\,0.15)\,t/0.15\,exp(-(t-0.15)*1.6))':eval=frame[g];[v1][v2][g]amix=inputs=3:normalize=0,acrusher=bits=10:mix=0.25,equalizer=f=90:t=q:w=1:g=6,aecho=0.6:0.5:60|150:0.35|0.2,atrim=start=0.3:end=2.2,asetpts=PTS-STARTPTS,afade=t=out:st=1.4:d=0.5" \
	-ac 1 "$OUT/_raget.wav"
unic demon_raget "$OUT/_raget.wav"
# glonțul intră în demon: carne (pleoscăit gros), o pocnitură de os și un mormăit scurt de durere, foarte jos
ffmpeg -v error -y -i "$PACHET/Combat and Gore/squelching_3.wav" -i "$PACHET/Combat and Gore/bone_snap.wav" -i "$PACHET/Human/man_2.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.75,aresample=44100,volume=0.9[a];[1]aformat=channel_layouts=mono,volume=0.5[b];[2]aformat=channel_layouts=mono,asetrate=44100*0.42,aresample=44100,lowpass=f=1500,adelay=60,volume=0.8[c];[a][b][c]amix=inputs=3:normalize=0,atrim=end=1.0,afade=t=out:st=0.7:d=0.3" \
	-ac 1 "$OUT/_lovit.wav"
unic demon_lovit "$OUT/_lovit.wav"
# se dezintegrează (~4 s): urletul (vocea încetinită, din ce în ce mai jos), flacăra care îl cuprinde, sfârâitul
# și pârâitul jarului, apoi scrumul care se risipește
ffmpeg -v error -y -i "$PACHET/Human/man_6.wav" -i "$PACHET/Human/man_9.wav" -i "$PACHET/Environment/fire_lighting.wav" \
	-f lavfi -i "anoisesrc=c=white:a=0.5:d=4.2:r=44100:s=15" -i "$OUT/foc_trosnet.ogg" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.33,aresample=44100,lowpass=f=1800[u1];[1]aformat=channel_layouts=mono,asetrate=44100*0.26,aresample=44100,lowpass=f=1400,adelay=1100,volume=0.9[u2];[2]aformat=channel_layouts=mono,asetrate=44100*0.45,aresample=44100,volume=0.8[f];[3]highpass=f=3000,lowpass=f=9000,volume='0.25*min(1\,t/0.8)*max(0\,1-(t-2.4)/1.8)':eval=frame[s];[4]aformat=channel_layouts=mono,aresample=44100,atrim=end=4.2,volume='min(1\,t/0.6)*max(0\,1-(t-2.5)/1.7)':eval=frame[j];[u1][u2][f][s][j]amix=inputs=5:normalize=0,acrusher=bits=11:mix=0.2,aecho=0.6:0.5:70|170:0.3|0.2,atrim=end=4.2,afade=t=out:st=3.4:d=0.8" \
	-ac 1 "$OUT/_dezintegrare.wav"
unic demon_dezintegrare "$OUT/_dezintegrare.wav"
# se teleportează: un vâjâit care se strânge (zgomot care crește tot mai repede, ~0,5 s), o pocnitură de aer și o
# bufnitură joasă, apoi ecoul
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.8:d=0.55:r=44100:s=16" -i "$PACHET/Environment/air_burst.wav" -i "$PACHET/Weapons/harsh_thud.wav" \
	-filter_complex "[0]bandpass=f=900:t=h:w=1400,volume='pow(t/0.55\,3)*1.4':eval=frame[w];[1]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,adelay=520,volume=0.9[a];[2]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,lowpass=f=900,adelay=520,volume=0.9[t];[w][a][t]amix=inputs=3:normalize=0:duration=longest,aecho=0.6:0.5:80|190:0.35|0.2,atrim=end=1.8,afade=t=out:st=1.3:d=0.5" \
	-ac 1 "$OUT/_teleport.wav"
unic demon_teleport "$OUT/_teleport.wav"
rm -f "$OUT"/_miau.wav "$OUT"/_incins.wav "$OUT"/_explozie.wav "$OUT"/_tiuit.wav "$OUT"/_chemare.wav "$OUT"/_raget.wav \
	"$OUT"/_lovit.wav "$OUT"/_dezintegrare.wav "$OUT"/_teleport.wav

# --- atacul Warlock-ului asupra conacului (atac_conac.gd, sefa_ruine.gd): o scenă de film de ~50 s, deci sunete „de film”
# ca la sacrificiu: cele mari stereo, la -13 LUFS, comprimate ($DENS). Cele care vin dintr-un loc (fulgerele, vrăjile care
# lovesc, teleporturile) sunt mono (3D), tot la -13 (vrajă aruncată -14, sunt multe): armata e la 40 m, deci trebuie să
# răzbată (vezi și VrajaAtac.sunet_la: mixaj de film, distanța „trișată”). Muzica tristă de după e la -20, ca restul muzicii.
TINTA_NORMALA=$TINTA_LUFS
TINTA_LUFS=-13
# taiko T AMPLITUDINE -> o lovitură de tobă mare de război la secunda T: tonul cade de la ~130 la 40 Hz, plus pielea (zgomot scurt)
taiko() {
	local T="$1" A="$2"
	local P="(40*(t-$T)+3*(1-exp(-(t-$T)*30)))"
	printf "+%s*gte(t\\\\,%s)*(sin(2*PI*%s)*exp(-(t-%s)*6)+0.35*(random(0)*2-1)*exp(-(t-%s)*40))" "$A" "$T" "$P" "$T" "$T"
}
# 1. tunetul de departe (~6 s): se rostogolește prin dealuri, fără pocnet
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:a=1:d=6:r=44100:s=41" -f lavfi -i "anoisesrc=c=pink:a=0.6:d=6:r=44100:s=42" \
	-filter_complex "[0]lowpass=f=260,tremolo=f=2.3:d=0.55,volume='min(t/0.35\,1)*exp(-t*0.55)*2.2':eval=frame[a];[1]bandpass=f=500:t=h:w=600,tremolo=f=6:d=0.7,volume='min(t/0.2\,1)*exp(-t*1.4)*0.5':eval=frame[b];[a][b]amix=inputs=2:normalize=0,$DENS,aecho=0.8:0.7:400|900:0.3|0.2,atrim=end=6,afade=t=out:st=4.8:d=1.2,$STEREO" \
	-ac 2 "$OUT/_tunet.wav"
unic atac_tunet "$OUT/_tunet.wav" stereo
# 2. fulgerul care lovește aproape (~3 s, 3D): pocnetul (zgomot alb de 40 ms + pârâit de scântei), bubuitul jos și
# huruitul tunetului care se stinge
ffmpeg -v error -y -f lavfi -i "aevalsrc='(random(1)*2-1)*(exp(-t*90)+0.5*gt(random(2)\,0.93)*exp(-t*6))':s=44100:d=3" \
	-f lavfi -i "aevalsrc='1.1*sin(2*PI*(48*t+2*(1-exp(-t*20))))*min(t/0.005\,1)*exp(-t*3.5)':s=44100:d=3" -f lavfi -i "anoisesrc=c=brown:a=1:d=3:r=44100:s=43" \
	-filter_complex "[0]highpass=f=900,volume=1.2[c];[2]lowpass=f=220,tremolo=f=4:d=0.5,volume='min(t/0.05\,1)*exp(-t*1.2)*1.8':eval=frame[r];[c][1][r]amix=inputs=3:normalize=0,$DENS,aecho=0.7:0.6:260|640:0.3|0.18,atrim=end=3,afade=t=out:st=2.3:d=0.7" \
	-ac 1 "$OUT/_fulger.wav"
unic atac_fulger "$OUT/_fulger.wav"
# 3. cornul de război (~5 s): două alămuri grave (re, apoi la peste ea), care se umflă încet, cu ecoul dealurilor
CORN="0.3*($(voce 73.42 0)*min(t/0.8\,1)+0.8*$(voce 110 1.3)*min(max(t-0.9\,0)/0.6\,1))*if(lt(t\,3.6)\,1\,max(0\,1-(t-3.6)/0.9))"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$CORN':s=44100:d=5" \
	-af "equalizer=f=480:t=q:w=1:g=7,equalizer=f=950:t=q:w=1.4:g=4,lowpass=f=2200,chorus=0.6:0.9:30|45:0.4|0.3:0.3|0.45:1.5|2,$DENS,aecho=0.8:0.75:500|1100|1800:0.35|0.25|0.15,afade=t=out:st=4.4:d=0.6,$STEREO" \
	-ac 2 "$OUT/_corn.wav"
unic atac_corn "$OUT/_corn.wav" stereo
# 4. teleportul: apare un vrăjitor / o vrăjitoare (~1,4 s, 3D). Lovitura e la t = 0, exact când îl vezi (codul pornește
# sunetul în clipa apariției): pocnetul de aer, un bas care cade 95 -> 40 Hz (în piept), bufnitura, apoi aerul împins în
# afară (vâjâitul), pârâitul de energie care se stinge și sfârâitul focului, cu ecou.
ffmpeg -v error -y -f lavfi -i "aevalsrc='(random(1)*2-1)*exp(-t*70)':s=44100:d=1.4" \
	-f lavfi -i "aevalsrc='0.9*sin(2*PI*(95*t-45*t*t))*min(t/0.004\,1)*exp(-t*4)':s=44100:d=1.4" \
	-i "$PACHET/Weapons/harsh_thud.wav" -i "$PACHET/Other/whoosh_1.wav" \
	-f lavfi -i "aevalsrc='lt(random(3)\,0.012)*(random(4)*2-1)*exp(-t*3)':s=44100:d=1.4" -i "$PACHET/Environment/fire_lighting.wav" \
	-filter_complex "[0]highpass=f=1200[c];[2]aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,lowpass=f=900[t];[3]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,lowpass=f=2500,volume=0.7[w];[4]highpass=f=2500,volume=0.7[p];[5]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,volume=0.4[f];[c][1][t][w][p][f]amix=inputs=6:normalize=0:duration=first,$DENS,aecho=0.7:0.5:90|220:0.3|0.18,atrim=end=1.4,afade=t=out:st=1.0:d=0.4" \
	-ac 1 "$OUT/_aparitie.wav"
unic atac_aparitie "$OUT/_aparitie.wav"
# 5. sosirea Warlock-ului (~7 s): un vuiet care coboară din cer (3 s, tot mai tare), un cor grav care se umflă, apoi
# aterizarea: bubuitura mare, basul care cade, alama de groază încetinită, ecoul lung
COR_JOS="0.12*($(voce 36.71 0)+$(voce 55 1)+$(voce 73.42 2)+$(voce 77.78 0.5)+$(voce 110 1.7))*min(t/3\,1)*if(lt(t\,3)\,1\,exp(-(t-3)*0.7))"
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:a=1:d=7:r=44100:s=44" -f lavfi -i "aevalsrc='$COR_JOS':s=44100:d=7" \
	-i "$PACHET/Retro/explosion_large.wav" -f lavfi -i "aevalsrc='1.2*gte(t\,3)*sin(2*PI*(60*(t-3)-4*(t-3)*(t-3)))*exp(-(t-3)*0.8)':s=44100:d=7" \
	-i "$PACHET/Musical Effects/horror_sting.wav" \
	-filter_complex "[0]lowpass=f=400,volume='if(lt(t\,3)\,pow(t/3\,2.5)*1.6\,exp(-(t-3)*1.5)*1.6)':eval=frame[v];[1]equalizer=f=600:t=q:w=1.2:g=6,lowpass=f=2500,chorus=0.6:0.9:40|55:0.4|0.35:0.3|0.4:2|2.5[c];[2]aformat=channel_layouts=mono,asetrate=44100*0.42,aresample=44100,lowpass=f=1200,adelay=3000,volume=1.3[e];[4]aformat=channel_layouts=mono,asetrate=44100*0.5,aresample=44100,adelay=3100,volume=0.6[h];[v][c][e][3][h]amix=inputs=5:normalize=0:duration=longest,$DENS,aecho=0.8:0.7:350|800|1400:0.35|0.25|0.15,atrim=end=7,afade=t=out:st=5.8:d=1.2,$STEREO" \
	-ac 2 "$OUT/_sosire.wav"
unic warlock_sosire "$OUT/_sosire.wav" stereo
# 6. o vrajă aruncată (~1 s, 3D): o bufnitură joasă la lansare (85 -> 55 Hz, „recul”), vâjâitul și sfârâitul focului
ffmpeg -v error -y -i "$PACHET/Other/whoosh_2.wav" -i "$PACHET/Environment/fire_lighting.wav" \
	-f lavfi -i "aevalsrc='0.7*sin(2*PI*(85*t-30*t*t))*min(t/0.005\,1)*exp(-t*9)':s=44100:d=1.1" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*1.25,aresample=44100,highpass=f=200[w];[1]aformat=channel_layouts=mono,asetrate=44100*1.5,aresample=44100,volume=0.6[f];[w][f][2]amix=inputs=3:normalize=0:duration=longest,$DENS,atrim=end=1.1,afade=t=out:st=0.7:d=0.4" \
	-ac 1 "$OUT/_vraja.wav"
TINTA_LUFS=-14
unic atac_vraja "$OUT/_vraja.wav"
# 7. vraja lovește piatra (~2,4 s, 3D): explozia, pietrele care se rup și cad, praful
ffmpeg -v error -y -i "$PACHET/Retro/explosion_medium.wav" -i "$PACHET/Materials/stone_push_short.wav" -i "$PACHET/Combat and Gore/crunch.wav" \
	-i "$PACHET/Materials/concrete_scrape.wav" -f lavfi -i "anoisesrc=c=brown:a=1:d=2.4:r=44100:s=45" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,lowpass=f=2500,volume=1.1[e];[1]aformat=channel_layouts=mono,asetrate=44100*0.75,aresample=44100,adelay=120,volume=0.8[s];[2]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,adelay=60,volume=0.7[c];[3]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,adelay=400,volume=0.5[r];[4]lowpass=f=200,volume='exp(-t*2)*1.4':eval=frame[v];[e][s][c][r][v]amix=inputs=5:normalize=0:duration=longest,$DENS,aecho=0.7:0.5:180|420:0.3|0.18,atrim=end=2.4,afade=t=out:st=1.8:d=0.6" \
	-ac 1 "$OUT/_impact.wav"
TINTA_LUFS=-13
unic atac_impact "$OUT/_impact.wav"
# 8. tobele de război (buclă de 4,8 s, 100 bpm): taiko-uri mari în ritm de marș. Facem trei măsuri cu ecou și o păstrăm pe
# cea din mijloc: ecoul măsurii dinainte cade peste începutul ei, deci bucla se leagă singură.
TOBE="0"
for m in 0 1 2; do
	for x in "0:1" "0.6:0.55" "0.9:0.5" "1.2:0.9" "2.4:1" "3.0:0.55" "3.3:0.5" "3.6:0.8" "4.2:0.7" "4.5:0.4"; do
		TOBE="$TOBE$(taiko $(awk -v a="${x%%:*}" -v m=$m 'BEGIN { printf "%.2f", a + m * 4.8 }') ${x##*:})"
	done
done
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.45*($TOBE)':s=44100:d=14.4" \
	-af "lowpass=f=1800,equalizer=f=70:t=q:w=1:g=5,$DENS,aecho=0.8:0.6:220|520:0.3|0.18,atrim=start=4.8:end=9.6,asetpts=PTS-STARTPTS,$STEREO,atrim=end=4.8" \
	-ac 2 "$OUT/_tobe.wav"
TINTA_LUFS=-17
g=$(castig_final "$OUT/_tobe.wav" "anull")
ffmpeg -v error -y -i "$OUT/_tobe.wav" -af "volume=${g}dB,$LIMITATOR" -c:a libvorbis -q:a 5 "$OUT/atac_tobe.ogg"
echo "atac_tobe.ogg  (buclă, 4,8 s)"
TINTA_LUFS=-13
# 9. scutul lui Head Witch (~1,6 s): un acord înalt care sclipește (tremolo repede) și urcă, cu un vâjâit
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.2*(sin(2*PI*(660+220*t)*t)+sin(2*PI*(990+330*t)*t)+0.7*sin(2*PI*(1320+440*t)*t))*(0.6+0.4*sin(2*PI*17*t))*min(t/0.3\,1)*exp(-t*1.2)':s=44100:d=1.6" \
	-i "$PACHET/Other/whoosh_1.wav" \
	-filter_complex "[1]aformat=channel_layouts=mono,asetrate=44100*1.2,aresample=44100,volume=0.5[w];[0][w]amix=inputs=2:normalize=0:duration=first,chorus=0.6:0.9:20|35:0.4|0.3:0.4|0.5:2|3,aecho=0.6:0.5:120|260:0.3|0.2,afade=t=out:st=1.2:d=0.4,$STEREO" \
	-ac 2 "$OUT/_scut.wav"
unic scut "$OUT/_scut.wav" stereo
# 10. scutul se sparge (~2 s): sticla (clinchete înalte, multe), pocnitura și zgomotul care se împrăștie
ffmpeg -v error -y -i "$PACHET/Materials/glass_ping_big.wav" -i "$PACHET/Materials/glass_ping_small.wav" -i "$PACHET/Combat and Gore/crunch_splat_2.wav" \
	-f lavfi -i "anoisesrc=c=white:a=0.8:d=2:r=44100:s=46" \
	-filter_complex "[0]aformat=channel_layouts=mono,asplit=2[g0][g1];[g0]asetrate=44100*0.8,aresample=44100[a];[g1]asetrate=44100*1.3,aresample=44100,adelay=90,volume=0.7[b];[1]aformat=channel_layouts=mono,asetrate=44100*1.6,aresample=44100,adelay=160,volume=0.6[c];[2]aformat=channel_layouts=mono,asetrate=44100*1.2,aresample=44100,volume=0.6[d];[3]highpass=f=2500,volume='exp(-t*5)*0.6':eval=frame[n];[a][b][c][d][n]amix=inputs=5:normalize=0:duration=longest,aecho=0.6:0.5:90|210:0.35|0.2,atrim=end=2,afade=t=out:st=1.4:d=0.6,$STEREO" \
	-ac 2 "$OUT/_spart.wav"
unic scut_spart "$OUT/_spart.wav" stereo
# 11. vraja mare se încarcă (~8,5 s): un vuiet care crește, un sinus care urcă (40 -> 160 Hz), pârâit de energie tot mai
# des, corul grav care se umflă și o inimă care bate tot mai repede. Se termină în vârf (pleacă vraja).
COR_URCA="0.1*($(voce 55 0.3)+$(voce 73.42 0)+$(voce 77.78 1.1)+$(voce 110 2.3)+$(voce 116.54 0.6))*pow(t/8.5\,1.6)"
INIMA_URCA="0$(inima 0.8 0.3)$(inima 2.0 0.35)$(inima 3.0 0.4)$(inima 3.8 0.48)$(inima 4.5 0.55)$(inima 5.1 0.62)$(inima 5.6 0.7)$(inima 6.05 0.76)$(inima 6.45 0.82)$(inima 6.8 0.88)$(inima 7.12 0.94)$(inima 7.42 1.0)$(inima 7.7 1.0)$(inima 7.96 1.0)"
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:a=1:d=8.5:r=44100:s=47" -f lavfi -i "aevalsrc='0.45*sin(2*PI*(40*t+7*t*t))*pow(t/8.5\,1.3)':s=44100:d=8.5" \
	-f lavfi -i "aevalsrc='(random(3)*2-1)*gt(random(4)\,0.995-0.04*t/8.5)*pow(t/8.5\,1.2)':s=44100:d=8.5" -f lavfi -i "aevalsrc='$COR_URCA':s=44100:d=8.5" \
	-f lavfi -i "aevalsrc='$INIMA_URCA':s=44100:d=8.5" \
	-filter_complex "[0]lowpass=f=350,volume='pow(t/8.5\,1.8)*2':eval=frame[v];[2]highpass=f=1500,volume=0.5[p];[3]equalizer=f=650:t=q:w=1.2:g=7,lowpass=f=2800,chorus=0.6:0.9:40|55|70:0.4|0.35|0.3:0.3|0.4|0.5:2|2.5|1.7[c];[4]lowpass=f=300,volume=1.5[i];[v][1][p][c][i]amix=inputs=5:normalize=0,$DENS,afade=t=in:d=1,$STEREO,atrim=end=8.5" \
	-ac 2 "$OUT/_incarcare.wav"
unic orb_incarcare "$OUT/_incarcare.wav" stereo
# 12. vraja mare zboară pe deasupra ta (~2,6 s): un vâjâit uriaș care vine din față, trece și pleacă (tonul cade, ca la
# o mașină care trece), cu vuietul focului
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=1:d=2.6:r=44100:s=48" -f lavfi -i "aevalsrc='0.6*sin(2*PI*(110*t-18*t*t))*exp(-pow((t-1.3)/0.55\,2))':s=44100:d=2.6" \
	-i "$PACHET/Environment/fire_lighting.wav" \
	-filter_complex "[0]lowpass=f=1800,highpass=f=80,volume='exp(-pow((t-1.3)/0.5\,2))*2.2':eval=frame[w];[2]aformat=channel_layouts=mono,asetrate=44100*0.5,aresample=44100,adelay=900,volume=0.7[f];[w][1][f]amix=inputs=3:normalize=0:duration=first,$DENS,afade=t=out:st=2.2:d=0.4,$STEREO" \
	-ac 2 "$OUT/_orb_zbor.wav"
unic orb_zbor "$OUT/_orb_zbor.wav" stereo
# 13. vraja mare lovește conacul (~8 s): bubuitura (explozia încetinită de 2,5 ori + pocnetul normal), basul care cade
# 60 -> 18 Hz și se simte în piept, zidurile care se prăbușesc (piatră, sticlă), tunetul care se rostogolește, alama de groază
ffmpeg -v error -y -i "$PACHET/Retro/explosion_large.wav" -f lavfi -i "aevalsrc='1.3*sin(2*PI*(60*t-3*t*t))*min(t/0.008\,1)*exp(-t*0.6)':s=44100:d=8" \
	-f lavfi -i "anoisesrc=c=brown:a=1:d=8:r=44100:s=49" -i "$PACHET/Materials/stone_push_long.wav" -i "$PACHET/Combat and Gore/crunch_splat.wav" \
	-i "$PACHET/Materials/glass_ping_big.wav" -i "$PACHET/Musical Effects/brass_negative_long.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asplit=2[e0][e1];[e0]asetrate=44100*0.4,aresample=44100,lowpass=f=900,volume=1.4[e];[e1]volume=0.8[p];[2]lowpass=f=200,tremolo=f=2.2:d=0.5,volume='min(t/0.1\,1)*exp(-t*0.4)*2':eval=frame[t];[3]aformat=channel_layouts=mono,asetrate=44100*0.6,aresample=44100,lowpass=f=1500,adelay=500,volume=0.9[s];[4]aformat=channel_layouts=mono,asetrate=44100*0.5,aresample=44100,adelay=200,volume=0.7[c];[5]aformat=channel_layouts=mono,asetrate=44100*0.9,aresample=44100,adelay=350,volume=0.35[g];[6]aformat=channel_layouts=mono,asetrate=44100*0.45,aresample=44100,lowpass=f=1200,adelay=300,volume=0.5[a];[e][p][1][t][s][c][g][a]amix=inputs=8:normalize=0:duration=longest,$DENS,aecho=0.8:0.75:300|750|1400:0.4|0.28|0.16,atrim=end=8,afade=t=out:st=6:d=2,$STEREO" \
	-ac 2 "$OUT/_orb_bum.wav"
unic orb_explozie "$OUT/_orb_bum.wav" stereo
# 14. leșinul: inima care încetinește (~5 s), înfundată ca prin vată
INIMA_LENTA="0$(inima 0.1 1.0)$(inima 1.15 0.85)$(inima 2.45 0.65)$(inima 4.0 0.45)"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$INIMA_LENTA':s=44100:d=5" -af "lowpass=f=220,aecho=0.6:0.4:90:0.25,afade=t=out:st=4.4:d=0.6,$STEREO" \
	-ac 2 "$OUT/_inima.wav"
unic inima_lenta "$OUT/_inima.wav" stereo
TINTA_LUFS=$TINTA_NORMALA
# 15. muzica de după atac (buclă de 32 s): un pad trist în re minor (Dm - Bb - Gm - A), câte 8 s pe acord, cu tranziții
# lungi între ele, un bas jos și ecou de catedrală. Ferestrele acordurilor se socotesc cu mod(t, 32), deci se leagă singură.
acord() {  # acord START NOTE... -> vocile acordului care ține de la START la START+8 (fereastră netedă pe 32 s)
	local s="$1"; shift
	local w="pow(sin(PI*min(max(mod(t-$s+1+32\,32)/10\,0)\,1))\,2)"
	local v="" f
	for f in "$@"; do v="$v+(sin(2*PI*$f*t)+0.3*sin(4*PI*$f*t)+0.12*sin(6*PI*$f*t))"; done
	echo "+$w*(0$v)"
}
PAD="0.07*(0$(acord 0 73.42 146.83 174.61 220 293.66)$(acord 8 58.27 116.54 146.83 174.61 233.08)$(acord 16 49 98 116.54 146.83 196)$(acord 24 55 110 138.59 164.81 220))"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$PAD*(0.85+0.15*sin(2*PI*0.25*t))':s=44100:d=34" \
	-af "lowpass=f=1600,chorus=0.6:0.9:45|60|75:0.4|0.35|0.3:0.25|0.35|0.45:2|2.5|1.7,aecho=0.8:0.8:700|1500|2600:0.35|0.25|0.18,atrim=end=34,$STEREO" \
	-ac 2 "$OUT/_tristete.wav"
bucla atac_tristete "$OUT/_tristete.wav" 2 stereo anull tri
rm -f "$OUT"/_tunet.wav "$OUT"/_fulger.wav "$OUT"/_corn.wav "$OUT"/_aparitie.wav "$OUT"/_sosire.wav "$OUT"/_vraja.wav "$OUT"/_impact.wav \
	"$OUT"/_tobe.wav "$OUT"/_scut.wav "$OUT"/_spart.wav "$OUT"/_incarcare.wav "$OUT"/_orb_zbor.wav "$OUT"/_orb_bum.wav "$OUT"/_inima.wav "$OUT"/_tristete.wav

# --- casino-ul din spălătorie (poker, păcănele, mașini de spălat); rulează doar secțiunea asta cu funcțiile de sus
TINTA_LUFS=-20
unic carti_amestecate "Card and Board/card_fan.wav"
unic carte_impartita "Card and Board/card_draw_1.wav"
unic carte_intoarsa "Card and Board/card_draw_3.wav" mono "asetrate=44100*1.15,aresample=44100"
unic jetoane_puse "Card and Board/chips_place_1.wav"
unic jetoane_stranse "Card and Board/chips_gather.wav"
unic bataie_masa "Other/subtle_knock.wav" mono "lowpass=f=2500"
unic poker_castig "Musical Effects/vibraphone_chime_positive.wav" stereo
unic poker_pierdere "Musical Effects/vibraphone_negative_quick.wav" stereo
unic pacanea_oprire "UI/click_double_off.wav" stereo "lowpass=f=3500,asetrate=44100*0.8,aresample=44100"
unic pacanea_castig "Musical Effects/8_bit_chime_positive.wav" stereo
unic pacanea_numarare "Retro/coin.wav" stereo
unic clopotel_usa "Items/jingle_bells_1.wav" mono "atrim=end=1.2,afade=t=out:st=0.8:d=0.4"
# rolele care se învârt: clicuri dese (18 pe secundă) peste un vâjâit subțire, buclă de 2 s
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.6*exp(-mod(t\,1/18)*180)*sin(2*PI*2400*t)':s=44100:d=4" -f lavfi -i "anoisesrc=c=pink:a=0.12:d=4:r=44100" \
	-filter_complex "[1]bandpass=f=1800:t=h:w=1500[z];[0][z]amix=inputs=2:normalize=0,lowpass=f=6000" -ac 2 "$OUT/_role.wav"
bucla pacanea_rulare "$OUT/_role.wav" 0.3 stereo
# mașina de spălat: motorul (50 Hz + armonice), apa care plescăie în tambur (în ritmul învârtitului), huruitul carcasei
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.22*sin(2*PI*50*t)+0.1*sin(2*PI*100*t)+0.05*sin(2*PI*150*t)':s=44100:d=8" \
	-i "$PACHET/Environment/water_babbling_loop.wav" -f lavfi -i "anoisesrc=c=brown:a=0.3:d=8:r=44100" \
	-filter_complex "[1]aformat=channel_layouts=mono,aloop=loop=-1:size=2e6,atrim=end=8,lowpass=f=1500,volume='0.6+0.4*sin(2*PI*0.5*t)':eval=frame[a];[2]lowpass=f=180,volume='0.7+0.3*sin(2*PI*0.5*t)':eval=frame[h];[0][a][h]amix=inputs=3:normalize=0" \
	-ac 1 "$OUT/_masina.wav"
bucla masina_spalat "$OUT/_masina.wav" 1.0 mono
# uscătoarele: huruit jos și rufele care cad în tambur (bufnituri moi, neregulate)
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:a=0.5:d=8:r=44100:s=7" -f lavfi -i "aevalsrc='0.5*exp(-mod(t\,0.83)*25)*sin(2*PI*70*t)+0.3*exp(-mod(t+0.31\,1.21)*30)*sin(2*PI*90*t)':s=44100:d=8" \
	-filter_complex "[0]lowpass=f=250[h];[h][1]amix=inputs=2:normalize=0,lowpass=f=600" -ac 1 "$OUT/_uscator.wav"
bucla uscator "$OUT/_uscator.wav" 1.0 mono
# camera de joc: liniștea unei încăperi închise, ventilatorul din tavan (vâjâit care pulsează)
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.4:d=8:r=44100:s=11" -af "lowpass=f=700,highpass=f=60,volume='0.75+0.25*sin(2*PI*3.1*t)':eval=frame" -ac 2 "$OUT/_camera.wav"
bucla camera_joc "$OUT/_camera.wav" 1.0 stereo
rm -f "$OUT/_role.wav" "$OUT/_masina.wav" "$OUT/_uscator.wav" "$OUT/_camera.wav"

# --- magazinul de arme „Freedom” (Gun Store): armele (cuțitul, shotgun-ul, AK-47, bazooka cu explozia), vânzătorul.
# Rulează doar secțiunea asta cu funcțiile de sus. Împușcăturile sunt sintetizate peste „shot_muffled” (în pachet nu
# sunt arme de foc), ca pistolul roz; explozia e „de film”, ca vraja din coven.
TINTA_LUFS=-20
unic arma_scoasa "Weapons/weapon_equip.wav"
unic arma_pe_tejghea "Weapons/weapon_drop.wav" mono "lowpass=f=4000"
unic tub_cazut "Materials/metal_blunt_tap.wav" mono "asetrate=44100*1.7,aresample=44100,highpass=f=900,atrim=end=0.25"
unic cutit_fasait "Combat and Gore/swipe.wav" mono "highpass=f=300"
ffmpeg -v error -y -i "$PACHET/Combat and Gore/squelching_2.wav" -i "$PACHET/Materials/cork_stabbed.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,atrim=end=0.6,volume=0.8[a];[1]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100[b];[a][b]amix=inputs=2:normalize=0,afade=t=out:st=0.4:d=0.2" \
	-ac 1 "$OUT/_carne.wav"
unic cutit_carne "$OUT/_carne.wav"
unic cutit_perete "Weapons/sword_clash.wav" mono "asetrate=44100*1.15,aresample=44100,atrim=end=0.5,afade=t=out:st=0.3:d=0.2"
# shotgun-ul: bubuitura (zgomot care se stinge, un bas care cade 215 -> 35 Hz), „shot_muffled” încetinit pentru corp,
# ecoul lung al străzii; apoi pompa: clic-clac (alunecarea înapoi, apoi înainte)
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=white:a=1:d=2.2:r=44100:s=31" \
	-f lavfi -i "aevalsrc=1.0*sin(2*PI*(35+180*exp(-t*18))*t)*exp(-t*4.5):s=44100:d=2.2" -i "$PACHET/Weapons/shot_muffled.wav" \
	-filter_complex "[0]volume='exp(-t*14)':eval=frame,highpass=f=180,lowpass=f=7000[c];[1]lowpass=f=320[b];[2]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,apad=pad_dur=2.2,atrim=end=2.2[m];[c][b][m]amix=inputs=3:normalize=0,aecho=0.8:0.65:110|290|640:0.4|0.26|0.14,afade=t=out:st=1.6:d=0.6" \
	-ac 1 "$OUT/_shotgun.wav"
unic shotgun_foc "$OUT/_shotgun.wav"
ffmpeg -v error -y -i "$PACHET/Other/slide_and_click.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,asplit=2[a][b];[a]asetrate=44100*0.8,aresample=44100,atrim=end=0.22[a2];[b]asetrate=44100*1.0,aresample=44100,atrim=end=0.25,adelay=170[b2];[a2][b2]amix=inputs=2:normalize=0:duration=longest,lowpass=f=6000" \
	-ac 1 "$OUT/_pompa.wav"
unic shotgun_pompa "$OUT/_pompa.wav"
# AK-47: un pocnet scurt și sec (zgomot care piere în 25 ms, un bas care cade, „shot_muffled” mai sus), ecou scurt
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=white:a=1:d=0.7:r=44100:s=37" \
	-f lavfi -i "aevalsrc=0.9*sin(2*PI*(55+420*exp(-t*45))*t)*exp(-t*11):s=44100:d=0.7" -i "$PACHET/Weapons/shot_muffled.wav" \
	-filter_complex "[0]volume='exp(-t*38)':eval=frame,highpass=f=450,lowpass=f=8000[c];[1]lowpass=f=500[b];[2]aformat=channel_layouts=mono,asetrate=44100*1.15,aresample=44100,apad=pad_dur=0.7,atrim=end=0.7,volume=0.8[m];[c][b][m]amix=inputs=3:normalize=0,aecho=0.7:0.5:70|170:0.3|0.15,afade=t=out:st=0.45:d=0.25" \
	-ac 1 "$OUT/_ak.wav"
unic ak_foc "$OUT/_ak.wav"
unic ak_incarcator_scos "Weapons/weapon_unequip.wav"
unic ak_incarcator_pus "Environment/lock_quick.wav" mono "asetrate=44100*0.85,aresample=44100"
unic ak_armat "Other/slide_and_click.wav" mono "asetrate=44100*1.2,aresample=44100"
# bazooka: lansarea (bufnitura joasă, aerul care țâșnește, vâjâitul care pleacă), reîncărcarea (clinchet metalic, zăvor)
ffmpeg -v error -y -i "$PACHET/Environment/air_burst.wav" -i "$PACHET/Other/whoosh_2.wav" \
	-f lavfi -i "aevalsrc=1.0*sin(2*PI*(40+120*exp(-t*12))*t)*exp(-t*5):s=44100:d=2.0" -f lavfi -i "anoisesrc=c=pink:a=0.8:d=2.0:r=44100:s=41" \
	-filter_complex "[0]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100[a];[1]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,adelay=60[w];[2]lowpass=f=260[b];[3]bandpass=f=1600:t=h:w=2400,volume='exp(-t*2.2)*0.9':eval=frame[z];[a][w][b][z]amix=inputs=4:normalize=0:duration=longest,aecho=0.7:0.5:150|380:0.3|0.15,atrim=end=2.0,afade=t=out:st=1.4:d=0.6" \
	-ac 1 "$OUT/_lansare.wav"
unic bazooka_lansare "$OUT/_lansare.wav"
ffmpeg -v error -y -i "$PACHET/Materials/metal_clang.wav" -i "$PACHET/Environment/lock_lock.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,asetrate=44100*0.75,aresample=44100,atrim=end=0.6,volume=0.6[a];[1]aformat=channel_layouts=mono,adelay=120[b];[a][b]amix=inputs=2:normalize=0:duration=longest,afade=t=out:st=0.6:d=0.3" \
	-ac 1 "$OUT/_incarcare.wav"
unic bazooka_incarcare "$OUT/_incarcare.wav"
# racheta în zbor: un șuierat de motor (zgomot în bandă, cu un tremur rapid) peste un huruit, buclă de 2 s
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=white:a=0.7:d=4:r=44100:s=43" -f lavfi -i "anoisesrc=c=brown:a=0.6:d=4:r=44100:s=47" \
	-filter_complex "[0]bandpass=f=2200:t=h:w=2600,tremolo=f=23:d=0.35[s];[1]lowpass=f=200[h];[s][h]amix=inputs=2:normalize=0" -ac 1 "$OUT/_racheta.wav"
bucla racheta_zbor "$OUT/_racheta.wav" 0.5 mono
# explozia rachetei (~6 s, „super powerful”): bubuitura mare (explozia încetinită + pocnetul normal), basul care cade
# 55 -> 18 Hz și se simte în piept, vuietul care se rostogolește, molozul și sticla care cad, ecoul lung al străzii
TINTA_LUFS=-13
ffmpeg -v error -y -i "$PACHET/Retro/explosion_large.wav" -f lavfi -i "aevalsrc='1.3*sin(2*PI*(55*t-3*t*t))*min(t/0.006\,1)*exp(-t*0.7)':s=44100:d=6.5" \
	-f lavfi -i "anoisesrc=c=brown:a=1:d=6.5:r=44100:s=53" -i "$PACHET/Materials/stone_push_short.wav" -i "$PACHET/Combat and Gore/crunch_splat.wav" \
	-i "$PACHET/Materials/glass_ping_big.wav" -i "$PACHET/Retro/explosion_medium.wav" \
	-filter_complex "[0]aformat=channel_layouts=mono,asplit=2[e0][e1];[e0]asetrate=44100*0.45,aresample=44100,lowpass=f=1000,volume=1.5[e];[e1]volume=0.9[p];[2]lowpass=f=220,tremolo=f=2.4:d=0.5,volume='min(t/0.05\,1)*exp(-t*0.5)*2':eval=frame[t];[3]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,adelay=700,volume=0.7[s];[4]aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,adelay=120,volume=0.6[c];[5]aformat=channel_layouts=mono,asetrate=44100*1.1,aresample=44100,adelay=900,volume=0.25[g];[6]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,adelay=40,volume=0.7[m];[e][p][1][t][s][c][g][m]amix=inputs=8:normalize=0:duration=longest,$DENS,aecho=0.8:0.75:260|680|1300:0.4|0.28|0.15,atrim=end=6.5,afade=t=out:st=4.8:d=1.7,$STEREO" \
	-ac 2 "$OUT/_bazooka_bum.wav"
unic bazooka_explozie "$OUT/_bazooka_bum.wav" stereo
TINTA_LUFS=-20
rm -f "$OUT"/_carne.wav "$OUT"/_shotgun.wav "$OUT"/_pompa.wav "$OUT"/_ak.wav "$OUT"/_lansare.wav "$OUT"/_incarcare.wav \
	"$OUT"/_racheta.wav "$OUT"/_bazooka_bum.wav

# --- pădurea, poteca spre vale: păpușa care cade și creatura care trece prin spatele tău (sperietura_papusa.gd)
# sfoara: scârțâie o clipă sub greutate, apoi se rupe (pocnetul la 0,25 s, coarda care zvâcnește)
ffmpeg -v error -y -i "$PACHET/Footsteps/foley_creak_1.wav" -i "$PACHET/Other/elastic_twang.wav" -i "$PACHET/Other/snap.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,atrim=end=0.35,asetrate=44100*1.3,aresample=44100,highpass=f=400,afade=t=out:st=0.18:d=0.08,volume=4[a];[1]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,adelay=260,volume=0.9[b];[2]aformat=channel_layouts=mono,adelay=250[c];[a][b][c]amix=inputs=3:normalize=0:duration=longest,atrim=end=0.8,afade=t=out:st=0.6:d=0.2" \
	-ac 1 "$OUT/_sfoara.wav"
unic papusa_sfoara "$OUT/_sfoara.wav"
# păpușa cade în frunze: bufnitura moale a cârpei, paiele care foșnesc, bețigașul brațelor care pocnește
ffmpeg -v error -y -i "$PACHET/Materials/clothing_thud.wav" -i "$PACHET/Materials/paper_scrunch.wav" -i "$PACHET/Materials/wood_small_drop.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,asetrate=44100*0.85,aresample=44100,lowpass=f=2500[a];[1]aformat=channel_layouts=mono,atrim=end=0.45,highpass=f=1500,lowpass=f=6000,afade=t=out:st=0.25:d=0.2,volume=0.35[b];[2]aformat=channel_layouts=mono,asetrate=44100*1.2,aresample=44100,adelay=30,volume=0.4[c];[a][b][c]amix=inputs=3:normalize=0:duration=longest,atrim=end=0.9,afade=t=out:st=0.7:d=0.2" \
	-ac 1 "$OUT/_papusa_cade.wav"
unic papusa_cade "$OUT/_papusa_cade.wav"
# goana creaturii prin tufișuri (~2,6 s, pe creatură, deci trece prin spatele tău dintr-o parte în alta): frunzele care
# vâjâie în rafale, crengi rupte, vâjâitul trupului
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.9:d=2.6:r=44100:s=61" -i "$PACHET/Combat and Gore/crunch.wav" \
	-i "$PACHET/Combat and Gore/crunch_quick.wav" -i "$PACHET/Combat and Gore/crunch.wav" -i "$PACHET/Other/whoosh_2.wav" -filter_complex \
	"[0]bandpass=f=2500:t=h:w=3500,tremolo=f=9:d=0.8,volume='min(t/0.15\,1)*max(0\,1-(t-2.0)/0.6)*0.8':eval=frame[f];[1]aformat=channel_layouts=mono,asetrate=44100*0.75,aresample=44100,adelay=300,volume=0.8[c1];[2]aformat=channel_layouts=mono,asetrate=44100*0.9,aresample=44100,adelay=1150,volume=0.7[c2];[3]aformat=channel_layouts=mono,asetrate=44100*0.65,aresample=44100,adelay=1850,volume=0.6[c3];[4]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,adelay=700,volume=0.7[w];[f][c1][c2][c3][w]amix=inputs=5:normalize=0:duration=longest,lowpass=f=5000,atrim=end=2.6,afade=t=out:st=2.2:d=0.4" \
	-ac 1 "$OUT/_goana.wav"
unic creatura_goana "$OUT/_goana.wav"
# țipătul ei când trece: o voce urcată mult (scheunat), dedesubt aceeași voce coborâtă (mârâit) și un hârâit în gât
ffmpeg -v error -y -i "$PACHET/Human/man_6.wav" -i "$PACHET/Human/man_4.wav" -f lavfi -i "anoisesrc=c=pink:a=0.8:d=1.1:r=44100:s=62" -filter_complex \
	"[0]aformat=channel_layouts=mono,asetrate=44100*1.6,aresample=44100,highpass=f=600,volume=0.8[h];[1]aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,lowpass=f=1500,volume=0.9[l];[2]bandpass=f=1800:t=h:w=1600,tremolo=f=45:d=0.9,volume='if(lt(t\,0.05)\,t/0.05\,exp(-(t-0.05)*3))*0.5':eval=frame[g];[h][l][g]amix=inputs=3:normalize=0:duration=longest,acrusher=bits=10:mix=0.3,aecho=0.6:0.4:60:0.25,atrim=end=1.1,afade=t=out:st=0.8:d=0.3" \
	-ac 1 "$OUT/_tipat.wav"
unic creatura_tipat "$OUT/_tipat.wav"
# inima ta după sperietură (~7 s): bate repede, apoi se liniștește, cu respirația scurtă, înfundată
INIMA_RAPIDA="0"
t=0.0
for pas in 0.4 0.4 0.4 0.42 0.42 0.44 0.46 0.48 0.5 0.53 0.56 0.6 0.64 0.68; do
	INIMA_RAPIDA="$INIMA_RAPIDA$(inima "$t" 0.9)"
	t=$(awk -v t="$t" -v p="$pas" 'BEGIN { printf "%.2f", t + p }')
done
ffmpeg -v error -y -f lavfi -i "aevalsrc='$INIMA_RAPIDA':s=44100:d=7" -f lavfi -i "anoisesrc=c=pink:a=0.7:d=7:r=44100:s=63" -filter_complex \
	"[0]lowpass=f=220[i];[1]bandpass=f=900:t=h:w=1200,volume='0.35*pow(abs(sin(PI*t/(0.8+t*0.08)))\,3)*max(0\,1-t/7)':eval=frame[r];[i][r]amix=inputs=2:normalize=0,afade=t=out:st=5.8:d=1.2,$STEREO" \
	-ac 2 "$OUT/_inima_rapida.wav"
unic inima_rapida "$OUT/_inima_rapida.wav" stereo
# lovitura (~4 s), mai tare decât efectele obișnuite, ca la celelalte momente mari: bubuitura, „sting”-ul de groază încetinit,
# basul care cade 70 -> 28 Hz, un cluster de coarde ascuțite care tremură și fantoma întoarsă care se stinge
TINTA_NORMALA_PADURE=$TINTA_LUFS
TINTA_LUFS=-13
ffmpeg -v error -y -i "$PACHET/Weapons/harsh_thud.wav" -i "$PACHET/Musical Effects/horror_sting.wav" \
	-f lavfi -i "aevalsrc='1.2*sin(2*PI*(70*t-7*t*t))*min(t/0.005\,1)*exp(-t*1.4)':s=44100:d=4" \
	-f lavfi -i "aevalsrc='0.22*(sin(2*PI*1480*t)+sin(2*PI*1568*t)+0.8*sin(2*PI*1661*t)+0.6*sin(2*PI*740*t))*min(t/0.03\,1)*exp(-t*1.1)':s=44100:d=4" \
	-i "$PACHET/Other/ghost_long.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,lowpass=f=1800,volume=1.2[t];[1]aformat=channel_layouts=mono,asetrate=44100*0.85,aresample=44100[s];[2]lowpass=f=200[b];[3]tremolo=f=11:d=0.5,highpass=f=500[z];[4]aformat=channel_layouts=mono,areverse,asetrate=44100*0.7,aresample=44100,lowpass=f=2500,adelay=400,volume=0.5[g];[t][s][b][z][g]amix=inputs=5:normalize=0:duration=longest,$DENS,aecho=0.7:0.6:180|420:0.3|0.18,atrim=end=4,afade=t=out:st=2.8:d=1.2,$STEREO" \
	-ac 2 "$OUT/_sperietura.wav"
unic sperietura_papusa "$OUT/_sperietura.wav" stereo
TINTA_LUFS=$TINTA_NORMALA_PADURE

# --- omul din pădure, pe urcușul spre platou (om_padure.gd)
# se screme: un mormăit întins de ~2,5 ori și tremurat (două variante)
ffmpeg -v error -y -i "$PACHET/Human/man_2.wav" -af "aformat=channel_layouts=mono,atempo=0.5,atempo=0.8,asetrate=44100*0.92,aresample=44100,tremolo=f=6:d=0.35,lowpass=f=1800,afade=t=out:st=0.75:d=0.2" -ac 1 "$OUT/_icnit1.wav"
unic om_icnit_1 "$OUT/_icnit1.wav"
ffmpeg -v error -y -i "$PACHET/Human/man_8.wav" -af "aformat=channel_layouts=mono,atempo=0.5,atempo=0.75,tremolo=f=8:d=0.45,lowpass=f=1600,afade=t=out:st=0.8:d=0.2" -ac 1 "$OUT/_icnit2.wav"
unic om_icnit_2 "$OUT/_icnit2.wav"
# pârțurile: o undă pătrată joasă care tremură repede (hârâitul), cu ton care se clatină; scurt și lung (care se sufocă la capăt)
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.7*(0.5*sgn(sin(2*PI*(62*t+0.9*sin(2*PI*3*t))))+sin(2*PI*62*t))*(0.55+0.45*sin(2*PI*31*t))*min(t/0.02\,1)*exp(-t*2.5)':s=44100:d=0.7" \
	-f lavfi -i "anoisesrc=c=brown:a=0.5:d=0.7:r=44100:s=64" -filter_complex "[1]lowpass=f=300,volume='exp(-t*4)':eval=frame[n];[0][n]amix=inputs=2:normalize=0,lowpass=f=700,highpass=f=40,afade=t=out:st=0.5:d=0.2" \
	-ac 1 "$OUT/_part1.wav"
unic om_part_1 "$OUT/_part1.wav"
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.7*(0.5*sgn(sin(2*PI*((88*t-12*t*t)+1.5*sin(2*PI*2*t))))+sin(2*PI*(88*t-12*t*t)))*(0.55+0.45*sin(2*PI*(24*t-3*t*t)))*min(t/0.03\,1)*(1-0.85*gt(t\,0.9)*lt(sin(2*PI*9*t)\,0))*max(0\,1-t/1.5)':s=44100:d=1.5" \
	-f lavfi -i "anoisesrc=c=brown:a=0.5:d=1.5:r=44100:s=65" -filter_complex "[1]lowpass=f=300,volume='0.6*max(0\,1-t/1.5)':eval=frame[n];[0][n]amix=inputs=2:normalize=0,lowpass=f=750,highpass=f=40,afade=t=out:st=1.3:d=0.2" \
	-ac 1 "$OUT/_part2.wav"
unic om_part_2 "$OUT/_part2.wav"
# pleoscăitul de dedesubt
ffmpeg -v error -y -i "$PACHET/Environment/water_drop_medium.wav" -i "$PACHET/Combat and Gore/splat_quick.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,lowpass=f=1500[a];[1]aformat=channel_layouts=mono,asetrate=44100*0.8,aresample=44100,lowpass=f=1200,adelay=20,volume=0.5[b];[a][b]amix=inputs=2:normalize=0:duration=longest,afade=t=out:st=0.4:d=0.2" \
	-ac 1 "$OUT/_plop.wav"
unic om_plop "$OUT/_plop.wav"
# l-ai prins: strigătul speriat (o voce urcată puțin) și fâșul care foșnește la fiecare pas cât fuge
unic om_tipat "Human/man_6.wav" mono "aformat=channel_layouts=mono,asetrate=44100*1.25,aresample=44100,highpass=f=200,aecho=0.6:0.4:70:0.2"
unic fas_fosnet_1 "Materials/clothing_1.wav" mono "aformat=channel_layouts=mono,highpass=f=800,asetpts=PTS-STARTPTS,atrim=end=0.3,afade=t=out:st=0.2:d=0.1"
unic fas_fosnet_2 "Materials/clothing_2.wav" mono "aformat=channel_layouts=mono,highpass=f=800,asetpts=PTS-STARTPTS,atrim=end=0.3,afade=t=out:st=0.2:d=0.1"
rm -f "$OUT"/_sfoara.wav "$OUT"/_papusa_cade.wav "$OUT"/_goana.wav "$OUT"/_tipat.wav "$OUT"/_inima_rapida.wav "$OUT"/_sperietura.wav \
	"$OUT"/_icnit1.wav "$OUT"/_icnit2.wav "$OUT"/_part1.wav "$OUT"/_part2.wav "$OUT"/_plop.wav

# --- lupta cu Warlock-ul de la motel (lupta_warlock.gd): bătaia în ușa camerei 122, muzica de boss, „YOU DIED”,
# „GREAT ENEMY FELLED” și Head Witch care îi absoarbe puterile. Rulează doar secțiunea asta cu funcțiile de sus
# (castig, castig_final, unic) și cu DENS / STEREO de la sacrificiu.
TINTA_NORMALA_WARLOCK=$TINTA_LUFS
# o singură bătaie în ușă (din cele trei ale lui door_knock), mai grea: metalul ușii și o bufnitură joasă dedesubt;
# în joc se aude de două ori („knock knock”), 3D, din ușă
TINTA_LUFS=-16
ffmpeg -v error -y -i "$PACHET/Environment/door_knock.wav" -i "$PACHET/Weapons/harsh_thud.wav" -filter_complex \
	"[0]aformat=channel_layouts=mono,atrim=start=0.1:end=0.38,asetpts=PTS-STARTPTS,asetrate=44100*0.9,aresample=44100,volume=1.2[a];[1]aformat=channel_layouts=mono,asetrate=44100*0.7,aresample=44100,lowpass=f=500,atrim=end=0.3,afade=t=out:st=0.12:d=0.18,volume=0.5[b];[a][b]amix=inputs=2:normalize=0:duration=longest,aecho=0.6:0.4:40:0.2,afade=t=out:st=0.25:d=0.08" \
	-ac 1 "$OUT/_ciocan.wav"
unic usa_ciocanit "$OUT/_ciocan.wav"
# muzica de boss (buclă de 16 s, 120 bpm, re minor: Dm - Bb - Gm - A, câte două măsuri): ostinato de coarde grave în
# optimi (accent pe pătrimi), basul care pulsează, alama la începutul fiecărui acord, corul „aah” care respiră între acorduri
# și taiko-urile. Ca la tobe: se face de trei ori și se păstrează bucata din mijloc, deci ecoul se leagă singur.
R="if(lt(mod(t\,16)\,4)\,73.42\,if(lt(mod(t\,16)\,8)\,58.27\,if(lt(mod(t\,16)\,12)\,49\,55)))"
ferastrau() {
	local f="$1" n="$2" s="" k
	for k in $(seq 1 "$n"); do s="$s+sin(2*PI*$k*($f)*t)/$k"; done
	echo "(0$s)"
}
OST="0.3*$(ferastrau "$R" 5)*exp(-mod(t\,0.25)*9)*min(mod(t\,0.25)/0.004\,1)*min((0.25-mod(t\,0.25))/0.012\,1)*(1+0.5*lt(mod(t\,0.5)\,0.25))"
BAS="0.45*sin(2*PI*($R)*0.5*t)*exp(-mod(t\,1)*2.2)*min(mod(t\,1)/0.01\,1)*min((1-mod(t\,1))/0.03\,1)"
ALAMA="0.16*($(ferastrau "($R)*2" 6)+0.8*$(ferastrau "($R)*3" 6))*exp(-mod(t\,4)*1.1)*min(mod(t\,4)/0.03\,1)"
C1="if(lt(mod(t\,16)\,4)\,146.83\,if(lt(mod(t\,16)\,8)\,116.54\,if(lt(mod(t\,16)\,12)\,98\,110)))"
C2="if(lt(mod(t\,16)\,4)\,174.61\,if(lt(mod(t\,16)\,8)\,146.83\,if(lt(mod(t\,16)\,12)\,116.54\,138.59)))"
C3="if(lt(mod(t\,16)\,4)\,220\,if(lt(mod(t\,16)\,8)\,174.61\,if(lt(mod(t\,16)\,12)\,146.83\,164.81)))"
vocea() {
	local f="$1" ph="$2" s="" k
	for k in 1 2 3 4 5; do s="$s+sin(2*PI*$k*(($f)*t+($f)*0.003*sin(2*PI*5.1*t+$ph)))/$k"; done
	echo "(0$s)"
}
COR="0.1*($(vocea "$C1" 0)+$(vocea "$C2" 1.3)+$(vocea "$C3" 2.1)+0.7*$(vocea "($C1)*2" 0.7))*min(mod(t\,4)/0.35\,1)*min((4-mod(t\,4))/0.35\,1)"
# o măsură de taiko (2 s), luată din mijlocul a trei, ca să se lege
TOBA="0"
for m in 0 1 2; do
	for x in "0:1" "0.75:0.55" "1.0:0.9" "1.5:0.5" "1.75:0.65"; do
		TOBA="$TOBA$(taiko $(awk -v a="${x%%:*}" -v m=$m 'BEGIN { printf "%.2f", a + m * 2 }') ${x##*:})"
	done
done
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.5*($TOBA)':s=44100:d=6" -af "lowpass=f=1800,equalizer=f=70:t=q:w=1:g=4,atrim=start=2:end=4,asetpts=PTS-STARTPTS" \
	-ac 1 "$OUT/_toba.wav"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$OST+$BAS+$ALAMA':s=44100:d=48" -f lavfi -i "aevalsrc='$COR':s=44100:d=48" \
	-stream_loop 23 -i "$OUT/_toba.wav" -filter_complex \
	"[0]lowpass=f=3200,highpass=f=35[o];[1]equalizer=f=700:t=q:w=1.2:g=6,equalizer=f=1150:t=q:w=1.5:g=3,lowpass=f=2600,chorus=0.6:0.9:35|50:0.4|0.35:0.3|0.45:1.6|2.2[c];[2]volume=0.9[b];[o][c][b]amix=inputs=3:normalize=0:duration=first,$DENS,aecho=0.8:0.6:180|430:0.3|0.18,atrim=start=16:end=32,asetpts=PTS-STARTPTS,$STEREO,atrim=end=16" \
	-ac 2 "$OUT/_boss.wav"
TINTA_LUFS=-18
g=$(castig_final "$OUT/_boss.wav" "anull")
ffmpeg -v error -y -i "$OUT/_boss.wav" -af "volume=${g}dB,$LIMITATOR" -c:a libvorbis -q:a 5 "$OUT/muzica_warlock.ogg"
echo "muzica_warlock.ogg  (buclă, 16 s)"
# „YOU DIED” (~5 s): un gong grav (parțiale neîmpărțite, care bat între ele), bubuitura joasă și un cor care cade
TINTA_LUFS=-13
GONG="0"
for x in "65:1:0.6" "96.5:0.7:0.8" "140:0.5:1.1" "188:0.35:1.5" "241:0.25:1.9" "66.3:0.5:0.7"; do
	IFS=: read -r f a d <<< "$x"
	GONG="$GONG+$a*sin(2*PI*$f*t)*exp(-t*$d)"
done
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.35*($GONG)*min(t/0.004\,1)':s=44100:d=5.5" \
	-f lavfi -i "aevalsrc='1.1*sin(2*PI*(52*t-3*t*t))*min(t/0.005\,1)*exp(-t*1.6)':s=44100:d=5.5" \
	-f lavfi -i "aevalsrc='0.12*($(voce 73.42 0)+$(voce 87.31 1)+$(voce 110 2))*min(t/0.15\,1)*exp(-t*0.8)':s=44100:d=5.5" \
	-filter_complex "[2]asetrate=44100*0.94,aresample=44100,equalizer=f=650:t=q:w=1.2:g=5,lowpass=f=2200[c];[0][1][c]amix=inputs=3:normalize=0,$DENS,aecho=0.8:0.7:300|700|1200:0.35|0.25|0.15,atrim=end=5.5,afade=t=out:st=4.2:d=1.3,$STEREO" \
	-ac 2 "$OUT/_murit.wav"
unic ai_murit "$OUT/_murit.wav" stereo
# „GREAT ENEMY FELLED” (~4 s): un acord luminos (re major) care sclipește și urcă, cu o bufnitură blândă dedesubt
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.16*(sin(2*PI*587.3*t)+sin(2*PI*740*t)+sin(2*PI*880*t)+0.7*sin(2*PI*1174.7*t)+0.5*sin(2*PI*293.7*t))*(0.7+0.3*sin(2*PI*13*t))*min(t/0.6\,1)*exp(-t*0.7)':s=44100:d=4.5" \
	-f lavfi -i "aevalsrc='0.9*sin(2*PI*(60*t-5*t*t))*min(t/0.005\,1)*exp(-t*2)':s=44100:d=4.5" -i "$PACHET/Other/whoosh_1.wav" \
	-filter_complex "[2]aformat=channel_layouts=mono,areverse,asetrate=44100*0.9,aresample=44100,volume=0.5[w];[0][1][w]amix=inputs=3:normalize=0:duration=first,chorus=0.6:0.9:20|35:0.4|0.3:0.4|0.5:2|3,aecho=0.8:0.6:250|600:0.3|0.2,afade=t=out:st=3.4:d=1.1,$STEREO" \
	-ac 2 "$OUT/_doborat.wav"
unic inamic_doborat "$OUT/_doborat.wav" stereo
# Head Witch îi absoarbe puterile (~6 s): energia trasă (zgomot care urcă și se strânge, tot mai repede), un cor grav care
# crește, pârâit de scântei, apoi implozia (aerul tras înapoi, bubuitura joasă)
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=pink:a=0.8:d=6:r=44100:s=71" \
	-f lavfi -i "aevalsrc='0.1*($(voce 55 0)+$(voce 82.41 1)+$(voce 110 2)+$(voce 116.54 0.5))*min(t/4.5\,1)*if(lt(t\,4.8)\,1\,exp(-(t-4.8)*4))':s=44100:d=6" \
	-f lavfi -i "aevalsrc='lt(random(3)\,0.01+0.03*t/6)*(random(4)*2-1)*0.8':s=44100:d=6" \
	-f lavfi -i "aevalsrc='1.2*gte(t\,4.8)*sin(2*PI*(70*(t-4.8)-12*(t-4.8)*(t-4.8)))*exp(-(t-4.8)*2.5)':s=44100:d=6" \
	-filter_complex "[0]bandpass=f=700:t=h:w=900,vibrato=f=7:d=0.4,volume='if(lt(t\,4.8)\,pow(t/4.8\,2)*1.6\,exp(-(t-4.8)*12)*1.6)':eval=frame[w];[1]equalizer=f=600:t=q:w=1.2:g=5,lowpass=f=2400,chorus=0.6:0.9:35|50:0.4|0.35:0.3|0.45:1.6|2.2[c];[2]highpass=f=2500[p];[w][c][p][3]amix=inputs=4:normalize=0,$DENS,aecho=0.8:0.6:200|480:0.3|0.18,atrim=end=6,afade=t=out:st=5.2:d=0.8,$STEREO" \
	-ac 2 "$OUT/_absorbtie.wav"
unic absorbtie "$OUT/_absorbtie.wav" stereo
TINTA_LUFS=$TINTA_NORMALA_WARLOCK
rm -f "$OUT"/_ciocan.wav "$OUT"/_toba.wav "$OUT"/_boss.wav "$OUT"/_murit.wav "$OUT"/_doborat.wav "$OUT"/_absorbtie.wav
