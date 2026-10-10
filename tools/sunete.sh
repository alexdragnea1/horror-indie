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

# Cele 4 sunete ale sacrificiului (cazan_plescait, vraja_cor, vraja_unda, vraja_bum) au fost refăcute pe 11.10 din
# pachetele noi: vezi secțiunea „sacrificiul din coven refăcut «de film»” de la sfârșitul fișierului. Funcțiile de mai
# sus (DENS, STEREO, inima, voce) le folosesc și secțiunile de mai jos.
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
# ceaunul care se încinge, explozia și demonul: refăcute „de film” la sfârșitul fișierului (secțiunea „ceaunul de acasă și demonul”)
# țiuitul din urechi după explozie: două sinusuri înalte, apropiate (bat ușor între ele), care se sting în 3,5 s
ffmpeg -v error -y -f lavfi -i "aevalsrc='(sin(2*PI*3700*t)+0.6*sin(2*PI*3745*t))*min(1\,t/0.05)*exp(-t*0.9)':s=44100:d=3.5" \
	-af "afade=t=out:st=2.8:d=0.7" -ac 1 "$OUT/_tiuit.wav"
unic tiuit "$OUT/_tiuit.wav"
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

# --- lupta cu Warlock-ul de la motel (lupta_warlock.gd): bătaia în ușa camerei 122, „YOU DIED”,
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

# --- barul „URBAN” (09.10): capacul de bere, turnatul, săgețile de darts, bilele, tacul, mantinela, buzunarul
unic capac_bere "Other/snap.wav" mono "highpass=f=900,asetrate=44100*1.25,aresample=44100,atrim=end=0.25,afade=t=out:st=0.12:d=0.13"
unic turnat_bautura "Environment/gurgling.wav" mono "lowpass=f=3500,asetrate=44100*1.15,aresample=44100,atrim=end=1.4,afade=t=in:d=0.08,afade=t=out:st=1.0:d=0.4"
unic darts_aruncat "Other/whoosh_2.wav" mono "asetrate=44100*1.7,aresample=44100,highpass=f=500,atrim=end=0.3,afade=t=out:st=0.15:d=0.15"
unic darts_infipt "Materials/cork_stabbed.wav" mono "atrim=end=0.35,afade=t=out:st=0.2:d=0.15"
# ciocnirea a două bile: un „clac” sec (parțiale înalte care se sting în ~40 ms) peste un clic de zgomot
ffmpeg -v error -y -f lavfi -i "aevalsrc='(0.5*sin(2*PI*2350*t)+0.35*sin(2*PI*3720*t)+0.2*sin(2*PI*5180*t))*exp(-t*95)+0.25*(random(0)*2-1)*exp(-t*600)':s=44100:d=0.15" \
	-af "highpass=f=700,afade=t=out:st=0.08:d=0.07" -ac 1 "$OUT/_bile.wav"
unic biliard_bile "$OUT/_bile.wav"
# tacul în albă: „toc” mai jos și mai scurt, cu o bufnitură dedesubt
ffmpeg -v error -y -f lavfi -i "aevalsrc='(0.45*sin(2*PI*1420*t)+0.3*sin(2*PI*2610*t))*exp(-t*70)+0.5*sin(2*PI*190*t)*exp(-t*45)+0.2*(random(0)*2-1)*exp(-t*500)':s=44100:d=0.18" \
	-af "afade=t=out:st=0.1:d=0.08" -ac 1 "$OUT/_tac.wav"
unic biliard_tac "$OUT/_tac.wav"
unic biliard_manta "Other/subtle_knock.wav" mono "lowpass=f=900,lowpass=f=900,atrim=end=0.2,afade=t=out:st=0.1:d=0.1"
unic biliard_buzunar "Materials/wood_small_drop.wav" mono "lowpass=f=2200,atrim=end=0.45,afade=t=out:st=0.3:d=0.15"
rm -f "$OUT/_bile.wav" "$OUT/_tac.wav"

# --- luptele cu vrăjitorii, refăcute „de film” (10.10) din pachetele noi ale owner-ului: atacul Warlock-ului asupra
# conacului (atac_conac.gd), lupta cu Warlock-ul (lupta_warlock.gd) și cu Head Witch (lupta_head_witch.gd), partea comună
# din lupta_boss.gd. Pachetele (în Sound/, ignorate):
#   Soundpack 2 = „Horror SFX Free” (urlete, stingere, corul fantomelor, clopotul), licență neverificată;
#   Soundpack 3 = „Helton Yan's Old-School Shonen SFX” (explozii, încărcări, lovituri, scântei), CC BY 4.0 -> trebuie
#                 trecut în credite;
#   Soundpack 4 = „Free Fantasy SFX Pack” de TomMusic (vrăji, gheață, piatră, bucla de furtună cu tunete adevărate),
#                 licență neverificată.
# ⚠️ Fișierele Shonen au câte 6 variante una după alta, despărțite de liniște (96 kHz): `b START SFARSIT VITEZA` taie
# bucata (aici aproape mereu prima variantă, de la 0). Rămân neschimbate (owner: „îmi place”) scut.ogg, plus inima,
# țiuitul, focul, tobele, ciocănitul și muzicile.
# Ca la sacrificiu: cele „de film” la -13 LUFS și comprimate ($DENS); cele care se aud des în luptă mai jos (scrie la fiecare).
TINTA_NORMALA_LUPTE=$TINTA_LUFS
P2="Sound/Soundpack 2"
P3="Sound/Soundpack 3"
P4="Sound/Soundpack 4/WAV Files/SFX"
FURTUNA="Sound/Soundpack 4/WAV Files/BGS Loops/Forest Night/Forest Night Storm.wav"
# b START SFARSIT VITEZA -> mono 44,1 kHz, bucata [START, SFARSIT) din fișier, redată cu VITEZA (sub 1 = mai grav și mai lent)
b() { echo "aformat=channel_layouts=mono,aresample=44100,atrim=start=$1:end=$2,asetpts=PTS-STARTPTS,asetrate=44100*$3,aresample=44100"; }
# sub F0 F1 DURATA DESCRESTERE AMPLITUDINE -> basul care „lovește în piept”: sinus care alunecă de la F0 la F1 Hz
sub() { echo "aevalsrc='$5*sin(2*PI*($1*t+($2-$1)*t*t/(2*$3)))*min(t/0.005\,1)*exp(-t*$4)':s=44100:d=$3"; }
MIX="amix=normalize=0:duration=longest:inputs"
ECOU_MARE="aecho=0.8:0.7:300|750|1400:0.4|0.28|0.16"
ECOU_MIC="aecho=0.7:0.5:110|260:0.3|0.18"
TINTA_LUFS=-13

# 1. tunetul de departe (~6,5 s): un tunet ADEVĂRAT, din bucla de furtună (17,2-24,5 s), cu ploaia tăiată de un lowpass
# (rămâne doar rostogolirea) și un bas care se umflă sub el
ffmpeg -v error -y -i "$FURTUNA" -f lavfi -i "$(sub 50 30 7.3 0.5 0.5)" -filter_complex \
	"[0]$(b 17.2 24.5 1),lowpass=f=700,equalizer=f=70:t=q:w=1:g=5,volume=2.5[t];[1]afade=t=in:d=0.6[s];[t][s]$MIX=2,$DENS,afade=t=in:d=0.15,afade=t=out:st=5.8:d=1.5,$ECOU_MIC,$STEREO" \
	-ac 2 "$OUT/_tunet.wav"
unic atac_tunet "$OUT/_tunet.wav" stereo
# 2. fulgerul care lovește aproape (~3 s, 3D): pocnetul electric (scânteia Shonen), lovitura (explozia scurtă) și
# rostogolirea tunetului adevărat care vine după
ffmpeg -v error -y -i "$P3/ELECSprk_Anime Spark 3.wav" -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -i "$FURTUNA" -f lavfi -i "$(sub 70 35 3 3 0.9)" -filter_complex \
	"[0]$(b 0 0.5 1),highpass=f=1200,afade=t=out:st=0.25:d=0.25[c];[1]$(b 0 1.4 0.85),lowpass=f=3500,volume=0.9[e];[2]$(b 17.4 20.4 1),lowpass=f=800,volume=2.2,adelay=150[r];[c][e][r][3]$MIX=4,$DENS,$ECOU_MIC,atrim=end=3,afade=t=out:st=2.3:d=0.7" \
	-ac 1 "$OUT/_fulger.wav"
unic atac_fulger "$OUT/_fulger.wav"
# 3. cornul de război „de film” (~5,5 s): cornul sintetizat de mai sus (atac_corn.ogg) peste drone-ul de groază și
# rezonanța de metal coborâtă, cu un bas care se umflă. Fișier nou (atac_corn rămâne sursa lui).
ffmpeg -v error -y -i "$OUT/atac_corn.ogg" -i "$P2/Ambient/Drone_doom.wav" -i "$P2/Stingers and Spooky Triggers/Metal_resonance.wav" -f lavfi -i "$(sub 37 37 5.5 0.2 0.5)" -filter_complex \
	"[0]aformat=channel_layouts=mono,aresample=44100[c];[1]$(b 0 5.5 0.8),volume=3[d];[2]$(b 0 5.5 0.7),lowpass=f=2000,volume=0.8[m];[3]afade=t=in:d=1.5[s];[c][d][m][s]$MIX=4,$DENS,atrim=end=5.5,afade=t=out:st=4.5:d=1,$ECOU_MARE,$STEREO" \
	-ac 2 "$OUT/_corn.wav"
unic atac_corn_film "$OUT/_corn.wav" stereo
# 4. teleportul (~1,4 s, 3D; lovitura la t = 0, când apare): eliberarea de energie (Ability Release), explozia coborâtă
# pentru greutate și basul care cade 95 -> 40 Hz
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Release 13.wav" -i "$P3/EXPLDsgn_Anime Explosion 5.wav" -f lavfi -i "$(sub 95 40 1.4 4 0.9)" -filter_complex \
	"[0]$(b 0 1 1)[r];[1]$(b 0 1.45 0.75),lowpass=f=1600,volume=0.8[e];[r][e][2]$MIX=3,$DENS,$ECOU_MIC,atrim=end=1.4,afade=t=out:st=1:d=0.4" \
	-ac 1 "$OUT/_aparitie.wav"
