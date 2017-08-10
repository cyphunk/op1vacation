#!/usr/bin/bash
# script passed argument of the root directory for currently copied files
# eg. 'sync/20170712_160423'


# current version requires ffmpeg or on raspberry pi avconv 
command -v avconv && CMD=avconv
command -v ffmpeg && CMD=ffmpeg
if [ "$CMD" == "" ]; then
    echo "cannot transcode, no ffmpeg or avconv found.";
    exit
fi

# CUT SILENCE from end of album's and tape's
# reduces size
for file in `ls $1/album/*.aif $1/tape/*.aif`; do
    echo "cut $file silence at end of"
    $CMD -y -i $file -af areverse /tmp/temp1.aif
    $CMD -y -i /tmp/temp1.aif -af silenceremove=1:0:-96dB /tmp/temp2.aif
    $CMD -y -i /tmp/temp2.aif -af areverse $file
    rm /tmp/temp1.aif /tmp/temp2.aif
done

# TRANSCODE album's to mp3
for file in `ls $1/album/*.aif`; do
    echo "convert $file to mp3"
    $CMD -loglevel panic -i $file -b:a 320k ${file%.*}.mp3
done
