# PX-TME-kubestr

This test harness assumes you have setup either Portworx Enterprise/Essentials or a competing product to test with.

To run the benchmark, perform the following:
 - Setup the StorageClass you wish to use with the test harness
 - Ensure there are no PVCs created for the StorageClass you wish to use
 - Extract the appropriate version of kubestr for your platform (X86_64 Linux or MacOS) and ensure the 'kubestr' binary is in the root of the folder
 - Modify the 'STORAGECLASS' and 'FIOSIZE' variables in the benchmark.sh script to reflect the k8s StorageClass and PVC size (minimum 10Gi) you wish to test with, respectively
 - Execute the benchmark.sh script

A total of 6x FIO tests will run, these take approximately 20 minutes total to complete:
 - Random R/W 60/40 Mix 4k block size, 10Gi file
 - Sequential R/W 60/40 Mix 256k block size, 10Gi file
 - Random Read 100% 4k block size, 10Gi file
 - Random Write 100% 4k block size, 10Gi file
 - Sequential Read 100% 256k block size, 10Gi file
 - Sequential Write 100% 256k block size, 10Gi file

Once FIO tests have completed, 5x pgbench runs will execute, the timing on these is dependent on how fast the system you are running on is. Each run performs the following:
 - Creates a 1Gi PVC for the postgres container
 - Deploys the postgres:14.1-alpine image and mounts the PV to the data directory (PGDATA)
 - Creates "sampledb" (kubectl exec -i postgres-0 -- bash -c "createdb -U admin sampledb")
 - Initializes "sampledb" with scale factor of 10 (kubectl exec -i postgres-0 -- bash -c "pgbench -U admin -i -s 10 sampledb")
 - Executes pgbench with 10 clients and 10,000 TX per client (kubectl exec -i postgres-0 -- bash -c "pgbench -U admin -c 10 -j 2 -t 10000 sampledb")
 - Once each pgbench run is complete, deletes all postgres pods, services, statefulsets, configmaps, and the associated PVC, and executes again until 5 total runs are reached

When the benchmark is completed, there should be 6 files for the FIO results in JSON format with the name <FIO Profile>-<StorageClassName>-<Date>.json, and 5x pgbench results files in text format with the name pgbench-<StorageClassName>-<Date>.txt in the root folder.
