#!/bin/bash
RAND_STORAGECLASS=portworx-sc
SEQ_STORAGECLASS=portworx-sc
DB_STORAGECLASS=portworx-sc
# Size of PVC used for FIO testing
FIOSIZE=50Gi
# Size of file used in FIO pod for testing (in GiB)
FILESIZE=1
# Number of kubestr pods to instantiate
NUM_WORKLOADS=2
# Number of concurrent pgbench workloads to instantiate (only used when calling concurrent pgbench!)
NUM_PGBENCH_WORKLOADS=2
# Duration of concurrent pgbench workloads
PGBENCH_CONCURRENT_DURATION=300

create_fio_profiles () {
  cp fio-profiles/template/*.fio fio-profiles
  SIZE_STRING="size="$FILESIZE"GiB"
  for FILE in fio-profiles/*.fio; do
    sed -i "s/size=10GiB/$SIZE_STRING/g" $FILE
  done
}


check_pvc () {
PVCNUM=$(kubectl get pvc -A -o jsonpath='{.items[*].spec.storageClassName}' | grep $1 | wc -w)

until [ "$PVCNUM" = "0" ]; do
   echo "PVC found for StorageClass $1. Waiting until existing PVC is removed/deleted."
   sleep 10 
   PVCNUM=$(kubectl get pvc -A -o jsonpath='{.items[*].spec.storageClassName}' | grep $1 | wc -w)
done
}

check_fio_pod () {
FIO_PODNUM=$(kubectl get pod | grep kubestr | wc -l)

until [ "$FIO_PODNUM" = "0" ]; do
  echo "$FIO_PODNUM FIO workloads still running. Waiting for completion of all FIO workloads - system time is $(date)."
  sleep 60
  FIO_PODNUM=$(kubectl get pod | grep kubestr | wc -l)
done
}

fio_benchmark () {
FILE=kubestr
if [ -x "$FILE" ]; then
    echo "Found $FILE binary and is executable."
else 
    echo "$FILE does not exist or is not executable, exiting."
    exit 1
fi

# Check for existence of the RAND_STORAGECLASS
kubectl get sc | grep -q $RAND_STORAGECLASS
RAND_SC_EXIST=$(echo $?)

if [ "$RAND_SC_EXIST" = "0" ]; then
    echo "Found StorageClass $RAND_STORAGECLASS, executing FIO benchmarks."
    unset RAND_SC_EXIST
else
    echo "Could not find StorageClass $RAND_STORAGECLASS, please ensure you have created the StorageClass you wish to test and try again."
    exit 1
fi

# Check for existence of the SEQ_STORAGECLASS
kubectl get sc | grep -q $SEQ_STORAGECLASS
SEQ_SC_EXIST=$(echo $?)

if [ "$SEQ_SC_EXIST" = "0" ]; then
    echo "Found StorageClass $SEQ_STORAGECLASS, executing FIO benchmarks."
    unset SEQ_SC_EXIST
else
    echo "Could not find StorageClass $SEQ_STORAGECLASS, please ensure you have created the StorageClass you wish to test and try again."
    exit 1
fi

check_pvc $RAND_STORAGECLASS

START=1

echo "Running random RW mix FIO profile with $NUM_WORKLOADS workloads. System time is $(date)"
i=$START
while [[ $i -le $NUM_WORKLOADS ]]
do
    ./kubestr fio -z $FIOSIZE -s $RAND_STORAGECLASS -f fio-profiles/px-rand-RW.fio -o json -e rand-RW-WL-$i-$RAND_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null &
    sleep 10
    ((i = i + 1))
done

check_fio_pod
check_pvc $RAND_STORAGECLASS
check_pvc $SEQ_STORAGECLASS

echo "Running sequential RW mix FIO profile. System time is $(date)"
i=$START
while [[ $i -le $NUM_WORKLOADS ]]
do
./kubestr fio -z $FIOSIZE -s $SEQ_STORAGECLASS -f fio-profiles/px-seq-RW.fio -o json -e seq-RW-WL-$i-$SEQ_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null &
    sleep 10
    ((i = i + 1))
done

check_fio_pod
check_pvc $SEQ_STORAGECLASS
check_pvc $RAND_STORAGECLASS

echo "Running random read FIO profile. System time is $(date)"
i=$START
while [[ $i -le $NUM_WORKLOADS ]]
do
./kubestr fio -z $FIOSIZE -s $RAND_STORAGECLASS -f fio-profiles/px-rand-read.fio -o json -e rand-read-WL-$i-$RAND_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null &
    sleep 10
    ((i = i + 1))
done

check_fio_pod
check_pvc $RAND_STORAGECLASS

echo "Running random write FIO profile. System time is $(date)"
i=$START
while [[ $i -le $NUM_WORKLOADS ]]
do
./kubestr fio -z $FIOSIZE -s $RAND_STORAGECLASS -f fio-profiles/px-rand-write.fio -o json -e rand-write-WL-$i-$RAND_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null &
    sleep 10
    ((i = i + 1))
done

check_fio_pod
check_pvc $RAND_STORAGECLASS
check_pvc $SEQ_STORAGECLASS

echo "Running sequential read FIO profile. System time is $(date)"
i=$START
while [[ $i -le $NUM_WORKLOADS ]]
do
./kubestr fio -z $FIOSIZE -s $SEQ_STORAGECLASS -f fio-profiles/px-seq-read.fio -o json -e seq-read-WL-$i-$SEQ_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null &
    sleep 10
    ((i = i + 1))
done

check_fio_pod
check_pvc $SEQ_STORAGECLASS

echo "Running sequential write FIO profile. System time is $(date)"
i=$START
while [[ $i -le $NUM_WORKLOADS ]]
do
./kubestr fio -z $FIOSIZE -s $SEQ_STORAGECLASS -f fio-profiles/px-seq-write.fio -o json -e seq-write-WL-$i-$SEQ_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null &
    sleep 10
    ((i = i + 1))
done

check_fio_pod
check_pvc $SEQ_STORAGECLASS

echo "All FIO tests completed. Please find results in files named *.json."
}

pgbench () {
# Check for StorageClass
kubectl get sc | grep -q $DB_STORAGECLASS
DB_SC_EXIST=$(echo $?)

if [ "$DB_SC_EXIST" = "0" ]; then
    echo "Found StorageClass $DB_STORAGECLASS, deploying postgres."
    unset DB_SC_EXIST
else
    echo "Could not find StorageClass $DB_STORAGECLASS, please ensure you have created the StorageClass you wish to test and try again."
    exit 1
fi

check_pvc $DB_STORAGECLASS

# Create the Postgres PVC
cp postgres/postgres-pvc-template.yaml postgres/postgres-pvc.yaml
sed -i "s/SC_NAME/$DB_STORAGECLASS/g" postgres/postgres-pvc.yaml
kubectl apply -f postgres/postgres-pvc.yaml
rm postgres/postgres-pvc.yaml

# Deploy postgres
kubectl apply -f postgres/postgres.yaml

PG_UP=1
until [ "$PG_UP" = "0" ]; do
    kubectl get pod | grep postgres-0 | grep -q Running
    PG_UP=$?
done

PG_READY=1
until [ "$PG_READY" = "0" ]; do
    kubectl logs postgres-0 | grep -q "database system is ready to accept connections"
    PG_READY=$?
done

sleep 5

# Create/initialize sampledb
kubectl exec -i postgres-0 -- bash -c "createdb -U admin sampledb"
kubectl exec -i postgres-0 -- bash -c "pgbench -U admin -i -s 600 sampledb"

# Run pgbench TPC-B
kubectl exec -i postgres-0 -- bash -c "pgbench -U admin -c 1 -j 1 -T 600 sampledb" > pgbench-$DB_STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').txt
}

pgbench_cleanup() {
kubectl delete sts postgres
kubectl delete all -l app=postgres
kubectl delete cm postgres-config
kubectl delete pvc postgres-data
check_pvc $DB_STORAGECLASS
}

pgbench_concurrent() {
  PG_START=1
# Check for StorageClass
kubectl get sc | grep -q $DB_STORAGECLASS
DB_SC_EXIST=$(echo $?)

if [ "$DB_SC_EXIST" = "0" ]; then
    echo "Found StorageClass $DB_STORAGECLASS, deploying postgres."
    unset DB_SC_EXIST
else
    echo "Could not find StorageClass $DB_STORAGECLASS, please ensure you have created the StorageClass you wish to test and try again."
    exit 1
fi

check_pvc $DB_STORAGECLASS

i=$PG_START
while [[ $i -le $NUM_PGBENCH_WORKLOADS ]]
do
# Create the Postgres PVC
cp postgres/postgres-pvc-template.yaml postgres/postgres-pvc-$i.yaml
sed -i "s/SC_NAME/$DB_STORAGECLASS/g" postgres/postgres-pvc-$i.yaml
sed -i "s/postgres-data/postgres-data-$i/g" postgres/postgres-pvc-$i.yaml
kubectl apply -f postgres/postgres-pvc-$i.yaml
rm postgres/postgres-pvc-$i.yaml

# Deploy postgres
cp postgres/postgres-concurrent-template.yaml postgres/postgres-$i.yaml
sed -i "s/postgres-config-N/postgres-config-$i/g" postgres/postgres-$i.yaml
sed -i "s/postgres-N/postgres-$i/g" postgres/postgres-$i.yaml
sed -i "s/DURATION-N/$PGBENCH_CONCURRENT_DURATION/g" postgres/postgres-$i.yaml
sed -i "s/postgres-data-N/postgres-data-$i/g" postgres/postgres-$i.yaml

kubectl apply -f postgres/postgres-$i.yaml
rm postgres/postgres-$i.yaml

echo "kubectl delete sts postgres-$i" >> pgbench_concurrent_cleanup.sh
echo "kubectl delete all -l app=postgres-$i" >> pgbench_concurrent_cleanup.sh
echo "kubectl delete cm postgres-config-$i" >> pgbench_concurrent_cleanup.sh
echo "kubectl delete pvc postgres-data-$i" >> pgbench_concurrent_cleanup.sh
chmod 777 pgbench_concurrent_cleanup.sh

    ((i = i + 1))
    sleep 2
done
}

# Main - run FIO benchmarks and 3x pgbench (to be averaged manually)
create_fio_profiles
fio_benchmark

for i in {1..3}
do
    pgbench
    pgbench_cleanup
done
