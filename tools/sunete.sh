#!/usr/bin/env bash
# Pregătește sunetele jocului din pachetul brut (Sound/Soundpack, ignorat de Godot și de git)
# în sunete/*.ogg: taie liniștea de la început, aduce vârful la -1 dB, mono pentru sunetele
# care vin dintr-un loc anume (3D) și face buclele să se lege fără cusătură.
# Rulare din folderul proiectului:   bash tools/sunete.sh
set -e
cd "$(dirname "$0")/.."
PACHET="Sound/Soundpack"
OUT="sunete"
mkdir -p "$OUT"

# varf_la FISIER_INTRARE FILTRU -> câștigul (dB) care aduce vârful la -1 dB după FILTRU
castig() {
	local max
	max=$(ffmpeg -hide_banner -i "$1" -af "$2,volumedetect" -f null - 2>&1 | grep -o "max_volume: [-0-9.]*" | grep -o "[-0-9.]*$")
	awk -v m="$max" 'BEGIN { printf "%.2f", -1 - m }'
}

# unic NUME SURSA [mono|stereo] [FILTRU_EXTRA] -> sunet scurt (pas, ușă, clic)
unic() {
	local nume="$1" sursa="$PACHET/$2" canale="${3:-mono}" extra="${4:-anull}"
	[ -f "$sursa" ] || sursa="$2"  # merge și cu un fișier din afara pachetului
	local ac=1; [ "$canale" = stereo ] && ac=2
	local f="silenceremove=start_periods=1:start_threshold=-50dB,$extra"
	local g; g=$(castig "$sursa" "$f")
	ffmpeg -v error -y -i "$sursa" -af "$f,volume=${g}dB" -ac $ac -c:a libvorbis -q:a 5 "$OUT/$nume.ogg"
	echo "$nume.ogg  <- $2"
}

# bucla NUME SURSA SUPRAPUNERE [mono|stereo] [FILTRU_EXTRA] -> buclă fără cusătură:
# coada sunetului se topește în începutul lui, deci sfârșitul se leagă perfect de început.
bucla() {
	local nume="$1" sursa="$2" d="$3" canale="${4:-mono}" extra="${5:-anull}"
	local ac=1; [ "$canale" = stereo ] && ac=2
	local tmp="$OUT/_tmp.wav"
	ffmpeg -v error -y -i "$sursa" -af "$extra" -ac $ac "$tmp"
	local g; g=$(castig "$tmp" "anull")
	ffmpeg -v error -y -i "$tmp" -filter_complex \
		"[0]atrim=start=$d,asetpts=PTS-STARTPTS[a];[0]atrim=end=$d,asetpts=PTS-STARTPTS[b];[a][b]acrossfade=d=$d:c1=qsin:c2=qsin,volume=${g}dB" \
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
ffmpeg -v error -y -i "$PACHET/Environment/clock_ticking.wav" -ac 1 -af "volume=-1dB" -c:a libvorbis -q:a 5 "$OUT/ceas.ogg"
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
echo "Gata."