unic atac_aparitie "$OUT/_aparitie.wav"
# 5. sosirea Warlock-ului (~7 s): coboară din cer 2,9 s (încărcarea Shonen care tot crește, urletul grav al unui monstru
# încetinit sub ea), apoi aterizarea la 2,9 s: explozia lungă coborâtă, trântitura grea, basul 60 -> 20 Hz și stingerul de
# pian disonant, cu ecoul lung al dealurilor
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Charge 17.wav" -i "$P2/Monsters & Ghosts/Monster_Roar_4.wav" -i "$P3/EXPLDsgn_Anime Explosion 6.wav" \
	-i "$P3/FGHTBf_Anime Land 11.wav" -f lavfi -i "$(sub 60 20 4 0.7 1.3)" -i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent.wav" -filter_complex \
	"[0]$(b 0 3.25 0.9),volume='0.08+0.42*pow(min(t/2.9\,1)\,2)':eval=frame,afade=t=out:st=2.85:d=0.2[i];[1]$(b 0 4.15 0.6),lowpass=f=1400,volume='0.2+0.8*min(t/2.9\,1)':eval=frame,afade=t=out:st=3.4:d=1.5,volume=0.4[m];[2]$(b 0 3.4 0.75),lowpass=f=2600,adelay=2900,volume=1.3[e];[3]$(b 0 0.7 0.7),adelay=2900,volume=1.1[l];[4]adelay=2900[s];[5]$(b 0 2.9 0.9),adelay=2950,volume=0.7[p];[i][m][e][l][s][p]$MIX=6,$DENS,$ECOU_MARE,atrim=end=7,afade=t=out:st=5.8:d=1.2,$STEREO" \
	-ac 2 "$OUT/_sosire.wav"
unic warlock_sosire "$OUT/_sosire.wav" stereo
# 6. o vrajă aruncată (~1,2 s, 3D, -15: armata aruncă una la 0,2-0,3 s, salvele boss-ului 3-5 una după alta): mingea de
# foc (Fantasy), „aruncarea” Shonen și o bufnitură joasă (reculul)
ffmpeg -v error -y -i "$P4/Spells/Fireball 1.wav" -i "$P3/FGHTMisc_Anime Throw 4.wav" -f lavfi -i "$(sub 85 50 1.2 9 0.7)" -filter_complex \
	"[0]$(b 0 1.2 1)[f];[1]$(b 0.1 0.6 0.9),volume=0.8[w];[f][w][2]$MIX=3,$DENS,atrim=end=1.2,afade=t=out:st=0.8:d=0.4" \
	-ac 1 "$OUT/_vraja.wav"
TINTA_LUFS=-15
unic atac_vraja "$OUT/_vraja.wav"
TINTA_LUFS=-13
# 7. vraja lovește piatra (~2,4 s, 3D): explozia scurtă, impactul vrăjii, zidul care se rupe și moloz (Rock Wall), bas
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -i "$P4/Spells/Spell Impact 1.wav" -i "$P4/Spells/Rock Wall 1.wav" -f lavfi -i "$(sub 75 35 2.4 5 0.9)" -filter_complex \
	"[0]$(b 0 1.4 0.9)[e];[1]$(b 0 0.35 0.9),volume=0.8[i];[2]$(b 0 2 0.85),adelay=60,volume=0.7[r];[e][i][r][3]$MIX=4,$DENS,$ECOU_MIC,atrim=end=2.4,afade=t=out:st=1.8:d=0.6" \
	-ac 1 "$OUT/_impact.wav"
TINTA_LUFS=-14
unic atac_impact "$OUT/_impact.wav"
TINTA_LUFS=-13
# 8. scutul lui Head Witch se sparge (~2 s): gheața care se face țăndări (Ice Barrage + Ice Freeze = sticlă magică),
# pocnetul (explozia tăiată) și clinchetul de sticlă din pachetul vechi
ffmpeg -v error -y -i "$P4/Spells/Ice Barrage 2.wav" -i "$P4/Spells/Ice Freeze 1.wav" -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -i "$PACHET/Materials/glass_ping_big.wav" -filter_complex \
	"[0]$(b 0 1.75 1)[a];[1]$(b 0 0.85 1.2),adelay=40[g];[2]$(b 0 0.6 1.1),highpass=f=300,afade=t=out:st=0.3:d=0.3,volume=0.7[e];[3]$(b 0 2 0.8),adelay=90,volume=0.4[p];[a][g][e][p]$MIX=4,$DENS,atrim=end=2,afade=t=out:st=1.4:d=0.6,$STEREO" \
	-ac 2 "$OUT/_spart.wav"
unic scut_spart "$OUT/_spart.wav" stereo
# 9. vraja mare de la conac se încarcă (~8,5 s): două încărcări Shonen coborâte, una după alta, riser-ul de groază
# („Suspenseful pitch increase”), corul fantomelor care se umflă, scântei tot mai dese și inima tot mai rapidă.
# Se termină în vârf (pleacă vraja).
INIMA_URCA="0$(inima 0.8 0.3)$(inima 2.0 0.35)$(inima 3.0 0.4)$(inima 3.8 0.48)$(inima 4.5 0.55)$(inima 5.1 0.62)$(inima 5.6 0.7)$(inima 6.05 0.76)$(inima 6.45 0.82)$(inima 6.8 0.88)$(inima 7.12 0.94)$(inima 7.42 1.0)$(inima 7.7 1.0)$(inima 7.96 1.0)"
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Charge 4.wav" -i "$P3/MAGSpel_Anime Ability Charge 17.wav" -i "$P2/Stingers and Spooky Triggers/Suspenseful pitch increase.wav" \
	-i "$P2/Monsters & Ghosts/Ghost chior.wav" -i "$P3/ELECSprk_Anime Spark 3.wav" -f lavfi -i "aevalsrc='$INIMA_URCA':s=44100:d=8.5" -filter_complex \
	"[0]$(b 0 3.15 0.7),afade=t=out:st=4:d=0.6[a];[1]$(b 0 3.25 0.85),adelay=4000,afade=t=in:st=4:d=0.5[b];[2]$(b 0 6.5 1),adelay=2000[r];[3]$(b 0 8.5 0.9),afade=t=in:d=4,volume=0.6[c];[4]$(b 0 3.4 1),highpass=f=1500,adelay=5000,volume=0.6[s];[5]lowpass=f=300,volume=1.5[i];[a][b][r][c][s][i]$MIX=6,$DENS,volume='0.12+0.88*pow(t/8.5\,1.6)':eval=frame,atrim=end=8.5,$STEREO" \
	-ac 2 "$OUT/_incarcare.wav"
unic orb_incarcare "$OUT/_incarcare.wav" stereo
# 10. încărcarea globului în luptă (~4 s, 3D din toiag, -15): tare de la început (în luptă ține doar 1-1,4 s, în intro
# până la 4 s cât ai timp de scut): încărcarea Shonen, tonul care urcă și pârâitul de scântei
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Charge 2.wav" -i "$P3/MAGSpel_Anime Ability Charge 14.wav" -i "$P3/ELECSprk_Anime Spark 4.wav" -filter_complex \
	"[0]$(b 0 3.1 0.9),apad=whole_dur=4[a];[1]$(b 0 3.5 1),volume=2.5[t];[2]$(b 0 3.1 1),highpass=f=1000,volume=0.8[s];[a][t][s]$MIX=3,$DENS,atrim=end=4,afade=t=out:st=3.6:d=0.4" \
	-ac 1 "$OUT/_boss_incarcare.wav"
TINTA_LUFS=-15
unic boss_incarcare "$OUT/_boss_incarcare.wav"
TINTA_LUFS=-13
# 11. vraja mare zboară pe deasupra ta (~2,6 s): vâjâitul care vine (întors, crește) și cel care pleacă (cade), mingea de
# foc încetinită și tonul care coboară ca la o mașină care trece (doppler)
ffmpeg -v error -y -i "$P3/SWSH_Anime Fly 5.wav" -i "$P3/SWSH_Anime Fly 4.wav" -i "$P4/Spells/Fireball 2.wav" \
	-f lavfi -i "aevalsrc='0.6*sin(2*PI*(110*t-18*t*t))*exp(-pow((t-1.3)/0.55\,2))':s=44100:d=2.6" -filter_complex \
	"[0]$(b 0 1.1 0.7),areverse[v];[1]$(b 0 1.05 0.6),adelay=1250[p];[2]$(b 0 1.2 0.6),adelay=600,volume=0.8[f];[v][p][f][3]$MIX=4,$DENS,atrim=end=2.9,afade=t=out:st=2.4:d=0.5,$STEREO" \
	-ac 2 "$OUT/_orb_zbor.wav"
unic orb_zbor "$OUT/_orb_zbor.wav" stereo
# 12. vraja mare lovește conacul (~8 s, -12): explozia lungă coborâtă + cea seacă pentru pocnet, basul 60 -> 18 Hz,
# zidurile care se prăbușesc (Rock Wall de două ori), tunetul adevărat care se rostogolește după, stingerul de pian
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 6.wav" -i "$P3/EXPLDsgn_Anime Explosion 11.wav" -f lavfi -i "$(sub 60 18 8 0.6 1.3)" \
	-i "$P4/Spells/Rock Wall 1.wav" -i "$P4/Spells/Rock Wall 2.wav" -i "$FURTUNA" -i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent.wav" -filter_complex \
	"[0]$(b 0 3.4 0.7),lowpass=f=2600,volume=1.3[e];[1]$(b 0 3.15 1),volume=0.8[p];[3]$(b 0 2 0.7),adelay=300,volume=0.8[r1];[4]$(b 0 2 0.6),adelay=900,volume=0.7[r2];[5]$(b 17.4 24.5 1),lowpass=f=600,adelay=1400,volume=2[t];[6]$(b 0 2.9 0.8),adelay=100,volume=0.6[s];[e][p][2][r1][r2][t][s]$MIX=7,$DENS,$ECOU_MARE,atrim=end=8.5,afade=t=out:st=6.5:d=2,$STEREO" \
	-ac 2 "$OUT/_orb_bum.wav"
TINTA_LUFS=-12
unic orb_explozie "$OUT/_orb_bum.wav" stereo
TINTA_LUFS=-13
# 13. globul / unda lovesc în luptă (~2 s): explozia de mijloc, eliberarea de energie și basul. Înlocuiește în luptă
# explozia de film de 8 s (se auzea la fiecare glob, cerc și undă)
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 5.wav" -i "$P3/MAGSpel_Anime Ability Release 13.wav" -f lavfi -i "$(sub 70 30 2 3 1)" -filter_complex \
	"[0]$(b 0 1.45 0.85)[e];[1]$(b 0 1 0.8),volume=0.7[r];[e][r][2]$MIX=3,$DENS,$ECOU_MIC,atrim=end=2,afade=t=out:st=1.4:d=0.6" \
	-ac 1 "$OUT/_boss_glob.wav"
TINTA_LUFS=-14
unic boss_glob_bum "$OUT/_boss_glob.wav"
TINTA_LUFS=-13
# 14. cercul de pe jos înainte de fulger (~1,3 s, 3D, -17: apar 3-4 deodată): energia care se strânge și sfârâie
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Charge 1.wav" -i "$P3/ELECSprk_Anime Spark 1.wav" -filter_complex \
	"[0]$(b 0 1.15 1)[c];[1]$(b 0 0.65 1),volume=1.5,adelay=400[s];[c][s]$MIX=2,atrim=end=1.3,afade=t=out:st=1:d=0.3" \
	-ac 1 "$OUT/_cerc.wav"
