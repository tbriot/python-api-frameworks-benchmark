#!/bin/sh
# $1 is the endpoint URL, including the port, e.g. http://10.0.1.78:8000/
echo Running load test on $1 endpoint
echo Duration set to $2
echo Pause between tests set to $3

for i in 2 4 8 16 32 64 128 256 512 1024
do
  echo ------------------------------------------------------------
  wrk --duration $2 --threads 2 --connections $i --timeout 10 $1
  sleep $3
done