#!/bin/bash
# Check for jq existence
command -v jq >& /dev/null
JQ_EXIST=$(echo $?)
JQ_PATH=$(command -v jq)

if [ "$JQ_EXIST" = "0" ]; then
    echo "Found jq binary at $JQ_PATH."
else
    echo "Could not find jq binary, please make sure it is installed on your system."
    exit 1
fi

# Check for json file existence
jsonarray=(`find ./ -maxdepth 1 -name "*.json"`)
if [ ${#jsonarray[@]} -gt 0 ]; then 
    echo "Found JSON files to parse." 
else 
    echo "Did not find any JSON files, are there any JSON files to parse?"
    exit 1
fi

# Loop through the JSON results and extract the information for each run
for FILE in *.json; do
    RUN_NAME=$(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].jobname"|sed 's/"//g')
    SC_NAME=$(cat $FILE | $JQ_PATH ."[0].Raw.storageClass.metadata.name"|sed 's/"//g')
    echo "Job Name:" $RUN_NAME >> $SC_NAME-$RUN_NAME.txt
    echo "StorageClass:" $SC_NAME >> $SC_NAME-$RUN_NAME.txt
    echo "From File:" $FILE >> $SC_NAME-$RUN_NAME.txt
    echo >> $SC_NAME-$RUN_NAME.txt
    echo "Read IOPS:" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].read.iops") >> $SC_NAME-$RUN_NAME.txt
    echo "Read BW (KiB/s):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].read.bw") >> $SC_NAME-$RUN_NAME.txt
    echo "Read Latency (ns):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].read.lat_ns.mean") >> $SC_NAME-$RUN_NAME.txt
    echo >> $SC_NAME-$RUN_NAME.txt
    echo "Write IOPS:" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].write.iops") >> $SC_NAME-$RUN_NAME.txt
    echo "Write BW (KiB/s):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].write.bw") >> $SC_NAME-$RUN_NAME.txt
    echo "Write Latency (ns):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].write.lat_ns.mean") >> $SC_NAME-$RUN_NAME.txt
    echo >> $SC_NAME-$RUN_NAME.txt
    LAYOUT_NAME=$(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[0].jobname"|sed 's/"//g')
    echo "File Layout Job Name:" $LAYOUT_NAME >> $SC_NAME-$RUN_NAME.txt
    FILE_CREATE_MS=$(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[0].job_runtime"|sed 's/"//g')
    FILE_CREATE_SEC=$(expr $FILE_CREATE_MS / 1000)
    echo "Time to layout file:" $FILE_CREATE_SEC seconds >> $SC_NAME-$RUN_NAME.txt
done
