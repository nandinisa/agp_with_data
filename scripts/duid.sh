#!/bin/bash

# get unique DUIDs present in the dispatch data file
# run in folder (formatted) or where PUBLIC_DVD_DISPATCH_UNIT_SCADA_*.csv files are located
for fname in PUBLIC_DVD_DISPATCH_UNIT_SCADA_* ;do
    echo "Processing " $fname
    awk -F ',' 'NR > 1 { print $3 }' < $fname >> duids
done

cat duids | sort | uniq > temp
mv temp duids #391 DUID







