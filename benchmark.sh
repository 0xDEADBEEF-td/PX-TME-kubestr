#!/bin/bash
STORAGECLASS=portworx-sc
# Size of PVC used for FIO testing
FIOSIZE=50Gi

check_pvc () {
PVCNUM=$(kubectl get pvc -A -o jsonpath='{.items[*].spec.storageClassName}' | grep $STORAGECLASS | wc -w)

until [ "$PVCNUM" = "0" ]; do
   echo "PVC found for StorageClass $STORAGECLASS. Waiting until existing PVC is removed/deleted."
   sleep 10 
   PVCNUM=$(kubectl get pvc -A -o jsonpath='{.items[*].spec.storageClassName}' | grep $STORAGECLASS | wc -w)
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

kubectl get sc | grep -q $STORAGECLASS
SC_EXIST=$(echo $?)

if [ "$SC_EXIST" = "0" ]; then
    echo "Found StorageClass $STORAGECLASS, executing FIO benchmarks."
    unset SC_EXIST
else
    echo "Could not find StorageClass $STORAGECLASS, please ensure you have created the StorageClass you wish to test and try again."
    exit 1
fi

check_pvc

echo "Running random RW mix FIO profile. System time is $(date)"
./kubestr fio -z $FIOSIZE -s $STORAGECLASS -f fio-profiles/px-rand-RW.fio -o json -e rand-RW-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null

check_pvc

echo "Running sequential RW mix FIO profile. System time is $(date)"
./kubestr fio -z $FIOSIZE -s $STORAGECLASS -f fio-profiles/px-seq-RW.fio -o json -e seq-RW-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null

check_pvc

echo "Running random read FIO profile. System time is $(date)"
./kubestr fio -z $FIOSIZE -s $STORAGECLASS -f fio-profiles/px-rand-read.fio -o json -e rand-read-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null

check_pvc

echo "Running random write FIO profile. System time is $(date)"
./kubestr fio -z $FIOSIZE -s $STORAGECLASS -f fio-profiles/px-rand-write.fio -o json -e rand-write-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null

check_pvc

echo "Running sequential read FIO profile. System time is $(date)"
./kubestr fio -z $FIOSIZE -s $STORAGECLASS -f fio-profiles/px-seq-read.fio -o json -e seq-read-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null

check_pvc

echo "Running sequential write FIO profile. System time is $(date)"
./kubestr fio -z $FIOSIZE -s $STORAGECLASS -f fio-profiles/px-seq-write.fio -o json -e seq-write-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').json >& /dev/null

check_pvc

echo "All FIO tests completed. Please find results in files named *-$STORAGECLASS.json."
}

pgbench () {
# Check for StorageClass
kubectl get sc | grep -q $STORAGECLASS
SC_EXIST=$(echo $?)

if [ "$SC_EXIST" = "0" ]; then
    echo "Found StorageClass $STORAGECLASS, deploying postgres."
    unset SC_EXIST
else
    echo "Could not find StorageClass $STORAGECLASS, please ensure you have created the StorageClass you wish to test and try again."
    exit 1
fi

check_pvc

# Create the Postgres PVC
cp postgres/postgres-pvc-template.yaml postgres/postgres-pvc.yaml
sed -i "s/SC_NAME/$STORAGECLASS/g" postgres/postgres-pvc.yaml
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
kubectl exec -i postgres-0 -- bash -c "pgbench -U admin -i -s 10 sampledb"

# Run pgbench TPC-B
kubectl exec -i postgres-0 -- bash -c "pgbench -U admin -c 10 -j 2 -t 10000 sampledb" > pgbench-$STORAGECLASS-$(date '+%Y-%m-%d-%H%M%S').txt
}

pgbench_cleanup() {
kubectl delete sts postgres
kubectl delete all -l app=postgres
kubectl delete cm postgres-config
kubectl delete pvc postgres-data
check_pvc
}


# Main - run FIO benchmarks and 5x pgbench (to be averaged manually)
fio_benchmark

for i in {1..5}
do
    pgbench
    pgbench_cleanup
done