TINTA_LUFS=-17
unic boss_cerc "$OUT/_cerc.wav"
TINTA_LUFS=-13
# 15. unda de șoc: toiagul bate în pământ (~2,5 s, 3D): trântitura grea, explozia coborâtă, valul (Wave Attack) care
# fuge pe jos și basul. Și la nova (de trei ori) și la coborârea după transformare.
ffmpeg -v error -y -i "$P3/FGHTBf_Anime Land 11.wav" -i "$P3/EXPLDsgn_Anime Explosion 9.wav" -i "$P4/Spells/Wave Attack 1.wav" -f lavfi -i "$(sub 55 22 2.5 1.6 1.2)" -filter_complex \
	"[0]$(b 0 0.7 0.6)[l];[1]$(b 0 2 0.75),lowpass=f=2500,volume=0.8[e];[2]$(b 1.2 3.2 1),afade=t=in:d=0.1,volume=0.7[w];[l][e][w][3]$MIX=4,$DENS,$ECOU_MIC,atrim=end=2.5,afade=t=out:st=1.8:d=0.7" \
	-ac 1 "$OUT/_unda.wav"
unic boss_unda "$OUT/_unda.wav"
# 16. scutul tău oprește o vrajă (~0,8 s, -15): clinchetul de metal al parării, impactul vrăjii și o scânteie; se aude
# PESTE scut.ogg (care rămâne)
ffmpeg -v error -y -i "$P4/Attacks/Sword Attacks Hits and Blocks/Sword Blocked 1.wav" -i "$P4/Spells/Spell Impact 2.wav" -i "$P3/ELECSprk_Anime Spark 2.wav" -f lavfi -i "$(sub 90 50 0.8 8 0.6)" -filter_complex \
	"[0]$(b 0 0.5 0.8)[m];[1]$(b 0 0.4 1)[i];[2]$(b 0 0.4 1.1),highpass=f=1500,volume=0.8[s];[m][i][s][3]$MIX=4,$ECOU_MIC,atrim=end=0.9,afade=t=out:st=0.6:d=0.3" \
	-ac 1 "$OUT/_parare.wav"
TINTA_LUFS=-15
unic boss_parare "$OUT/_parare.wav"
TINTA_LUFS=-13
# 17. te lovește o vrajă (~0,8 s): lovitura Shonen (pumnul), explozia scurtă înfundată (în corp) și bufnitura
ffmpeg -v error -y -i "$P3/FGHTImpt_Anime Melee 1.wav" -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -f lavfi -i "$(sub 80 40 0.8 6 1)" -filter_complex \
	"[0]$(b 0 0.5 0.9)[m];[1]$(b 0 0.6 1),lowpass=f=900,volume=0.7[e];[m][e][2]$MIX=3,$DENS,atrim=end=0.8,afade=t=out:st=0.5:d=0.3" \
	-ac 1 "$OUT/_lovit_tu.wav"
unic jucator_lovit "$OUT/_lovit_tu.wav"
# 18. îl lovești pe boss (~0,5 s, -18: AK-ul trage repede; codul îl rărește): lovitura Shonen și sfârâitul vrăjii
ffmpeg -v error -y -i "$P3/FGHTImpt_Anime Melee 3.wav" -i "$P4/Spells/Spell Impact 3.wav" -filter_complex \
	"[0]$(b 0 0.45 1)[m];[1]$(b 0 0.4 0.9),volume=0.7[i];[m][i]$MIX=2,atrim=end=0.5,afade=t=out:st=0.35:d=0.15" \
	-ac 1 "$OUT/_boss_lovit.wav"
TINTA_LUFS=-18
unic boss_lovit "$OUT/_boss_lovit.wav"
TINTA_LUFS=-13
# 19. cazi pe spate în luptă (~0,8 s): trântitura Shonen pe asfalt
ffmpeg -v error -y -i "$P3/FGHTBf_Anime Land 3.wav" -f lavfi -i "$(sub 70 35 0.8 6 0.6)" -filter_complex \
	"[0]$(b 0 0.7 0.85)[l];[l][1]$MIX=2,$ECOU_MIC,atrim=end=0.9,afade=t=out:st=0.6:d=0.3" -ac 1 "$OUT/_cazi.wav"
unic boss_cazi "$OUT/_cazi.wav"
# --- vocile: Warlock-ul și Head Witch (monștri și fantome din pachetul Horror, coborâți ca să sune mari)
# 20. Warlock-ul geme când îl lovești (~0,6 s, 3D, -16; codul îl lasă cel mult o dată la 1,2 s)
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Monster_grunt x2 (ghmmm).wav" -i "$P2/Monsters & Ghosts/Zombie_6.wav" -filter_complex \
	"[0]$(b 0 0.35 0.75)[g];[1]$(b 0 0.85 0.7),lowpass=f=1800,volume=0.5[z];[g][z]$MIX=2,$ECOU_MIC,atrim=end=0.9,afade=t=out:st=0.6:d=0.3" \
	-ac 1 "$OUT/_durere.wav"
TINTA_LUFS=-16
unic warlock_durere "$OUT/_durere.wav"
TINTA_LUFS=-13
# 21. Warlock-ul urlă la faza a doua (~4,5 s, 3D): urletul lung coborât, mârâitul dedesubt și basul
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Monster_Roar_4.wav" -i "$P2/Monsters & Ghosts/Monster_growl_1.wav" -f lavfi -i "$(sub 45 30 4.5 0.6 0.6)" -filter_complex \
	"[0]$(b 0 4.15 0.72)[r];[1]$(b 0 1.7 0.6),adelay=200,volume=0.6[g];[2]afade=t=in:d=0.4[s];[r][g][s]$MIX=3,$DENS,$ECOU_MARE,atrim=end=5,afade=t=out:st=3.8:d=1.2" \
	-ac 1 "$OUT/_urlet_w.wav"
unic warlock_urlet "$OUT/_urlet_w.wav"
# 22. Warlock-ul cade învins (~2,5 s, 3D): urletul scurt, frânt, și horcăitul
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Monster_Roar_2.wav" -i "$P2/Monsters & Ghosts/Zombie_8.wav" -filter_complex \
	"[0]$(b 0 1.15 0.65)[r];[1]$(b 0 0.9 0.7),lowpass=f=1500,adelay=700,volume=0.7[z];[r][z]$MIX=2,$DENS,$ECOU_MARE,atrim=end=2.8,afade=t=out:st=2:d=0.8" \
	-ac 1 "$OUT/_moare_w.wav"
unic warlock_moare "$OUT/_moare_w.wav"
# 23. Warlock-ul râde (~2,8 s, 3D): râsul înfiorător, coborât și grav, cu ecou (la apariția din motel și la „YOU DIED”)
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Laugh_spooky_4.wav" -filter_complex \
	"[0]$(b 0 2.1 0.78),lowpass=f=3500,equalizer=f=180:t=q:w=1:g=4,$DENS,$ECOU_MARE,atrim=end=3.2,afade=t=out:st=2.5:d=0.7" \
	-ac 1 "$OUT/_ras.wav"
TINTA_LUFS=-14
unic warlock_ras "$OUT/_ras.wav"
TINTA_LUFS=-13
# 24. stingerul de apariție (~3 s, stereo): lovitura de groază (Stinger) peste pianul disonant și un bas care cade.
# Când apare Warlock-ul în spatele vostru la motel și când te vede Head Witch.
ffmpeg -v error -y -i "$P2/Stingers and Spooky Triggers/Stinger.wav" -i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent.wav" -f lavfi -i "$(sub 65 25 3 1.2 1)" -filter_complex \
	"[0]$(b 0 2.1 0.9)[a];[1]$(b 0 2.9 0.85),volume=0.8[p];[a][p][2]$MIX=3,$DENS,$ECOU_MARE,atrim=end=3.4,afade=t=out:st=2.6:d=0.8,$STEREO" \
	-ac 2 "$OUT/_stinger.wav"
unic stinger_aparitie "$OUT/_stinger.wav" stereo
# 25. „YOU DIED” (~5,5 s, stereo): clopotul grav (Bell_low încetinit), pianul disonant care se stinge, chitara care
# alunecă în jos și o bubuitură în piept
ffmpeg -v error -y -i "$P2/Ambient/Bell_low.wav" -i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent_2.wav" -i "$P2/Stingers and Spooky Triggers/Slide guitar_decreasing pitch.wav" -f lavfi -i "$(sub 52 30 5.5 1.4 1.1)" -filter_complex \
	"[0]$(b 0 5.5 0.8),volume=4[c];[1]$(b 0 2.15 0.7),volume=0.8[p];[2]$(b 0.15 4.65 0.85),adelay=300,volume=0.6[g];[c][p][g][3]$MIX=4,$DENS,$ECOU_MARE,atrim=end=5.5,afade=t=out:st=4.2:d=1.3,$STEREO" \
	-ac 2 "$OUT/_murit.wav"
unic ai_murit "$OUT/_murit.wav" stereo
# 26. „… DEFEATED” (~4,5 s, stereo): acordul luminos-înfiorător (Harmonized Tone), sclipirea (Ability Ready), o bufnitură
# blândă dedesubt
ffmpeg -v error -y -i "$P2/Stingers and Spooky Triggers/Harmonized Tone_Pleasant but Spooky.wav" -i "$P3/MAGSpel_Anime Ability Ready 3.wav" -i "$P3/FGHTBf_Anime Land 12.wav" -filter_complex \
	"[0]$(b 0 4.5 1)[h];[1]$(b 0 1.1 1),volume=0.5[r];[2]$(b 0 0.95 0.6),lowpass=f=600,volume=0.8[l];[h][r][l]$MIX=3,$ECOU_MARE,atrim=end=4.8,afade=t=out:st=3.6:d=1.2,$STEREO" \
	-ac 2 "$OUT/_doborat.wav"
unic inamic_doborat "$OUT/_doborat.wav" stereo
# 27. Head Witch îi absoarbe puterile Warlock-ului (~6 s): corul fantomelor care se umflă, energia trasă (încărcarea
# Shonen întoarsă = aer care se strânge), pârâitul, apoi la 4,8 s implozia: explozia scurtă coborâtă și basul
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Ghost chior.wav" -i "$P3/MAGSpel_Anime Ability Release 4.wav" -i "$P3/ELECSprk_Anime Spark 4.wav" \
	-i "$P3/EXPLDsgn_Anime Explosion 4.wav" -f lavfi -i "$(sub 70 25 1.2 2.5 1.2)" -filter_complex \
	"[0]$(b 3 8 0.85),afade=t=in:d=3,afade=t=out:st=4.9:d=0.3,volume=0.7[c];[1]$(b 0 2.4 0.9),areverse,adelay=2400[r];[2]$(b 0 3.1 1),highpass=f=1200,adelay=1600,volume=0.6[s];[3]$(b 0 1.4 0.7),lowpass=f=1800,adelay=4800[e];[4]adelay=4800[b];[c][r][s][e][b]$MIX=5,$DENS,$ECOU_MARE,atrim=end=6.5,afade=t=out:st=5.6:d=0.9,$STEREO" \
	-ac 2 "$OUT/_absorbtie.wav"
