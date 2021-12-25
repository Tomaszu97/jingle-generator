#!/bin/bash -axe
# Converts all wav files in a directory to 2ch 44.1ksamples/s 16bit wav
# Usage:
#     ./convert <directory>
for f in $(find $1 -maxdepth 1 -type f)
do
    tempfile="$(mktemp --suffix=.wav)"
    sox "$f" -r 44100 -c 2 -b 16 "$tempfile"
    mv "$tempfile" "$f"
done
