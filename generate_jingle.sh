#!/bin/bash -ae
EFFECTS_DIR="effects"
VOICES_DIR="voices"
MODIFIERS_DIR="modifiers"
WORK_DIR="workdir"
INPUT="in.wav"
OUTPUT="out.wav"

# clean work directory
rm -rf ${WORK_DIR}/*

# take care of sample rate conversion for input file
sox "$INPUT" -r 44100 -c 2 -b 16 "${WORK_DIR}/${INPUT}"

# clean up audio a bt
sox "${WORK_DIR}/${INPUT}" "${WORK_DIR}/1.wav" \
remix - \
highpass 100 \
norm \
compand 0.05,0.2 6:-54,-90,-36,-36,-24,-24,0,-12 0 -90 0.1 \
vad -T 0.6 -p 0.2 -t 5 \
fade 0.1 \
reverse \
vad -T 0.6 -p 0.2 -t 5 \
fade 0.1 \
reverse \
norm -0.5

rm "${WORK_DIR}/${INPUT}"

# separate into chunks
sox "${WORK_DIR}/1.wav" "${WORK_DIR}/chunk.wav" channels 2 silence 1 0.1t 1% 1 0.1t 1% : newfile : restart
rm "${WORK_DIR}/1.wav"
test "$(ls -1 "$WORK_DIR" | grep -E '^chunk.*' | wc -l)" -gt "1" && \
rm "${WORK_DIR}/$(ls -1 "$WORK_DIR" | grep -E '^chunk.*' | tail -n 1)"

## do or do not choose additional voice depending on luck and plug as another voice
##if [ "$(echo "${RANDOM} % 100 + 1" | bc)" -lt 30 ]
##then
##    random_voice=$(ls -1 "$VOICES_DIR" | sed -n "$(echo "${RANDOM} % $(ls -1 "$VOICES_DIR" | wc -l) + 1" | bc)p")
##    cp "${VOICES_DIR}/${random_voice}" "$WORK_DIR"
#fi

# pick 1 to 4 random effects
mkdir -p "${WORK_DIR}/effects"

for i in $(seq $(echo "$RANDOM % 4 + 1" | bc))
do
    cp "${EFFECTS_DIR}/$(ls -1 "$EFFECTS_DIR" | sed -n "$(echo "${RANDOM} % $(ls -1 "$EFFECTS_DIR" | wc -l) + 1" | bc)p")" "${WORK_DIR}/effects"
done

#5 use random modifiers on voice and effects
for infile in $(find "$WORK_DIR" -maxdepth 1 -type f)
do
    infile=$(basename "$infile")
    modifier="$(ls -1 "$MODIFIERS_DIR" | sed -n "$(echo "${RANDOM} % $(ls -1 "$MODIFIERS_DIR" | wc -l) + 1" | bc)p")"
    ./$MODIFIERS_DIR/$modifier "${WORK_DIR}/$infile" "${WORK_DIR}/mod-${infile}"
    echo "voice $infile mod: $modifier"
done

for infile in $(find "${WORK_DIR}/effects" -maxdepth 1 -type f)
do
    infile=$(basename "$infile")
    rndval="$(echo "$RANDOM % 100 + 1" | bc)"
    if test "$rndval"  -lt "40"
    then
        modifier="$(ls -1 "$MODIFIERS_DIR" | sed -n "$(echo "${RANDOM} % $(ls -1 "$MODIFIERS_DIR" | wc -l) + 1" | bc)p")"
        ./$MODIFIERS_DIR/$modifier "${WORK_DIR}/effects/$infile" "${WORK_DIR}/effects/mod-${infile}"
        echo "effect $infile mod: $modifier"
    else
        cp "${WORK_DIR}/effects/$infile" "${WORK_DIR}/effects/mod-${infile}"
        echo "effect $infile clean"

    fi
done

find  "${WORK_DIR}" -maxdepth 1 -type f ! -name 'mod-*' -printf '%f\n' | xargs -n 1 -I '%' rm "${WORK_DIR}/%"
find  "${WORK_DIR}/effects" -maxdepth 1 -type f ! -name 'mod-*' -printf '%f\n' | xargs -n 1 -I '%' rm "${WORK_DIR}/effects/%"

#6 mix
mix_list=""
for i in $(find "${WORK_DIR}" -maxdepth 1 -type f | sort)
do
    test -n "$mix_list" && \
    mix_list="${mix_list}
${i}" || \
    mix_list="${i}"
done

chunk_count="$(find "${WORK_DIR}" -maxdepth 1 -type f | wc -l)"
for effect in $(find "${WORK_DIR}/effects" -maxdepth 1 -type f)
do
    position="$(echo "$RANDOM % ( 1 + $chunk_count )" | bc)"
    test "$position" == "0" && \
    mix_list="${effect}
${mix_list}" || \
    mix_list="$(echo "$mix_list" | sed -n "p;${position}a ${effect}" )"
done

echo -e '##########\nmixing order:'
echo "$mix_list"

echo -e '##########\nmixing...'
prev_file="$(head -n 1 <(echo "$mix_list"))"
mix_list="$(tail -n +2 <(echo "$mix_list"))"
while true
do
    curr_file="$(head -n 1 <(echo "$mix_list"))"
    test -n "$curr_file" ||  break
    mix_list="$(tail -n +2 <(echo "$mix_list"))"
    (( $(echo "$(soxi -D $prev_file) > 3" |bc -l) )) && \
    (( $(echo "$(soxi -D $curr_file) > 3" |bc -l) )) && \
    ./crossfade_cat.sh 0.25 "$prev_file" "$curr_file"
    mv "mix.wav" "$curr_file"
    prev_file="$curr_file"
done

mv "$prev_file" "$OUTPUT"