unic absorbtie "$OUT/_absorbtie.wav" stereo

# --- Head Witch (City Center)
# 28. urletul ei (~2,5 s, 3D): țipătul de fantomă peste un țipăt de om și un mârâit, ca o vrăjitoare furioasă
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Ghost_scream_3.wav" -i "$P2/Ambient/Scream.wav" -i "$P2/Monsters & Ghosts/Monster_growl_1.wav" -filter_complex \
	"[0]$(b 0 2.6 0.95)[g];[1]$(b 0 2.15 0.9),volume=0.5[s];[2]$(b 0 1.7 0.8),volume=0.5[m];[g][s][m]$MIX=3,$DENS,$ECOU_MARE,atrim=end=3,afade=t=out:st=2.2:d=0.8" \
	-ac 1 "$OUT/_urlet_s.wav"
unic sefa_urlet "$OUT/_urlet_s.wav"
# 29. ea ca demon (faza a doua; ~4,5 s, 3D, -12): urletul de monstru coborât, țipătul de fantomă dedesubt, mârâitul, basul
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Monster_Roar_4.wav" -i "$P2/Monsters & Ghosts/Ghost_scream_3.wav" -i "$P2/Monsters & Ghosts/Monster_growl_5.wav" -f lavfi -i "$(sub 40 25 4.5 0.5 0.7)" -filter_complex \
	"[0]$(b 0 4.15 0.62)[r];[1]$(b 0 4.1 0.75),volume=0.5[g];[2]$(b 0 1.75 0.55),volume=0.6[m];[3]afade=t=in:d=0.3[s];[r][g][m][s]$MIX=4,$DENS,$ECOU_MARE,atrim=end=5,afade=t=out:st=3.8:d=1.2" \
	-ac 1 "$OUT/_raget.wav"
TINTA_LUFS=-12
unic sefa_demon_raget "$OUT/_raget.wav"
TINTA_LUFS=-13
# 30. ea strânge puterea (~2,6 s, 3D; te vede / nova): riser-ul de groază, geamătul adânc și încărcarea Shonen
ffmpeg -v error -y -i "$P2/Stingers and Spooky Triggers/Suspenseful pitch increase.wav" -i "$P2/Monsters & Ghosts/Tone_Moaning_Deep_3.wav" -i "$P3/MAGSpel_Anime Ability Charge 8.wav" -filter_complex \
	"[0]$(b 2.5 5.1 1)[r];[1]$(b 0 2.6 0.9),volume=3[m];[2]$(b 0 2.2 0.9),volume=0.8,adelay=300[c];[r][m][c]$MIX=3,$DENS,volume='0.4+0.6*t/2.6':eval=frame,atrim=end=2.6,afade=t=out:st=2.4:d=0.2" \
	-ac 1 "$OUT/_chemare.wav"
TINTA_LUFS=-14
unic sefa_chemare "$OUT/_chemare.wav"
TINTA_LUFS=-13
# 31. corul ei (~4 s, stereo): îi ridică pe oameni în aer / se ridică la transformare: corul fantomelor, acordul înfiorător
# și o încărcare coborâtă
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Ghost chior.wav" -i "$P2/Stingers and Spooky Triggers/Harmonized Tone_Pleasant but Spooky.wav" -i "$P3/MAGSpel_Anime Ability Charge 4.wav" -filter_complex \
	"[0]$(b 6 10.5 1),afade=t=in:d=0.6[c];[1]$(b 0 4 0.75),volume=0.6[h];[2]$(b 0 3.15 0.8),volume=0.6[i];[c][h][i]$MIX=3,$DENS,$ECOU_MARE,atrim=end=4.3,afade=t=out:st=3.4:d=0.9,$STEREO" \
	-ac 2 "$OUT/_cor.wav"
unic sefa_cor "$OUT/_cor.wav" stereo
# 32. poarta de ceață se închide (~2,8 s, 3D): drone-ul de groază coborât și eliberarea lungă de energie
ffmpeg -v error -y -i "$P2/Ambient/Drone_doom.wav" -i "$P3/MAGSpel_Anime Ability Release 4.wav" -f lavfi -i "$(sub 50 35 2.8 1 0.5)" -filter_complex \
	"[0]$(b 0 3 0.75),volume=3[d];[1]$(b 0 2.4 0.7),volume=0.8[r];[d][r][2]$MIX=3,$DENS,$ECOU_MARE,atrim=end=3,afade=t=out:st=2.2:d=0.8" \
	-ac 1 "$OUT/_poarta.wav"
TINTA_LUFS=-14
unic poarta_ceata "$OUT/_poarta.wav"
TINTA_LUFS=-13
# 33. transformarea: lumina albă (~5 s, stereo, -12): explozia lungă, eliberarea de energie, urletul de monstru încetinit,
# gheața care crapă (pielea care se rupe) și stingerul de pian
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 11.wav" -i "$P3/MAGSpel_Anime Ability Release 5.wav" -i "$P2/Monsters & Ghosts/Monster_Roar_2.wav" \
	-i "$P4/Spells/Ice Barrage 1.wav" -i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent.wav" -f lavfi -i "$(sub 60 20 5 0.8 1.2)" -filter_complex \
	"[0]$(b 0 3.15 0.7),lowpass=f=3000[e];[1]$(b 0 1.7 0.9),volume=0.8[r];[2]$(b 0 1.15 0.55),volume=0.8,adelay=150[m];[3]$(b 0 2.1 0.8),volume=0.6[g];[4]$(b 0 2.9 0.8),volume=0.6[p];[e][r][m][g][p][5]$MIX=6,$DENS,$ECOU_MARE,atrim=end=5.5,afade=t=out:st=4:d=1.5,$STEREO" \
	-ac 2 "$OUT/_transformare.wav"
TINTA_LUFS=-12
unic sefa_transformare "$OUT/_transformare.wav" stereo
TINTA_LUFS=-13
# 34. zboară pe mătură spre tine (~1,3 s, 3D): vâjâitul Shonen și focul care trece
ffmpeg -v error -y -i "$P3/SWSH_Anime Fly 5.wav" -i "$P3/FGHTMisc_Anime Dodge 4.wav" -i "$P4/Spells/Fireball 3.wav" -filter_complex \
	"[0]$(b 0 1.1 0.85)[w];[1]$(b 0 0.6 0.9),volume=0.7[d];[2]$(b 0 1.2 0.8),volume=0.5[f];[w][d][f]$MIX=3,$DENS,atrim=end=1.4,afade=t=out:st=1:d=0.4" \
	-ac 1 "$OUT/_matura.wav"
unic matura_atac "$OUT/_matura.wav"
# 35. raza care mătură piața (~2,8 s, 3D): flacăra continuă (Firespray), pârâitul electric și un zumzet jos
ffmpeg -v error -y -i "$P4/Spells/Firespray 2.wav" -i "$P3/ELECSprk_Anime Spark 3.wav" -i "$P3/MAGSpel_Anime Ability Charge 17.wav" -filter_complex \
	"[0]$(b 0 2.1 0.85)[f];[1]$(b 0 3 1),volume=0.7[s];[2]$(b 0 3 0.7),lowpass=f=700,volume=0.6[h];[f][s][h]$MIX=3,$DENS,atrim=end=2.8,afade=t=in:d=0.05,afade=t=out:st=2.4:d=0.4" \
	-ac 1 "$OUT/_raza.wav"
unic raza_matura "$OUT/_raza.wav"
# 36. o rază de lumină țâșnește din ea la final (~0,9 s, 3D, -15; nouă una după alta)
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Release 6.wav" -i "$P3/ELECSprk_Anime Spark 2.wav" -filter_complex \
	"[0]$(b 0 0.7 1)[r];[1]$(b 0 0.5 1.2),highpass=f=1500,volume=0.6[s];[r][s]$MIX=2,$ECOU_MIC,atrim=end=1,afade=t=out:st=0.7:d=0.3" \
	-ac 1 "$OUT/_tasneste.wav"
TINTA_LUFS=-15
unic raza_tasneste "$OUT/_tasneste.wav"
TINTA_LUFS=-13
# 37. explozia ei finală (~8 s, stereo, -10: vârful jocului): explozia lungă coborâtă + cea seacă, țipătul ei care se pierde în explozie,
# basul 55 -> 16 Hz și ecoul străzilor
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 8.wav" -i "$P3/EXPLDsgn_Anime Explosion 10.wav" -i "$P2/Monsters & Ghosts/Ghost_scream_3.wav" -f lavfi -i "$(sub 55 16 8 0.5 1.3)" \
	-i "$P2/Stingers and Spooky Triggers/Harmonized Tone_Pleasant but Spooky.wav" -filter_complex \
	"[0]$(b 0 3.1 0.65),lowpass=f=2400,volume=1.3[e];[1]$(b 0 1.95 1),volume=0.7[p];[2]$(b 0 4.1 1),afade=t=out:st=0.5:d=2.5,volume=0.5[s];[4]$(b 0 4 0.5),afade=t=in:st=0:d=1.5,adelay=1500,volume=0.5[h];[e][p][s][3][h]$MIX=5,$DENS,$ECOU_MARE,atrim=end=8,afade=t=out:st=6:d=2,$STEREO" \
	-ac 2 "$OUT/_final.wav"
TINTA_LUFS=-10
unic sefa_explozie_finala "$OUT/_final.wav" stereo
TINTA_LUFS=-13
# 38. ploaia de meteoriți începe (~2,5 s, 3D): roiul de pietre (Rock Meteor Swarm) peste tunetul adevărat
ffmpeg -v error -y -i "$P4/Spells/Rock Meteor Swarm 1.wav" -i "$FURTUNA" -filter_complex \
	"[0]$(b 0 1.9 0.85)[m];[1]$(b 17.4 20 1),lowpass=f=700,volume=1.5[t];[m][t]$MIX=2,$DENS,atrim=end=2.6,afade=t=out:st=2:d=0.6" \
	-ac 1 "$OUT/_meteori.wav"
unic meteori "$OUT/_meteori.wav"
TINTA_LUFS=$TINTA_NORMALA_LUPTE
rm -f "$OUT"/_tunet.wav "$OUT"/_fulger.wav "$OUT"/_corn.wav "$OUT"/_aparitie.wav "$OUT"/_sosire.wav "$OUT"/_vraja.wav "$OUT"/_impact.wav \
	"$OUT"/_spart.wav "$OUT"/_incarcare.wav "$OUT"/_boss_incarcare.wav "$OUT"/_orb_zbor.wav "$OUT"/_orb_bum.wav "$OUT"/_boss_glob.wav \
	"$OUT"/_cerc.wav "$OUT"/_unda.wav "$OUT"/_parare.wav "$OUT"/_lovit_tu.wav "$OUT"/_boss_lovit.wav "$OUT"/_cazi.wav "$OUT"/_durere.wav \
	"$OUT"/_urlet_w.wav "$OUT"/_moare_w.wav "$OUT"/_ras.wav "$OUT"/_stinger.wav "$OUT"/_murit.wav "$OUT"/_doborat.wav "$OUT"/_absorbtie.wav \
	"$OUT"/_urlet_s.wav "$OUT"/_raget.wav "$OUT"/_chemare.wav "$OUT"/_cor.wav "$OUT"/_poarta.wav "$OUT"/_transformare.wav "$OUT"/_matura.wav \
	"$OUT"/_raza.wav "$OUT"/_tasneste.wav "$OUT"/_final.wav "$OUT"/_meteori.wav


