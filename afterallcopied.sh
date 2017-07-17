#!/usr/bin/bash
# script passed argument of the root directory for currently copied files
# eg. 'sync/20170712_160423'


# TRANSCODE
command -v avconv && CMD=avconv
command -v ffmpeg && CMD=ffmpeg
if [ "$CMD" == "" ]; then
    echo "cannot transcode, no ffmpeg or avconv found.";
else
    for file in `ls $1/album/*.aif`; do
        echo "convert $file to mp3"
        $CMD -loglevel panic -i $file -b:a 320k ${file%.*}.mp3
    done
fi
