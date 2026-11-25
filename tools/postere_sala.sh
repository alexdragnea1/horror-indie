#!/usr/bin/env bash
# Posterele din sală: fețele acoperite cu un dreptunghi negru, apoi micșorate și lipite de paleta jocului.
set -e
# Rulare: pune pozele owner-ului (convertite în PNG) ca orig_1..5.png într-un folder și dă-l ca argument.
S="${1:?folderul cu orig_1..5.png}"
P="/c/Users/gheorghe dracu/Desktop/horror-indie"
cols=$(tr -d '\r' < "$P/textures/paleta culori.hex")
lista=($cols)
ff=""
for k in $(seq 0 255); do
	c=${lista[$((k % ${#lista[@]}))]}
	ff="$ff,drawbox=x=$((k % 16)):y=$((k / 16)):w=1:h=1:color=0x$c:t=fill"
done
ffmpeg -v error -y -f lavfi -i color=c=black:s=16x16 -vf "${ff:1}" -frames:v 1 "$S/paleta.png"
B="color=0x262d2f:t=fill"
cenz() { ffmpeg -v error -y -i "$S/orig_$1.png" -vf "$2" "$S/cenz_$1.png"; }
cenz 1 "drawbox=x=360:y=400:w=240:h=280:$B"
cenz 2 "drawbox=x=480:y=460:w=290:h=370:$B"
cenz 3 "drawbox=x=570:y=580:w=170:h=190:$B,drawbox=x=1030:y=0:w=170:h=760:$B"
cenz 4 "drawbox=x=590:y=290:w=180:h=190:$B,drawbox=x=30:y=230:w=200:h=220:$B"
cenz 5 "drawbox=x=620:y=615:w=140:h=165:$B,drawbox=x=955:y=640:w=170:h=170:$B"
for i in 1 2 3 4 5; do
	ffmpeg -v error -y -i "$S/cenz_$i.png" -i "$S/paleta.png" -filter_complex \
		"[0]scale=-2:128:flags=area[a];[a][1]paletteuse=dither=bayer:bayer_scale=4" "$P/textures/poster_sala_$i.png"
done
echo gata