# --- ceaunul de acasă și demonul, refăcute „de film” (10.10) din pachetele noi (vezi „luptele cu vrăjitorii” mai sus:
# P2 / P3 / P4, `b`, `sub`, `MIX`, ecourile). ceaun_acasa.gd + demon.gd; aceleași nume, plus `demon_voce` (sub replica
# lui). Timpii sunt ai scenei:
#   ceaunul se încinge 4 s, apoi explozia; chemarea: pentagrama 2 s, stâlpul de lumină la 2 s, demonul urcă 2,6 s și
#   răcnește la ~4,9 s de la începutul chemării; teleportul: sunetul pornește la 0,22 s, el dispare la ~0,53 s.
# Explozia, chemarea și răgetul sunt stereo, în 2D (Sunet.reda): sunt „ale camerei”, nu ale unui punct.
TINTA_NORMALA_DEMON=$TINTA_LUFS

# 1. ceaunul se încinge (~4,1 s, 3D): fierberea care o ia razna, sfârâitul, fonta care geme sub presiune (rezonanța de
# metal coborâtă, scârțâind), încărcarea Shonen care tot urcă și un bas care se umflă; se taie scurt la 4 s, chiar
# înainte de bubuitură (o clipă de „vid”)
ffmpeg -v error -y -i "$P2/House & Office/Water_Boiling_4.wav" -i "$P2/House & Office/Food_sizzling_5.wav" \
	-i "$P2/Stingers and Spooky Triggers/Metal_resonance.wav" -i "$P3/MAGSpel_Anime Ability Charge 10.wav" \
	-i "$P2/Stingers and Spooky Triggers/Metal_twang.wav" -f lavfi -i "$(sub 32 58 4.1 0 0.9)" -filter_complex \
	"[0]$(b 0.3 5.63 1.3),volume='0.35+0.9*t/4.1':eval=frame[f];[1]$(b 0 4.1 1),highpass=f=1500,volume='0.1+0.6*pow(t/4.1\,2)':eval=frame[z];[2]$(b 0 4.1 0.55),lowpass=f=1300,vibrato=f=3:d=0.3,volume='pow(t/4.1\,2)*1.6':eval=frame[m];[3]$(b 0 3.2 0.9),adelay=850,volume=0.55[i];[4]$(b 0 1 0.7),asplit=2[k0][k1];[k0]adelay=2300,volume=0.5[k2];[k1]asetrate=44100*1.15,aresample=44100,adelay=3250,volume=0.6[k3];[5]volume='pow(t/4.1\,2.5)':eval=frame[s];[f][z][m][i][k2][k3][s]$MIX=7,$DENS,atrim=end=4.1,afade=t=out:st=3.98:d=0.12" \
	-ac 1 "$OUT/_incins.wav"
TINTA_LUFS=-16
unic ceaun_incins "$OUT/_incins.wav"

# 2. explozia ceaunului (~5,5 s, stereo): două explozii Shonen coborâte una peste alta (pocnetul + corpul), fonta care se
# sparge (piatra Fantasy + metalul vechi), poțiunea care plesnește pe pereți (gore ud), cioburile care sună, un bas care
# cade 90 -> 22 Hz și vuietul lung al camerei. În joc, după 0,35 s totul se înfundă (_asurzeste): basul și vuietul
# rămân, deci ele duc greul.
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 11.wav" -i "$P3/EXPLDsgn_Anime Explosion 2.wav" -i "$P4/Spells/Rock Wall 2.wav" \
	-i "$PACHET/Materials/metal_clang.wav" -i "$P2/Monsters & Ghosts/Gore_Wet_7.wav" -i "$P2/Stingers and Spooky Triggers/Metal_twang.wav" \
	-f lavfi -i "$(sub 90 22 5.5 0.9 1.4)" -f lavfi -i "anoisesrc=c=brown:a=1:d=5.5:r=44100:s=31" -filter_complex \
	"[0]$(b 0 3.15 0.72),lowpass=f=4000[e];[1]$(b 0 1.85 0.9),volume=0.8[p];[2]$(b 0 2 0.8),adelay=40,volume=0.8[r];[3]aformat=channel_layouts=mono,aresample=44100,asetrate=44100*0.7,aresample=44100,volume=0.7[m];[4]$(b 0 1.1 0.8),adelay=80,volume=0.6[g];[5]$(b 0 1 0.6),asplit=2[t0][t1];[t0]adelay=700,volume=0.35[t2];[t1]asetrate=44100*1.3,aresample=44100,adelay=1250,volume=0.25[t3];[6]volume=1[s];[7]lowpass=f=220,volume='1.3*exp(-t*0.8)':eval=frame[v];[e][p][r][m][g][t2][t3][s][v]$MIX=9,$DENS,$ECOU_MARE,atrim=end=5.5,afade=t=out:st=4.3:d=1.2,$STEREO" \
	-ac 2 "$OUT/_explozie.wav"
TINTA_LUFS=-12
unic ceaun_explozie "$OUT/_explozie.wav" stereo

# 3. chemarea demonului (~8 s, stereo): drone-ul de groază și corul fantomelor coborât, care se strâng ca o rugăciune
# întoarsă; un geamăt adânc care urcă; la 2 s stâlpul de lumină (eliberarea Shonen + flacăra Fantasy), apoi podeaua
# care se rupe sub el (zidul de piatră coborât) cât urcă (2-4,6 s), cu inima tot mai rapidă și urcarea de pian care
# se oprește la 4,8 s, ca răgetul (la ~4,9 s) să intre în liniște; dedesubt rămâne drone-ul, sub replica lui
ffmpeg -v error -y -i "$P2/Ambient/Drone_doom.wav" -i "$P2/Monsters & Ghosts/Ghost chior.wav" -i "$P2/Monsters & Ghosts/Tone_Moaning_Deep_3.wav" \
	-i "$P3/MAGSpel_Anime Ability Release 11.wav" -i "$P4/Spells/Firebuff 1.wav" -i "$P4/Spells/Rock Wall 1.wav" \
	-i "$P2/Stingers and Spooky Triggers/Suspenseful pitch increase.wav" -f lavfi -i "$(sub 30 48 8 0 0.7)" \
	-f lavfi -i "aevalsrc='0$(inima 2.6 0.7)$(inima 3.3 0.8)$(inima 3.85 0.9)$(inima 4.3 1)':s=44100:d=5" -filter_complex \
	"[0]$(b 0 4.75 0.75),volume=2.2,asplit=2[d0][d1];[d1]areverse[d2];[d0][d2]concat=n=2:v=0:a=1,atrim=end=8,afade=t=in:d=1.2[d];[1]$(b 2 10 0.62),lowpass=f=1600,volume='0.15+0.55*min(t/4.6\,1)':eval=frame,afade=t=out:st=4.7:d=0.25,volume=0.7[c];[2]$(b 0 8 0.7),lowpass=f=900,volume='0.4+0.8*min(t/4.6\,1)':eval=frame[g];[3]$(b 0 3.55 0.8),adelay=2000,volume=0.6[l];[4]$(b 0 1.3 0.8),adelay=1950,volume=0.6[fl];[5]$(b 0 2 0.6),lowpass=f=1800,adelay=2150,volume=0.9,asplit=2[p0][p1];[p1]adelay=1200,volume=0.6[p2];[6]$(b 2.3 6.4 1),volume='pow(min(t/2.5\,1)\,2)*0.7':eval=frame,adelay=700,afade=t=out:st=4.72:d=0.08[u];[7]volume='min(t/4.6\,1)':eval=frame[s];[8]lowpass=f=200,volume=1.1[h];[d][c][g][l][fl][p0][p2][u][s][h]$MIX=10,$DENS,volume='if(lt(t\,4.8)\,0.25+0.75*pow(t\/4.8\,1.6)\,0.4)':eval=frame,atrim=end=8,afade=t=out:st=6:d=2,$STEREO" \
	-ac 2 "$OUT/_chemare.wav"
TINTA_LUFS=-15
unic demon_chemare "$OUT/_chemare.wav" stereo

# 4. răgetul (~4 s, stereo): trei fiare coborâte una peste alta (răgetul scurt de monstru încetinit pentru corp, mârâitul
# lung pentru gât, mârâitul gros dedesubt), aripile care se deschid (zborul Shonen, coborât), un bas, stingerul
# disonant de pian și ecoul mare. Diferit de al lui Head Witch (sefa_demon_raget): alte voci, mai grav.
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Monster_Roar_2.wav" -i "$P2/Monsters & Ghosts/Monster_grunt_long.wav" \
	-i "$P2/Monsters & Ghosts/Monster_growl_5.wav" -i "$P3/SWSH_Anime Fly 3.wav" -f lavfi -i "$(sub 65 32 3 1.2 1)" \
	-i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent_2.wav" -filter_complex \
	"[0]$(b 0 1.2 0.5),lowpass=f=2400,volume=1.1[a];[1]$(b 0 2.5 0.62),lowpass=f=1800,volume=0.8[c];[2]$(b 0 1.8 0.55),lowpass=f=900,adelay=100,volume=0.8[d];[3]$(b 0 1.1 0.6),adelay=120,volume=0.5[w];[5]$(b 0 2.15 0.85),adelay=60,volume=0.45[p];[a][c][d][w][4][p]$MIX=6,acrusher=bits=10:mix=0.25,$DENS,$ECOU_MARE,atrim=end=4,afade=t=out:st=3:d=1,$STEREO" \
	-ac 2 "$OUT/_raget.wav"
TINTA_LUFS=-13
unic demon_raget "$OUT/_raget.wav" stereo

# 5. vocea lui, sub replică (~2,5 s, 3D): o respirație de fiară coborâtă și un mârâit adânc, ca să nu „vorbească” doar
# bipul din Dialog
ffmpeg -v error -y -i "$P2/Monsters & Ghosts/Monster_breath.wav" -i "$P2/Monsters & Ghosts/Monster_grunt x2 (ghmmm).wav" \
	-i "$P2/Monsters & Ghosts/Tone_Moaning.wav" -filter_complex \
	"[0]$(b 0 1.48 0.6),lowpass=f=1500[r];[1]$(b 0 1.2 0.55),lowpass=f=1100,adelay=500,volume=0.7[m];[2]$(b 0 1.9 0.5),lowpass=f=700,volume=0.5[t];[r][m][t]$MIX=3,$DENS,$ECOU_MIC,atrim=end=2.6,afade=t=out:st=1.9:d=0.7" \
	-ac 1 "$OUT/_voce_demon.wav"
