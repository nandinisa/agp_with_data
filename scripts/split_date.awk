#!/usr/bin/env awk -f

# first column has to be: SETTLEMENTDATE 
# split SETTLEMENTDATE date to 2 columns: SETTLEMENTDATE and SETTLEMENTTIME
BEGIN{
    FS=OFS=","
}
NR==1{
    split($0, header, ",")
    s="SETTLEMENTDATE,SETTLEMENTTIME"
    for(i=2;i<=length(header);i++)
    {
        s=s","header[i]
    }
    print s
}
NR>1{
    split($0, cols, "\"")
    split(cols[2], datetime, " ")
    s=datetime[1]","datetime[2]""cols[3]
    print s
}