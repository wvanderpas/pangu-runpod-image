#!/bin/bash

set -uo pipefail

# Configuration
dissemination_delay=3
MAP_DIR="/workspace/Maps"
GRIB_DIR="/workspace/grib"

mkdir -p "$MAP_DIR" "$GRIB_DIR"

# Date and run setup
DATE=$(date -u +%Y%m%d)
H=$(date -u +%H)
H=$((10#$H))

RUN=$(( ((($H + 24 - $dissemination_delay)/6)%4)*6 ))
if [ $RUN -le 10 ]; then RUN="0$RUN"; fi

RUNtime="${RUN}00"
nonzerorun=$((10#$RUNtime))

# Hours sequence
HoursToProcess=($(seq -w 0 6 360))
endTimePP=$(date -d "+1 hours" +%s)

# Post-processing and plotting loop
post_processing() {
    while (( $(date +%s) < $endTimePP )); do
        for MapHour in "${HoursToProcess[@]}"; do
            nonzeroHour=$((10#$MapHour))
            LOCAL_FILE="pangugfs-${DATE}-${nonzeroHour}-${nonzerorun}.grib"

            if [[ -f $LOCAL_FILE ]]; then
                echo "[INFO] Found $LOCAL_FILE, processing..."
                HOURstr=$MapHour

                # Extract fields into separate grib files
                grib_copy "$LOCAL_FILE" -w typeOfLevel=meanSea   "${GRIB_DIR}/PANGUGFS_${DATE}${RUN}_${HOURstr}_mslp.grib"
                grib_copy "$LOCAL_FILE" -w shortName=z,level=500 "${GRIB_DIR}/PANGUGFS_${DATE}${RUN}_${HOURstr}_z500.grib"
                grib_copy "$LOCAL_FILE" -w shortName=10u         "${GRIB_DIR}/PANGUGFS_${DATE}${RUN}_${HOURstr}_10u.grib"
                grib_copy "$LOCAL_FILE" -w shortName=10v         "${GRIB_DIR}/PANGUGFS_${DATE}${RUN}_${HOURstr}_10v.grib"
                grib_copy "$LOCAL_FILE" -w shortName=2t          "${GRIB_DIR}/PANGUGFS_${DATE}${RUN}_${HOURstr}_t2m.grib"

                # Map plotting (run in background for speed)
                python plotmap.py -date=$DATE -hour=$HOURstr -run=$RUN -model=PANGUGFS -maptype=gph_6h_diff   &
                python plotmap.py -date=$DATE -hour=$HOURstr -run=$RUN -model=PANGUGFS                        &
                python plotmap.py -date=$DATE -hour=$HOURstr -run=$RUN -model=PANGUGFS -maptype=wind10m       &
                python plotmap.py -date=$DATE -hour=$HOURstr -run=$RUN -model=PANGUGFS -maptype=t2m           

                # # Special case: daily plot every 24h
                # if (( $nonzeroHour % 24 == 0 )); then
                #     echo "[INFO] Generating daily plots for DE..."
                #     python plotMW.py -date=$DATE -run=$RUN -method=Rafa -country=DE &
                # fi

                rm "$LOCAL_FILE"

                # Remove processed hour from list
                for i in "${!HoursToProcess[@]}"; do
                    if [[ "${HoursToProcess[i]}" = "$MapHour" ]]; then
                        unset 'HoursToProcess[i]'
                        break
                    fi
                done

                echo "[INFO] Processing completed for $DATE $nonzeroHour"

                # If no hours remain, stop early
                if [[ "${#HoursToProcess[@]}" -eq 0 ]]; then
                    endTimePP=$(date -d "-2 hours" +%s)
                fi
            else
                echo "[WAIT] $LOCAL_FILE not yet available"
                sleep 1
            fi
        done
    done
}

# Run post-processing in background
post_processing &

# Launch AI model run
ai-models-gfs panguweather \
    --input gfs \
    --date $DATE \
    --time $RUN \
    --path 'pangugfs-{date}-{step}-{time}.grib' \
    --only-gpu \
    --lead-time 360 \
    --download-assets

# Wait for everything to finish
wait

# # Final plotting for multiple countries
# for C in FR DE NL UK SP; do
#     python ~/repos/AIFS_downloader/plotMW.py -date=$DATE -run=$RUN -method=Rafa -country=$C &
# done
# wait

# Move outputs
mv PANGUGFS_${DATE}${RUN}* "$GRIB_DIR/"

echo "[DONE] Workflow completed for $DATE $RUN"