TINTA_LUFS=-18
unic demon_voce "$OUT/_voce_demon.wav"

# 6. glonțul intră în el (~1,2 s, 3D): lovitura Shonen cu sânge, carnea ruptă, și un urlet scurt de durere, foarte jos
ffmpeg -v error -y -i "$P3/FGHTImpt_Anime Melee Gore 2.wav" -i "$P2/Monsters & Ghosts/Gore_Ripping_5.wav" -i "$P2/Monsters & Ghosts/Zombie_6.wav" \
	-f lavfi -i "$(sub 80 45 0.6 8 0.7)" -filter_complex \
	"[0]$(b 0 0.6 0.85)[i];[1]$(b 0.25 1.3 0.9),volume=0.7[g];[2]$(b 0 0.85 0.55),lowpass=f=1500,adelay=90,volume=0.9[u];[i][g][u][3]$MIX=4,$DENS,$ECOU_MIC,atrim=end=1.3,afade=t=out:st=0.9:d=0.4" \
	-ac 1 "$OUT/_lovit.wav"
TINTA_LUFS=-15
unic demon_lovit "$OUT/_lovit.wav"

# 7. se dezintegrează (~5 s, 3D): urletul lui de agonie (țipătul coborât, apoi încă unul mai jos), flacăra care îl
# cuprinde (Firespray + sfârâitul), la 1,5 s corpul care se surpă în scrum (piatra coborâtă, carnea ruptă), un vânt de
# cenușă (vâjâitul întors) și basul care se stinge; la capăt, o notă de pian disonant, ca un ecou
ffmpeg -v error -y -i "$P2/Ambient/Scream.wav" -i "$P2/Monsters & Ghosts/Ghost_moan_2.wav" -i "$P4/Spells/Firespray 1.wav" \
	-i "$P2/House & Office/Food_sizzling.wav" -i "$P4/Spells/Rock Wall 2.wav" -i "$P2/Monsters & Ghosts/Gore_Ripping_4.wav" \
	-i "$P2/Character/woosh_5.wav" -f lavfi -i "$(sub 60 25 5 0.6 0.9)" -i "$P2/Stingers and Spooky Triggers/Slow Stinger.wav" -filter_complex \
	"[0]$(b 0 2.15 0.55),lowpass=f=2500,volume=1.1[u1];[1]$(b 0 3 0.6),lowpass=f=1400,adelay=1300,volume=0.8[u2];[2]$(b 0 2.1 0.9),volume=0.8,afade=t=in:d=0.2[f];[3]$(b 0 2.39 0.8),highpass=f=1200,adelay=300,volume=0.5[z];[4]$(b 0 2 0.5),lowpass=f=1500,adelay=1500,volume=0.8[p];[5]$(b 0 1.1 0.7),adelay=1550,volume=0.6[g];[6]aformat=channel_layouts=mono,aresample=44100,areverse,asetrate=44100*0.7,aresample=44100,adelay=1800,volume=0.6[w];[8]$(b 2.55 4.3 0.8),adelay=3200,volume=0.5[n];[u1][u2][f][z][p][g][w][7][n]$MIX=9,$DENS,$ECOU_MARE,atrim=end=5.2,afade=t=out:st=4.2:d=1" \
	-ac 1 "$OUT/_dezintegrare.wav"
TINTA_LUFS=-13
unic demon_dezintegrare "$OUT/_dezintegrare.wav"

# 8. se teleportează (~2,5 s, 3D): aerul tras spre el (încărcarea Shonen întoarsă, ~0,3 s), pocnitura la 0,31 s (când
# dispare: explozia scurtă + scânteia roșie + bas) și râsul lui care se pierde în ecou
ffmpeg -v error -y -i "$P3/MAGSpel_Anime Ability Charge 12.wav" -i "$P3/EXPLDsgn_Anime Explosion 5.wav" -i "$P3/ELECSprk_Anime Spark 1.wav" \
	-f lavfi -i "$(sub 90 35 1.5 4 1)" -i "$P2/Monsters & Ghosts/Laugh_spooky_4.wav" -filter_complex \
	"[0]$(b 0 0.9 1),areverse,atrim=start=0.59,asetpts=PTS-STARTPTS,afade=t=in:d=0.05,volume=0.9[s];[1]$(b 0 1.45 0.8),lowpass=f=3000,adelay=310[e];[2]$(b 0 0.65 0.9),adelay=310,volume=0.6[c];[3]adelay=310[b];[4]$(b 0 2 0.55),lowpass=f=1800,adelay=650,volume=0.55,afade=t=out:st=1.8:d=0.85[r];[s][e][c][b][r]$MIX=5,$DENS,$ECOU_MARE,atrim=end=2.8,afade=t=out:st=2:d=0.8" \
	-ac 1 "$OUT/_teleport.wav"
TINTA_LUFS=-14
unic demon_teleport "$OUT/_teleport.wav"
TINTA_LUFS=$TINTA_NORMALA_DEMON
rm -f "$OUT"/_incins.wav "$OUT"/_explozie.wav "$OUT"/_chemare.wav "$OUT"/_raget.wav "$OUT"/_voce_demon.wav "$OUT"/_lovit.wav \
	"$OUT"/_dezintegrare.wav "$OUT"/_teleport.wav

# --- muzica adusă de owner (10.10), toate în buclă din import (loop=true). Timpii de tăiere sunt după liniștea de la
# început (silenceremove); coada de liniște iese, ca bucla să reînceapă repede.
#  - muzica_afara: afară la Sketchy Laundromat, Gun Store și Town Hall (muzica_loc.gd cu `doar_afara`: se stinge când
#    intri în clădire, revine când ieși);
#  - muzica_lexy_afara: afară la Lexy (înăuntru e muzica_lexy);
#  - muzica_poker: doar în camera de poker din spatele spălătoriei;
#  - muzica_lupta_warlock / muzica_lupta_head_witch: luptele (lupta_boss.gd). Sunt mai tari decât restul (-18 LUFS, ca
#    vechea muzică de boss sintetizată, pe care au înlocuit-o): în luptă se bat cu exploziile. Merg cap-coadă în buclă,
#    deci doar o stingere de 30 ms la capăt, să nu pocnească la reluare.
unic muzica_afara "Sound/Music/Afara General.mp3" stereo "atrim=end=121.5,afade=t=out:st=119.5:d=2"
unic muzica_lexy_afara "Sound/Music/Afara la Lexy.mp3" stereo "atrim=end=184.3,afade=t=out:st=183.3:d=1"
unic muzica_poker "Sound/Music/Poker Room.mp3" stereo "atrim=end=120.6,afade=t=out:st=120.2:d=0.4"
TINTA_LUFS=-18
unic muzica_lupta_warlock "Sound/Music/Warlock Battle.mp3" stereo "atrim=end=140.0,afade=t=out:st=139.97:d=0.03"
unic muzica_lupta_head_witch "Sound/Music/Head Witch Battle.ogg" stereo "atrim=end=99.48,afade=t=out:st=99.45:d=0.03"
TINTA_LUFS=-20

# --- perechea din spatele blocului (afara_bloc.tscn, pereche.gd): gâfâitul în buclă (încet, 3D), ușa de tablă a
# garajului lovită în ritm (bufnitură surdă, tabla vibrează), „gasp”-ul când îi prinzi, fermoarul tras din fugă.
# Din `Sound/Soundpack 2` (Horror SFX Free, licență neverificată) și pachetul de bază.
bucla pereche_gafait "Sound/Soundpack 2/Character/Breathing_fast.wav" 0.4 mono "aformat=channel_layouts=mono,highpass=f=150,lowpass=f=5000"
unic garaj_bufnit "Materials/metal_blunt_tap.wav" mono "aformat=channel_layouts=mono,asetrate=44100*0.55,aresample=44100,lowpass=f=900,equalizer=f=120:t=q:w=1:g=6,aecho=0.7:0.5:28:0.35,afade=t=out:st=0.25:d=0.35"
unic pereche_gasp "Sound/Soundpack 2/Character/Gasp.wav" mono "aformat=channel_layouts=mono"
unic pereche_gasp_2 "Sound/Soundpack 2/Character/Gasp_3.wav" mono "aformat=channel_layouts=mono,asetrate=48000*1.12,aresample=48000"
unic fermoar "Sound/Soundpack 2/Character/Zipper up.wav" mono "aformat=channel_layouts=mono"

# --- sacrificiul din coven refăcut „de film” (11.10, owner: „mai cinematic și mai dramatic”) din pachetele noi
# (P2 Horror, P3 Shonen, P4 Fantasy, FURTUNA, `b`, `sub`, MIX, ECOU_* de la „luptele cu vrăjitorii”; DENS, STEREO, inima,
# voce de la sacrificiul vechi). Aceleași 4 fișiere și ACEEAȘI cronologie ca înainte (cazan.gd nu se schimbă):
# plescăit (2 s, 3D) -> 0,9+0,5 s -> cor (3,9 s) -> la 1,5 s în cor, unda (EXACT 2,5 s, liniște de la 2,42) -> bubuitura.
TINTA_NORMALA_SACRIFICIU=$TINTA_LUFS
TINTA_LUFS=-13
# 1. corpul cade în cazan (2 s, 3D): pleoscăitul greu (Liquid splash încetinit + vechiul water_splashing), carnea udă
# (Gore_Wet), trântitura de anime coborâtă (corpul lovește fundul), basul și bulele mari care „înghit”
ffmpeg -v error -y -i "$P2/Liquids/Liquid_plash poor.wav" -i "$PACHET/Environment/water_splashing.wav" -i "$P2/Monsters & Ghosts/Gore_Wet_7.wav" \
	-i "$P3/FGHTBf_Anime Land 11.wav" -f lavfi -i "$(sub 62 30 2 4 1.0)" -i "$P2/Liquids/Bubbles.wav" -filter_complex \
	"[0]$(b 0 1.1 0.7),lowpass=f=3000,volume=1.2[a];[1]$(b 0 2 0.62),lowpass=f=2400,volume=0.7[w];[2]$(b 0 1 0.75),adelay=60,volume=0.8[g];[3]$(b 0 0.7 0.6),lowpass=f=900,adelay=120,volume=0.9[l];[5]$(b 3 5 0.55),lowpass=f=1000,afade=t=in:d=0.15,afade=t=out:st=0.9:d=0.5,adelay=600,volume=0.9[u];[a][w][g][l][4][u]$MIX=6,$DENS,$ECOU_MIC,atrim=end=2,afade=t=out:st=1.5:d=0.5" \
	-ac 1 "$OUT/_plescait.wav"
