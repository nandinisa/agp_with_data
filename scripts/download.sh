#!/bin/bash
# Script file for cerating demand, dispatch price and dispatch data

# AEMO data archivem(#'PUBLIC_DVD_DISPATCHPRICE')
home_url='http://nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM'
dispatch_data='PUBLIC_DVD_DISPATCH_UNIT_SCADA' #5 min interval dispatch data
dispatch_price='PUBLIC_DVD_DISPATCHPRICE' # 5 min interval dispatch price
dispatch_hh_price='PUBLIC_DVD_TRADINGPRICE' # 30 min interval dispatch price
demand='PUBLIC_DVD_TRADINGREGIONSUM' # 30 min interval demand

createDirectory() {
    if [ ! -d $1 ]
        then
            mkdir -p $1
        else
            echo "Directory exists will overwrite contents"
    fi
}

# Download zip files to dump
createDirectory download
cd download

# Time period {*/2010 - */2020}
# Download data from NEM archive
for type in $dispatch_data $dispatch_price $demand $dispatch_hh_price;do
    for year in $(seq 2010 2020); do
        for month in $(seq -f "%02g" 1 12); do
            url="${home_url}/${year}/MMSDM_${year}_${month}/MMSDM_Historical_Data_SQLLoader/DATA/${type}_${year}${month}010000.zip"
            if curl --output /dev/null --silent --head --fail "$url"; then
                echo "URL exists, downloading: $url"
                curl -O $url
            else
                echo "URL does not exist: $url" >> error
            fi
        done
    done
done

# Unzip the files
unzip '*.zip'

# remove files before nov 2010 and after sept 2020 (study period)
# dispatch data available only post nov 2010
# **** change dates according to study period ****
for type in $dispatch_data $dispatch_price $demand $dispatch_hh_price;do
    for year in 2010; do
        for month in $(seq 1 12); do
            if (( year == 2010 & month < 11 )) || (( year == 2020 & month > 9 )); then
                    mf=$(printf %02d $month)
                    fname="${type}_${year}${mf}010000.*"
                    echo "deleting files " $fname
                    rm -f $fname
            fi
        done
    done
done

createDirectory ../formatted
# move unzipped *.csv files to formatted directory
mv *.csv ../formatted

# or
# unzip files to aemo folder 
# for type in $dispatch_data $dispatch_price $demand $dispatch_hh_price;do
#     for year in $(seq 2010 2020); do
#         for month in $(seq 1 12); do
#             if (( year == 2010 & month < 11 )); then
#                 :
#             elif (( year == 2020 & month > 9 )); then
#                 :
#             else
#                 mf=$(printf %02d $month)
#                 fname="${type}_${year}${mf}010000"
#                 unzip "$fname".zip -d ../formatted 2>> error_unzip
#             fi
#         done
#     done
# done

cd ../formatted


# format files - select only relevant columns and remove redundant headers, and 'end of report' last line comment
for fname in *.CSV;do
    tail -n +2 $fname > temp # remove 1st headers from all files, csv has 2 lines of headers
    # filter columns
    if [[ $fname == *"$dispatch_data"* ]]; then
        echo "Processing " $fname " - dispatch"

        # {SETTLEMENTDATE, DUID, SCADAVALUE}
        cut -d , -f 5,6,7 < temp > $fname

    elif [[ $fname == *"$dispatch_price"* ]]; then
        echo "Processing " $fname " - dispatch price"

        # {SETTLEMENTDATE, REGIONID, RRP (10)}
        cut -d , -f 5,7,9< temp > $fname

    elif [[ $fname == *"$demand"* ]]; then
        echo "Processing " $fname " - demand"
        
        # {SETTLEMENTDATE, REGIONID, TOTALDEMAND}
        cut -d , -f 5,7,9 < temp > $fname
    fi

    # split datetime cols to date and time
    awk -f ../../scripts/split_date.awk < $fname > temp
    sed '$ d' temp > $fname # remove last line (end of report)
done


# Merge into single file
dispatch_data='PUBLIC_DVD_DISPATCH_UNIT_SCADA'
dispatch_price='PUBLIC_DVD_DISPATCHPRICE'
dispatch_hh_price='PUBLIC_DVD_TRADINGPRICE'
demand='PUBLIC_DVD_TRADINGREGIONSUM'

# Merge into single file by year
for type in $dispatch_data $dispatch_price $demand $dispatch_hh_price;do
    for year in $(seq 2010 2020); do
        merged_fname="${type}_${year}.csv"
        count=1
        for month in $(seq 1 12); do
            if (( year == 2010 & month < 11 )); then
                    :
                elif (( year == 2020 & month > 9 )); then
                    :
                else
                    mf=$(printf %02d $month)
                    fname="${type}_${year}${mf}010000.csv"
                    echo "Processing " $fname 
                    if (( $count == 1 )); then
                        cp $fname $merged_fname
                    else
                        tail -n +2 $fname >> $merged_fname
                    fi
                    echo "Done " $merged_fname
                    count=$(( $count + 1 ))
            fi
        done
    done
done


# move the last 4 lines from file 0 to file 1 for price/demand
# for type in $dispatch_price $demand;do
#     for year in $(seq 2010 2020); do
#         next_year=$(( $year+1 ))
#         sname="${type}_${year}.csv"
#         dname="${type}_${next_year}.csv"

#         echo "Processing " $sname " - " $dname
#         if (( year < 2020 )); then
#             head -n 1 $dname > temp
#             tail -n 5 $sname >> temp
#             awk -F ',' 'NR>1{ print $0 }' < $dname >> temp 
#             mv temp $dname

#             python -c "import sys; a=[]; [a.append(line) for line in sys.stdin]; [sys.stdout.write(l) for l in a[:-5]]" < $sname > temp
#             mv temp $sname
#         fi
#     done
# done



# Gas price
# https://aemo.com.au/-/media/files/gas/dwgm/2020/price-and-withdrawals-2019.xlsx?la=en&hash=E04D2C1D121115C955695F2E6132223D
# https://aemo.com.au/-/media/files/gas/dwgm/2019/price-and-withdrawals-2018.xlsx?la=en&hash=EAA1BA1E3C76F655C7A320354713077E
# https://aemo.com.au/-/media/files/gas/dwgm/2018/price-and-withdrawals-2017.xlsx?la=en&hash=F81F157CF9CAD6B015F70C01FEA353D9

# for year in $(seq 2011 2020); do
#     url="https://aemo.com.au/-/media/files/gas/dwgm/2020/price-and-withdrawals-2019.xlsx?la=en&hash=E04D2C1D121115C955695F2E6132223D"
#     curl -O $url
# done

# for type in $dispatch_data;do
#     for year in $(seq 2010 2020); do
#         sname="${type}_${year}.csv"
#         sed '$d' $sname > temp
#         mv temp $sname
#     done
# done