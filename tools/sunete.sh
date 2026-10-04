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
for i in 1 2 3 4; do
	unic "pas_lemn_$i" "Footsteps/foley_footstep_vinyl_$i.wav"
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
unic cazan_plescait "Environment/water_splashing.wav" mono "asetrate=44100*0.7,aresample=44100,lowpass=f=3000"
# unda de lumină: un sinus care urcă (70 -> 540 Hz) peste un șuierat care crește, cu tremolo și ecou
ffmpeg -v error -y -f lavfi -i "aevalsrc=0.45*sin(2*PI*(70*t+90*t*t))*min(t*1.5\,1):s=44100:d=2.8" \
	-f lavfi -i "anoisesrc=c=pink:a=0.35:d=2.8:r=44100" \
	-filter_complex "[1]lowpass=f=2500,volume='min(t/2.2\,1)':eval=frame[z];[0][z]amix=inputs=2:normalize=0,tremolo=f=9:d=0.35,afade=t=out:st=2.4:d=0.4,aecho=0.8:0.7:90|230:0.3|0.2" \
	-ac 1 "$OUT/_unda.wav"
unic vraja_unda "$OUT/_unda.wav"
unic vraja_bum "Retro/explosion_large.wav" mono "asetrate=44100*0.65,aresample=44100,lowpass=f=900,aecho=0.8:0.7:200|500:0.4|0.25"
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
rm -f "$OUT"/_impuscatura.wav "$OUT"/_unda.wav "$OUT"/_cant.wav "$OUT"/_foc.wav