TINTA_LUFS=-15
unic cazan_plescait "$OUT/_plescait.wav"
TINTA_LUFS=-13
# 2. corul (3,9 s): corul sintetizat vechi pe acordul disonant (cu sopranele și inima tot mai rapidă) peste corul ADEVĂRAT
# al fantomelor (Ghost chior, coborât), drone-ul de pian grav, riser-ul de groază care urcă și energia Shonen care se
# adună de la 1,5 s (Ability Charge). Se stinge la 3,65-3,9 s, înainte de liniștea din undă.
COR="0.11*($(voce 55 0.3)+$(voce 73.42 0)+$(voce 110 1.1)+$(voce 146.83 2.3)+$(voce 174.61 0.6)+$(voce 207.65 1.7))*pow(min(t/3.7\,1)\,1.8)"
SOPRANE="0.07*($(voce 587.33 0.4)+$(voce 622.25 2.0))*pow(max(0\,(t-1.6)/2.1)\,2)"
INIMA="0$(inima 0.30 0.3)$(inima 1.10 0.38)$(inima 1.80 0.46)$(inima 2.38 0.55)$(inima 2.86 0.64)$(inima 3.24 0.73)$(inima 3.55 0.82)"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$COR+$SOPRANE':s=44100:d=4" -f lavfi -i "aevalsrc='$INIMA':s=44100:d=4" \
	-i "$P2/Monsters & Ghosts/Ghost chior.wav" -i "$P2/Stingers and Spooky Triggers/Piano_drone_low_sustained_2.wav" \
	-i "$P2/Stingers and Spooky Triggers/Suspenseful pitch increase.wav" -i "$P3/MAGSpel_Anime Ability Charge 17.wav" -filter_complex \
	"[0]equalizer=f=700:t=q:w=1.2:g=8,equalizer=f=1150:t=q:w=1.5:g=5,lowpass=f=3200,chorus=0.6:0.9:40|55|70:0.4|0.35|0.3:0.3|0.4|0.5:2|2.5|1.7[c];[1]lowpass=f=300,volume=1.6[h];[2]$(b 1 5 0.85),volume='0.15+0.85*pow(t/3.7\,1.5)':eval=frame,volume=1.1[f];[3]$(b 0 4 0.8),lowpass=f=1200,afade=t=in:d=0.8,volume=0.7[p];[4]$(b 0 4 1),volume='pow(t/3.8\,2)':eval=frame,volume=0.6[r];[5]$(b 0 3.25 0.75),afade=t=in:d=0.6,adelay=1500,volume=0.45[e];[c][h][f][p][r][e]$MIX=6,$DENS,afade=t=in:d=0.6,$STEREO,afade=t=out:st=3.65:d=0.25,atrim=end=3.9" \
	-ac 2 "$OUT/_cor.wav"
unic vraja_cor "$OUT/_cor.wav" stereo
# 3. unda de lumină (EXACT 2,5 s; la 2,42 s liniște absolută până la bubuitură): pornirea = eliberarea de energie Shonen
# (Ability Release) + BRAAM-ul vechi + trântitura; apoi raza care țiuie și urcă (sinusul 70 -> 600 Hz), încărcarea Shonen
# care crește, scânteile electrice tot mai dese și explozia Shonen ÎNTOARSĂ care „trage aerul” fix până la 2,42 s.
FINAL_UNDA=2.42
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 6.wav" -af "$(b 0 3.4 0.8),lowpass=f=3000,areverse" "$OUT/_invers.wav"
L=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/_invers.wav")
TAIERE=$(awk -v l="$L" -v f="$FINAL_UNDA" 'BEGIN { s = l - f; if (s < 0) s = 0; printf "%.3f", s }')
INTARZIERE=$(awk -v l="$L" -v f="$FINAL_UNDA" 'BEGIN { d = (f - l) * 1000; if (d < 0) d = 0; printf "%d", d }')
BRAAM="0.24*($(voce 36.71 0)+$(voce 55 1)+$(voce 73.42 2)+$(voce 77.78 3))*min(t/0.02\,1)*exp(-t*0.8)"
ffmpeg -v error -y -f lavfi -i "aevalsrc='$BRAAM':s=44100:d=2.5" -f lavfi -i "aevalsrc=0.3*sin(2*PI*(70*t+106*t*t))*min(t*1.5\,1):s=44100:d=2.5" \
	-i "$P3/MAGSpel_Anime Ability Release 13.wav" -i "$P3/MAGSpel_Anime Ability Charge 4.wav" -i "$P3/ELECSprk_Anime Spark 3.wav" \
	-i "$P3/FGHTBf_Anime Land 11.wav" -i "$OUT/_invers.wav" -f lavfi -i "$(sub 90 40 1.2 3 0.9)" -filter_complex \
	"[0]acrusher=bits=9:mix=0.35,lowpass=f=1400,volume=1.1[b];[1]tremolo=f=9:d=0.35,volume='0.5+0.5*t/2.4':eval=frame[s];[2]$(b 0 1 0.9),volume=1.0[r];[3]$(b 0 3.15 1.05),atrim=end=2.5,volume='0.2+0.8*pow(t/2.4\,2)':eval=frame,volume=0.6[c];[4]$(b 0 3.4 1),highpass=f=1500,atrim=end=2.5,volume='pow(t/2.4\,1.5)':eval=frame,volume=0.55[k];[5]$(b 0 0.7 0.55),lowpass=f=800,volume=0.9[l];[6]atrim=start=$TAIERE,asetpts=PTS-STARTPTS,adelay=$INTARZIERE,volume=1.3[w];[b][s][r][c][k][l][w][7]$MIX=8,$DENS,atrim=end=2.5,afade=t=out:st=$FINAL_UNDA:d=0.02,$STEREO,atrim=end=2.5" \
	-ac 2 "$OUT/_unda.wav"
g=$(castig_final "$OUT/_unda.wav" "anull")
ffmpeg -v error -y -i "$OUT/_unda.wav" -af "volume=${g}dB,$LIMITATOR,afade=t=out:st=$FINAL_UNDA:d=0.012" -ac 2 -c:a libvorbis -q:a 5 "$OUT/vraja_unda.ogg"
echo "vraja_unda.ogg  (2,5 s, liniște de la $FINAL_UNDA)"
# 4. bubuitura (~7 s): explozia lungă Shonen coborâtă + cea scurtă pentru pocnet, basul 75 -> 25 Hz, stab-ul de cor, tunetul
# ADEVĂRAT din bucla de furtună care se rostogolește prin pădure, răgetul grav al unui monstru (ceva s-a trezit), clopotul
# grav care bate o dată, stinger-ul de pian disonant; apoi inima ta, de două ori, rar.
STAB="0.15*($(voce 55 0.3)+$(voce 73.42 0)+$(voce 110 1.1)+$(voce 146.83 2.3)+$(voce 207.65 1.7)+$(voce 293.66 0.9))*min(t/0.012\,1)*exp(-t*1.4)"
INIMA_DUPA="0$(inima 3.6 0.6)$(inima 4.8 0.45)"
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 6.wav" -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -f lavfi -i "$(sub 75 25 7 0.7 1.2)" \
	-f lavfi -i "aevalsrc='$STAB':s=44100:d=7" -i "$FURTUNA" -i "$P2/Monsters & Ghosts/Monster_Roar_4.wav" -i "$P2/Ambient/Bell_low.wav" \
	-i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent.wav" -f lavfi -i "aevalsrc='$INIMA_DUPA':s=44100:d=7" -i "$P3/FGHTBf_Anime Land 11.wav" -filter_complex \
	"[0]$(b 0 3.4 0.7),lowpass=f=2200,volume=1.3[e];[1]$(b 0 1.4 0.95),volume=1.6[p];[3]equalizer=f=700:t=q:w=1.2:g=8,lowpass=f=3500,chorus=0.6:0.9:40|55|70:0.4|0.35|0.3:0.3|0.4|0.5:2|2.5|1.7,volume=0.8[c];[4]$(b 17.4 24 1),lowpass=f=900,equalizer=f=70:t=q:w=1:g=5,adelay=300,volume=2.2[t];[5]$(b 0 4.2 0.55),lowpass=f=1300,adelay=700,afade=t=out:st=3.5:d=2,volume=0.5[m];[6]$(b 0 6 0.85),adelay=1200,volume=0.7[g];[7]$(b 0 3 0.8),adelay=200,volume=0.5[s];[8]lowpass=f=300,volume=1.5[i];[9]$(b 0 0.7 0.6),lowpass=f=1200,volume=1.3[l];[e][p][2][c][t][m][g][s][i][l]$MIX=10,$DENS,$ECOU_MARE,atrim=end=7,afade=t=out:st=5.4:d=1.6,$STEREO" \
	-ac 2 "$OUT/_bum.wav"
unic vraja_bum "$OUT/_bum.wav" stereo
rm -f "$OUT"/_plescait.wav "$OUT"/_cor.wav "$OUT"/_unda.wav "$OUT"/_bum.wav "$OUT"/_invers.wav
TINTA_LUFS=$TINTA_NORMALA_SACRIFICIU

# --- televizorul lui Lexy spart cu un glonț (televizor.gd, 11.10): tv_spart (~1,5 s, 3D) = ecranul care se face țăndări
# (zgomot alb tăiat sus + trei clinchete de sticlă), pocnetul (explozia Shonen scurtă, subțiată), descărcarea electrică
# (scânteia Shonen) și o bufnitură joasă; tv_scantei (~0,5 s) = pârâitul de după, de câteva ori, tot mai încet.
TINTA_NORMALA_TV=$TINTA_LUFS
TINTA_LUFS=-16
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -i "$PACHET/Materials/glass_ping_big.wav" -i "$PACHET/Materials/glass_ping_small.wav" \
	-f lavfi -i "anoisesrc=c=white:a=0.6:d=0.6:r=44100:s=31" -i "$P3/ELECSprk_Anime Spark 1.wav" -f lavfi -i "$(sub 90 40 0.4 9 0.8)" -filter_complex \
	"[0]$(b 0 0.6 1.25),highpass=f=400,afade=t=out:st=0.2:d=0.4,volume=0.6[e];[1]$(b 0 1.5 1),volume=0.5[g1];[2]$(b 0 1 1.35),asplit=2[x][y];[x]adelay=30,volume=0.5[g2];[y]asetrate=44100*0.6,aresample=44100,adelay=80,volume=0.45[g3];[3]highpass=f=2500,afade=t=out:st=0.02:d=0.5:curve=exp,volume=0.9[n];[4]$(b 0 0.8 1),adelay=20,volume=0.7[z];[e][g1][g2][g3][n][z][5]$MIX=7,$ECOU_MIC,atrim=end=1.5,afade=t=out:st=1.1:d=0.4" \
	-ac 1 "$OUT/_tv.wav"
