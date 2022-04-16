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

# Create the results dirs (including the pgbench dir) if it doesn't exist
mkdir -p results/pgbench
mkdir -p results/origjson

# Loop through the JSON results and extract the information for each run
for FILE in *.json; do
    WL_NAME=$(echo "$FILE" | cut -f 1 -d '.')
    RUN_NAME=$(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].jobname"|sed 's/"//g')
    mkdir -p results/$RUN_NAME
    OUTPUT_FILE="results/$RUN_NAME/$WL_NAME.txt"
    SC_NAME=$(cat $FILE | $JQ_PATH ."[0].Raw.storageClass.metadata.name"|sed 's/"//g')
    echo "Job Name:" $RUN_NAME >> $OUTPUT_FILE
    echo "StorageClass:" $SC_NAME >> $OUTPUT_FILE
    echo "From File:" $FILE >> $OUTPUT_FILE
    echo >> $OUTPUT_FILE
    echo "Read IOPS:" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].read.iops") >> $OUTPUT_FILE
    echo "Read BW (KiB/s):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].read.bw") >> $OUTPUT_FILE
    echo "Read Latency (ns):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].read.lat_ns.mean") >> $OUTPUT_FILE
    echo >> $OUTPUT_FILE
    echo "Write IOPS:" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].write.iops") >> $OUTPUT_FILE
    echo "Write BW (KiB/s):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].write.bw") >> $OUTPUT_FILE
    echo "Write Latency (ns):" $(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[1].write.lat_ns.mean") >> $OUTPUT_FILE
    echo >> $OUTPUT_FILE
    LAYOUT_NAME=$(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[0].jobname"|sed 's/"//g')
    echo "File Layout Job Name:" $LAYOUT_NAME >> $OUTPUT_FILE
    FILE_CREATE_MS=$(cat $FILE | $JQ_PATH ."[0].Raw.result.jobs[0].job_runtime"|sed 's/"//g')
    FILE_CREATE_SEC=$(expr $FILE_CREATE_MS / 1000)
    echo "Time to layout file:" $FILE_CREATE_SEC seconds >> $OUTPUT_FILE
    mv $FILE results/origjson
done

# Move the pgbench results to the results folder
mv pgbench-* results/pgbench