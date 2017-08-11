#!/usr/bin/env bash
# script will wait for OP-1 to be connected in disk mode and copy files
# that have changed into the sync directory next to this script

# cd to directory of this script
cd $(dirname $BASH_SOURCE)

test -e sync || mkdir sync

# If available run following script after all files copied and op1 unmounted
AFTERALLCOPIED=afterallcopied.sh

# if sd cart contains 3rd partition, mount it to the ./sync, which is where all
# files from op1 are copied to. useful if you want to make 3rd partition vfat
# but not required.
test -e /dev/mmcblk0p3 && sudo mount /dev/mmcblk0p3 sync
# upgrade afterallcopied script if it exists in that directory
test -e sync/$AFTERALLCOPIED && mv sync/$AFTERALLCOPIED $AFTERALLCOPIED
# upgrade this script if it exists in that directory. restart script
if [ -e sync/sync.sh ]; then
    mv sync/sync.sh sync.sh && sleep 1
    ./sync.sh &
    sleep 1
    exit
fi







#
# LED FUNCTIONS FOR STATUS INDICATIONS AFTER SYNC
#

# RPI Zero ACT LED - Take control
if test -e /sys/class/leds/led0/trigger ; then
    echo none > /sys/class/leds/led0/trigger
    function ledoff () { echo 1 > /sys/class/leds/led0/brightness; }
    function ledon () { echo 0 > /sys/class/leds/led0/brightness; }
else
    # debug - run locally:
    function ledoff () { true; } # echo -n " _ "; }
    function ledon () { true; }  # echo -n " X "; }
fi
ledoff


function indicate_start () {
    echo indicate_start
    i=10; while [ $i -gt 0 ]; do
        ledon; sleep 0.05
        ledoff; sleep 0.05
        i=$(($i-1))
    done
}
function indicate_done () {
    echo indicate_done
    i=5; while [ $i -gt 0 ]; do
        ledoff; sleep 0.1
        ledon; sleep 0.1
        i=$(($i-1))
    done
    sleep 1
    # At end just loop over how many files were copied.
    while [ 1 ]; do
        echo begin check sequence
        # Show some sequince so we understand the check loop has begun
        ledoff; sleep 0.1
        ledon; sleep 0.1
        ledoff; sleep 0.1
        sleep 2
        # inidicate number of files we think we copied
        i=$COPIED
        while [ $i -gt 0 ]; do
            ledon; sleep 0.3
            ledoff; sleep 0.5
            i=$(($i-1))
        done
        sleep 2
    done
}
function indicate_error () {
    echo indicate_error
    while [ 1 ]; do
        ledon; sleep 0.5
        ledoff; sleep 0.5
    done
}
function indicate_loop () {
    echo indicate_loop
    ledon; sleep 0.05
    ledoff; sleep 1
}

function indicate_mounted () {
    echo indicate_mounted
    ledon
}
function indicate_copystart () {
    echo indicate_copystart
    ledon
}
function indicate_copyend () {
    echo indicate_copyend
    ledoff; sleep 0.2; ledon; sleep 0.2; ledoff
}



#
# Execute
#


trap ctrl_c INT
function ctrl_c() {
        echo "clean exit"
        sudo umount /tmp/usb
        test -e /dev/mmcblk0p3 && sudo umount sync
        exit 0
}


indicate_start


while [ 1 ]; do
    indicate_loop
    # wait for OP-1 to show up in disk mode
    dev=$(readlink -f /dev/disk/by-id/*Teenage_OP-1*)
    test -e "$dev" || continue

    mkdir -p /tmp/usb 2>/dev/null
    sudo mount $dev /tmp/usb || break
    indicate_mounted

    # Get the $date of the latest file to use as our destination directory
    for file in $(cd /tmp/usb && find . -type f); do
        modifiedtime=$(stat -t /tmp/usb/$file | awk '{print $13}')
        #echo $file $modifiedtime
        #stat --format=%y /tmp/usb/$file
        if [[ "$modifiedtime" -gt "$latest" ]]; then
            latest=$modifiedtime
            date=$(date +%Y%m%d_%H%M%S -r /tmp/usb/$file)
        fi
    done
    # make the destination $date directory
    # handle odd case where files have changed but dates not?
    while [ 1 ]; do
        # if dir doesn't exist, keep this date path and exit loop
        test -e sync/$date || break
        # if dir did exist append a _N to the date path and check again
        i=$(($i+1))
        date="${date}_$i"
    done
    echo desitation date $date

    IFS=$'\n'
    COPIED=0
    for file in $(cd /tmp/usb && find . -type f); do
        echo $file
        if [ ! -e mirror/$file ]; then
            echo mirror/$file doesnt exist
            COPY=1
        #elif [ mirror/$file -ot /tmp/usb/$file ]; then
        #    # echo file is newer
        #    COPY=1
        # OP-1 changes modified time on user synth/drump/tracks even when just
        # recording a new album track. So we can't trust modified time (above)
        # Also size will probably not differ. Time may differ but will differ often
        #elif [ "`stat --format %s mirror/$file`" != "`stat --format %s /tmp/usb/$file`" ] && \
        #     [ "`cd /tmp/usb && md5sum $file`" != "`cd mirror && md5sum $file`" ]; then
        # so, all we can really do is a crc32 and then md5? I found md5sum to work
        # as swifly as cksum, so lets just do that for every file?
        #elif [ "`cd /tmp/usb && cksum $file`" != "`cd mirror && cksum $file`" ]; then
        elif [ "`cd /tmp/usb && md5sum $file`" != "`cd mirror && md5sum $file`" ]; then
            echo "$file hashes differ (will copy file)"
            COPY=1
        else
            COPY=0
        fi

        if [ $COPY -eq 1 ]; then
            indicate_copystart
            echo $file
            mkdir -p mirror/`dirname $file`     2>/dev/null
            mkdir -p sync/$date/`dirname $file` 2>/dev/null

            cp -p /tmp/usb/$file  sync/$date/$file
            # makes duplicate for mirror
            cp -p sync/$date/$file mirror/$file
            # just links for mirror (not using currently because the benifit is really only saving 150mb)
            #ln -sf `readlink -f sync/$date/$file` mirror/$file

            COPIED=$(($COPIED+1))
            indicate_copyend
        fi

    done

    # success
    sudo umount /tmp/usb
    test -e $AFTERALLCOPIED && bash $AFTERALLCOPIED sync/$date
    test -e /dev/mmcblk0p3 && sudo umount sync
    indicate_done
    exit
done

#  ERROR
sudo umount /tmp/usb
test -e /dev/mmcblk0p3 && sudo umount sync
indicate_error
echo "OP1 sync.sh ERROR. end of script."