unic tv_spart "$OUT/_tv.wav"
TINTA_LUFS=-20
unic tv_scantei "$P3/ELECSprk_Anime Spark 2.wav" mono "$(b 0 0.5 1.2),highpass=f=1500,afade=t=out:st=0.25:d=0.25"
rm -f "$OUT"/_tv.wav
TINTA_LUFS=$TINTA_NORMALA_TV
# --- atacul conacului, a treia oară (owner: „fulgerele nu sună a fulgere, să tune rău de tot; vrăjile par super weak;
# exploziile nu se aud deloc, mai ales la vraja mare”). Tunetul adevărat de APROAPE are trei bucăți, pe care pachetele
# nu le au separat (tunetele din buclele de furtună sunt departe, sub ploaie), deci le facem:
#   1. pocnetul (primele 5-30 ms): zgomot alb care „rupe” aerul, cu bas, ca o lovitură de tun;
#   2. sfâșierea (~0,6 s): zgomot tăiat în rafale de câteva ms (trei sinusuri care trec de un prag = pârâit neregulat)
#      plus scânteia Shonen încetinită;
#   3. bubuitura și rostogolirea: zgomot maro (doar bas) care se stinge în 3-4 s, tunetul adevărat din bucla de furtună
#      (cea din casă are cea mai puțină ploaie: 16,3-23,5 s), comprimat tare ca să i se audă coada, și ecouri lungi.
# Toate ies mai tare decât prima dată (-10/-11 LUFS, comprimate), iar codul le pornește și el mai tare (fulger.gd,
# vraja_atac.gd, atac_conac.gd). Folosește funcțiile din „luptele cu vrăjitorii” și de la sacrificiu ($DENS, $STEREO, b, sub).
TUNET_CASA="Sound/Soundpack 4/WAV Files/BGS Loops/Interior Night/Inside Night Storm.wav"
# pocnet DURATA -> pocnetul + sfâșierea (zgomot în rafale), mono
pocnet() { echo "aevalsrc='(random(0)*2-1)*(1.6*exp(-t*35)+0.9*gt(sin(2*PI*41*t)+sin(2*PI*67*t+1.3)+sin(2*PI*113*t+2.1)\,1.15+0.9*t)*exp(-t*3.5))':s=44100:d=$1"; }
# bubuitura DURATA DESCRESTERE -> zgomot maro, doar bas, care pornește brusc și se stinge
bubuitura() { echo "anoisesrc=c=brown:a=0.9:d=$1:r=44100,lowpass=f=140,lowpass=f=140,volume='min(t/0.02\,1)*exp(-t*$2)':eval=frame,volume=6"; }
COMPRIMAT="acompressor=threshold=-30dB:ratio=6:attack=5:release=400:makeup=4"
# lovitura CAT_RAMANE VITEZA -> după compresor: lovitura de la început rămâne întreagă, coada cade spre CAT_RAMANE (altfel
# compresorul și tăria medie le fac la fel de tari de la cap la coadă și bubuitura nu mai iese în față)
lovitura() { echo "volume='$1+(1-$1)*exp(-t*$2)':eval=frame"; }
ROSTOGOLIRE="aecho=0.8:0.75:380|820|1500|2300:0.45|0.35|0.25|0.15"

# 1. fulgerul care lovește aproape (~4 s, 3D): pocnetul care sfâșie aerul, scânteia electrică, explozia Shonen
# coborâtă (corpul), bubuitura de bas și tunetul adevărat care se rostogolește după
ffmpeg -v error -y -f lavfi -i "$(pocnet 1)" -i "$P3/ELECSprk_Anime Spark 3.wav" -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -f lavfi -i "$(bubuitura 4 1.1)" \
	-i "$TUNET_CASA" -f lavfi -i "$(sub 65 28 4 1.3 1.2)" -filter_complex \
	"[0]highpass=f=180,lowpass=f=9000,volume=1.3[p];[1]$(b 0 0.6 0.7),highpass=f=600,volume=0.8[c];[2]$(b 0 1.4 0.7),lowpass=f=2500[e];[4]$(b 16.3 20.3 1),lowpass=f=1100,$COMPRIMAT,volume=3,adelay=120[r];[p][c][e][3][r][5]$MIX=6,$DENS,$(lovitura 0.12 2.2),$ECOU_MIC,atrim=end=4,afade=t=out:st=3:d=1" \
	-ac 1 "$OUT/_fulger.wav"
TINTA_LUFS=-10
unic atac_fulger "$OUT/_fulger.wav"
# 2. tunetul (~7 s, stereo): același tunet, dar pocnetul vine întâi (mai înfundat, e mai departe) și apoi
# rostogolirea lungă care trece de la un deal la altul
ffmpeg -v error -y -f lavfi -i "$(pocnet 1.2)" -f lavfi -i "$(bubuitura 7 0.55)" -i "$TUNET_CASA" -i "$P3/EXPLDsgn_Anime Explosion 6.wav" -f lavfi -i "$(sub 50 25 7 0.45 0.9)" -filter_complex \
	"[0]highpass=f=120,lowpass=f=4500,volume=1.2[p];[2]$(b 16.3 23.5 1),lowpass=f=1000,$COMPRIMAT,volume=3.5,adelay=80[r];[3]$(b 0 3.4 0.6),lowpass=f=1500,volume=0.8[e];[p][1][r][e][4]$MIX=5,$DENS,$(lovitura 0.25 1.4),$ROSTOGOLIRE,atrim=end=7,afade=t=out:st=5.5:d=1.5,$STEREO" \
	-ac 2 "$OUT/_tunet.wav"
TINTA_LUFS=-11
unic atac_tunet "$OUT/_tunet.wav" stereo
# 3. o vrajă aruncată (~1,2 s, 3D): „trântitura” de la plecare (eliberarea de energie Shonen + un pocnet scurt de
# bas), mingea de foc care urlă (Fireball + Firebuff coborât) și vâjâitul aruncării. Era la -15; acum -12.
ffmpeg -v error -y -i "$P4/Spells/Fireball 1.wav" -i "$P4/Spells/Firebuff 1.wav" -i "$P3/MAGSpel_Anime Ability Release 13.wav" -i "$P3/FGHTMisc_Anime Throw 4.wav" -f lavfi -i "$(sub 110 45 1.2 7 1.1)" -filter_complex \
	"[0]$(b 0 1.2 0.9),volume=1.2[f];[1]$(b 0 1.4 0.75),lowpass=f=4000,volume=0.8[u];[2]$(b 0 0.8 1.1),volume=0.9[r];[3]$(b 0.1 0.6 0.9),volume=0.7[w];[f][u][r][w][4]$MIX=5,$DENS,$(lovitura 0.5 5),atrim=end=1.2,afade=t=out:st=0.85:d=0.35" \
	-ac 1 "$OUT/_vraja.wav"
TINTA_LUFS=-12
unic atac_vraja "$OUT/_vraja.wav"
# 4. vraja lovește piatra (~2,6 s, 3D): o explozie adevărată, nu un pocnet: explozia Shonen și cea retro (corpul),
# pocnetul de aer, impactul vrăjii, piatra care se rupe și pietrele care cad (Rock Wall, Meteor), basul care lovește
# în piept. Era la -14; acum -11.
ffmpeg -v error -y -i "$P3/EXPLDsgn_Anime Explosion 4.wav" -i "$PACHET/Retro/explosion_large.wav" -f lavfi -i "$(pocnet 0.4)" -i "$P4/Spells/Spell Impact 1.wav" -i "$P4/Spells/Rock Wall 1.wav" \
	-i "$P4/Spells/Rock Meteor Swarm 1.wav" -f lavfi -i "$(sub 80 30 2.6 3.2 1.4)" -f lavfi -i "$(bubuitura 2.6 2.2)" -filter_complex \
	"[0]$(b 0 1.4 0.8),lowpass=f=6000[e];[1]aformat=channel_layouts=mono,aresample=44100,asetrate=44100*0.7,aresample=44100,lowpass=f=2500,volume=0.6[x];[2]highpass=f=200,volume=0.7[p];[3]$(b 0 0.35 0.85),volume=0.6[i];[4]$(b 0 2 0.8),adelay=60,volume=0.7[r];[5]$(b 0 1.97 0.9),adelay=350,volume=0.4[m];[e][x][p][i][r][m][6][7]$MIX=8,$DENS,$(lovitura 0.15 3.5),$ECOU_MIC,atrim=end=2.6,afade=t=out:st=1.9:d=0.7" \
	-ac 1 "$OUT/_impact.wav"
TINTA_LUFS=-11
unic atac_impact "$OUT/_impact.wav"
# 5. vraja mare lovește conacul (~8,5 s, stereo). Totul e în FAȚĂ: în joc, la 0,55 s după, te asurzește (atac_conac.gd
# o pornește pe busul Interfata, ca s-o lase întreagă). La t = 0: pocnetul de tunet, cele două explozii Shonen (lungă,
# coborâtă + seacă), cea retro foarte coborâtă, bubuitura de bas și basul 55 -> 16 Hz; apoi zidurile care se prăbușesc,
# pietrele care plouă, tunetul adevărat care se rostogolește și stingerul de pian. Era la -12; acum -10.
ffmpeg -v error -y -f lavfi -i "$(pocnet 1.2)" -i "$P3/EXPLDsgn_Anime Explosion 6.wav" -i "$P3/EXPLDsgn_Anime Explosion 11.wav" -i "$PACHET/Retro/explosion_large.wav" \
	-f lavfi -i "$(bubuitura 8.5 0.5)" -f lavfi -i "$(sub 55 16 8.5 0.55 1.6)" -i "$P4/Spells/Rock Wall 1.wav" -i "$P4/Spells/Rock Wall 2.wav" -i "$P4/Spells/Rock Meteor Swarm 2.wav" \
	-i "$TUNET_CASA" -i "$P2/Stingers and Spooky Triggers/Piano_stinger_dissonent.wav" -filter_complex \
	"[0]highpass=f=150,volume=1.5[p];[1]$(b 0 3.4 0.65),lowpass=f=3000,volume=1.3[e];[2]$(b 0 3.15 0.9),volume=0.9[s];[3]aformat=channel_layouts=mono,aresample=44100,asetrate=44100*0.5,aresample=44100,lowpass=f=1500,volume=0.8[x];[6]$(b 0 2 0.7),adelay=250,volume=0.8[r1];[7]$(b 0 2 0.6),adelay=800,volume=0.7[r2];[8]$(b 0 1.97 0.8),adelay=1300,volume=0.5[m];[9]$(b 16.3 23.5 1),lowpass=f=900,$COMPRIMAT,volume=3,adelay=1000[t];[10]$(b 0 2.9 0.8),adelay=100,volume=0.5[pi];[p][e][s][x][4][5][r1][r2][m][t][pi]$MIX=11,$DENS,$(lovitura 0.18 1.1),$ROSTOGOLIRE,atrim=end=8.5,afade=t=out:st=6.5:d=2,$STEREO" \
	-ac 2 "$OUT/_orb_bum.wav"
TINTA_LUFS=-10
unic orb_explozie "$OUT/_orb_bum.wav" stereo
TINTA_LUFS=$TINTA_NORMALA_LUPTE
