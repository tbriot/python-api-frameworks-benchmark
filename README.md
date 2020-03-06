# Python API frameworks tested
* Flask Restful: https://flask-restful.readthedocs.io/

# Frameworks popularity
Flask Restful: 4k GitHub stars.  
Flask: 43k stars.

# API endpoints
Implementing two HTTP endpoints.
* **/hello** (GET)  
Returns a "hello world" JSON string.

* **/sleep/_delay_**  (GET)  
The API waits for _delay_ milliseconds before returning a JSON string.  
e.g. /sleep/2000 returns a response after 2 seconds.

# HTTP server

Using **Gunicorn** (Python WSGI HTTP server for UNIX). See https://gunicorn.org/.

Size: **757KB**
```
pip install gunicorn -t ./gunicorn-libraries
du -bh ./gunicorn-libraries
```

# Dockerizing the app
## Base image: official Python Docker images
See https://hub.docker.com/_/python

Three flavors available:

* **python:3.6**: "Fat" image. OS is Debian. Contains a large number of common Debian packages. **Size: 924MB**
* **python:3.6-slim**: OS is Debian. Contains the minimal packages needed to run python.
**Size: 138MB**
* **python:3.6-alpine**: OS is Alpine Linux. **Size: 79MB**

## Why smaller images are better?
* faster container startup on ECS Fargate. Fargate is a serverless solution. Images are not cached on the Docker Host. The full image has to be pulled from the Docker repository whenever a task is launched.
* security consideration: smaller packages = smaller surface of attack.
* ECR pricing is based on image storage. $0.10 per GB-month.

Read:  
https://stackoverflow.com/questions/51618252/how-to-speed-up-deployments-on-aws-fargate
https://www.reddit.com/r/aws/comments/7ixf1q/ecs_fargate_bluegreen_deployments/
https://stackoverflow.com/questions/48006598/how-fast-can-ecs-fargate-boot-a-container
https://datree.io/blog/migrating-to-aws-ecs-fargate-in-production/

## Building Docker images
```
cd flask-restful
docker build -f alpine.Dockerfile -t flask-restful-api-benchmark:alpine .
docker build -f slim.Dockerfile -t flask-restful-api-benchmark:slim .
docker build -f fat.Dockerfile -t flask-restful-api-benchmark:fat .
```

## Images size with the API code

### Gunicorn (HTTP server) size
Size: **757KB**
```
pip install gunicorn -t ./gunicorn-libraries
du -bh ./gunicorn-libraries
```

### Flask Restful library (+ dependencies) size
Size: **10MB**
```
pip install flask-restful -t ./flask-restful-libraries
du -bh ./flask-restful-libraries 
```

### Docker images size
* **python:3.6**:
    *  Flask Restful + Gunicorn: 934 MB, 357 MB compressed in ECR
* **python:3.6-slim**:
    *  Flask Restful + Gunicorn: 149 MB, 53 MB compressed in ECR
* **python:3.6-alpine**:
    *  Flask Restful + Gunicorn: 91 MB, **34 MB compressed in ECR** :)

Note: images size are smaller in ECR since docker clients compress image layers before pushing them to Docker registries. This is not specific to ECR. See https://docs.aws.amazon.com/cli/latest/reference/ecr/describe-images.html.


## Pushing images to Amazon ECR
```
# Create Amazon ECR repository
aws ecr create-repository --repository-name flask-restful-api-benchmark

# Tag Docker images with ECR repository
docker tag flask-restful-api-benchmark:alpine 535992502053.dkr.ecr.ca-central-1.amazonaws.com/flask-restful-api-benchmark:alpine
docker tag flask-restful-api-benchmark:slim 535992502053.dkr.ecr.ca-central-1.amazonaws.com/flask-restful-api-benchmark:slim
docker tag flask-restful-api-benchmark:fat 535992502053.dkr.ecr.ca-central-1.amazonaws.com/flask-restful-api-benchmark:fat

# Get docker login command from AWS
aws ecr get-login --no-include-email

# Login to ECR
docker login -u AWS -p <secret> https://535992502053.dkr.ecr.ca-central-1.amazonaws.com

# Push images to ECR
docker push 535992502053.dkr.ecr.ca-central-1.amazonaws.com/flask-restful-api-benchmark:alpine
docker push 535992502053.dkr.ecr.ca-central-1.amazonaws.com/flask-restful-api-benchmark:slim
docker push 535992502053.dkr.ecr.ca-central-1.amazonaws.com/flask-restful-api-benchmark:fat
```

# ECS Fargate task startup time
## Task startup time and Docker image size
Test:
* a task definitions is created for each Docker image ("fat", slim and alpine) 
* images size in ECR (compressed): fat = 358 MB, slim = 53 MB, alpine = 34 MB
* task CPU = 0.25 vCPU, task memory = 512 MB 
* an ECS service is created for each task definition
* 10 tasks per service
* the startup time of each task can be inferred from the "created at" and "started at" timestamp in the AWS Console or _describe-tasks_ AWS CLI command.
* computing the average startup time of the 10 tasks

Results:
* alpine image: task avg startup time = **19.8 sec**
* slim image: task avg startup time = **19.2 sec**
* **fat image**: task avg startup time = **34.6 sec**

Conclusion:
* **Docker image size does matter** when it comes to the ECS Fargate launch type
* Tasks with the fat image takes **75% more time** to start than the slim or alpine ones

## Task startup time and CPU
Do tasks start faster with more CPU ?

Test:
* Using the "fat" Python Docker image
* 4 vCPU instead of 0.25 vCPU
* same protocol as above (10 tasks are launched)

Results:
* fat image: task avg startup time = **32.3 sec** (5% faster)

Conclusion:
* Increasing vCPU does **not** speed up task startup time significantly
* hypothesis: the small improvement, if any, may come from the decompression of the image on the Docker host. Does not seem to be worth the extra vCPU though

## Task startup time and VPC Endpoints
Do tasks start faster if they use VPC Endpoints to pull image from ECR ?

Test:
* Using the "fat" Python Docker image
* VPC Endpoints have been created in the VPC to reach ECR (and S3)
* 4 vCPU
* same protocol as above (10 tasks are launched)

Results:
* fat image: task avg startup time = 33.2 sec (3% slower)

Conclusion:
* VPC Endpoints do **not** speed up task startup time
* those endpoints can be useful if your tasks are running in a private subnet and you don't want to overload your NAT Gateway with large docker images downloads. But it won't improve your tasks startup time.

# Task memory utilization
Without any load:
* slim and alpine based docker image: 14.5% of 512 MB
* fat image: 14.6% of 512 MB

Conclusion: **75 MB of memory consumed when idle**



## Latency

The number of vCPU assigned to the ECS Task definition **impacts the response time** of the API, even if the load is minimal: 
- 0.25 vCPU, 14ms response time !! :(
- 0.5 vCPU, 1ms response time

More details in this reddit thread: https://www.reddit.com/r/aws/comments/bg448q/ecs_fargate_latency_issue/


To know more about ECS tasks networking: watch 'AWS Deep dive on Container Networking' video : https://www.youtube.com/watch?v=1upInHReIxI&list=WL&index=67&t=1770s

## Load testing
Using **wrk** benchmark tool. See https://github.com/wg/wrk.   
A bash script has been created to run the load tests: /wrk/run-load-tests.sh
It executes multiple load tests, increasing the number of concurrent http connections.

Load test is run from an EC2 instance in the same subnet as the ECS task.

```
# Example: 30 seconds, 4 threads, 5 connections
wrk --duration 30s --threads 4 --connections 4 --timeout 10 http://35.182.155.194:5000/
```

### Bottleneck on the client side
The number of opened ephemeral ports on the client side os was the bottleneck.  
By default, the Amazon Linux os shipped with the ec2 instance has a limit of 1024 opened ports. 

To increase the limits, the following file has to be edited: **/etc/security/limits.conf**

See https://superuser.com/questions/1200539/cannot-increase-open-file-limit-past-4096-ubuntu.


### Gunicorn non-blocking worker class
Performance were increased signficantly by using **asynch io** worker class.

Read https://medium.com/@genchilu/brief-introduction-about-the-types-of-worker-in-gunicorn-and-respective-suitable-scenario-67b0c0e7bd62.

If your API is not CPU-bound but I/O bound, the thread is not blocked, it can still process requests while waiting for the I/O access.

Using the **siege** tool (https://github.com/JoeDog/siege) and the **gevent** worker class, we could see the async behaviour of the API calls as describe in the Medium.com post above.


### Meinheld and evenlet worker class
For some reason we were not able to have asynch behaviour with these two worker classes.  
We suspect that the time.sleep() method call might be blocking for those frameworks.


### Results
Flask + Gunicorn + gevent workers combo is able to process around **1300 req/sec per vCPU** provisioned.  
At this rate the framework overhead is < 1ms.  
The CPU is the limiting factor. Memory utilization is pretty low < 100MB.  
If the number of connections is pushed beyond this limit then 100% CPU is consumed, and latency increases significantly.

The performance seems pretty linear.  
2x vCPU provides 2x req/sec.  
2x 1vCPU tasks supports almost the same load as 1x 2vCPU task.


### Load test samples w/ wrk

1vCPU, 1500 connections, 1 sec sleep, Flask, Gunicorn + gevent workers

```
Running 1m test @ http://35.183.93.139:8000/sleep/1000
  2 threads and 1500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.12s   110.34ms   2.02s    77.97%
    Req/Sec   673.16     87.25     0.96k    73.31%
  79203 requests in 1.00m, 15.11MB read
Requests/sec:   1318.29
Transfer/sec:    257.49KB
```

1vCPU, 1250 connections, 1 sec sleep, Flask, Gunicorn + gevent workers  
CPU: 83%

```
Running 1m test @ http://35.183.93.139:8000/sleep/1000
  2 threads and 1250 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.01s    53.52ms   1.70s    97.68%
    Req/Sec   625.04    129.40     1.11k    72.62%
  73376 requests in 1.00m, 14.00MB read
Requests/sec:   1221.29
Transfer/sec:    238.54KB
```

1vCPU, 1400 connections, 1 sec sleep, Flask, Gunicorn + gevent workers  
CPU: 100%

```
Running 1m test @ http://35.183.93.139:8000/sleep/1000
  2 threads and 1400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.05s    69.36ms   1.82s    95.82%
    Req/Sec   672.54     85.23     1.02k    75.68%
  79111 requests in 1.00m, 15.09MB read
Requests/sec:   1316.90
Transfer/sec:    257.21KB
```

1vCPU, 1350 connections, 1 sec sleep, Flask, Gunicorn + gevent workers  
CPU: 94%

```
wrk --duration 1m --threads 2 --connections 1350 --timeout 10 http://35.183.93.139:8000/sleep/1000

Running 1m test @ http://35.183.93.139:8000/sleep/1000
  2 threads and 1350 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.01s    56.33ms   1.77s    97.87%
    Req/Sec   674.30    139.41     1.01k    74.06%
  79102 requests in 1.00m, 15.09MB read
Requests/sec:   1318.15
Transfer/sec:    257.45KB
```

1vCPU, 650 connections, 500 msec sleep, Flask, Gunicorn + gevent workers  
CPU: 87%

```
Running 1m test @ http://35.183.93.139:8000/sleep/500
  2 threads and 650 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   503.64ms   17.23ms 827.27ms   98.15%
    Req/Sec   648.74    170.28     1.04k    68.27%
  76953 requests in 1.00m, 14.60MB read
Requests/sec:   1280.88
Transfer/sec:    248.92KB
```

2vCPU, 1350 connections, 1 sec sleep, Flask, Gunicorn + gevent workers  
CPU: 48%

```
Running 1m test @ http://99.79.33.246:8000/sleep/1000
  2 threads and 1350 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.01s    32.57ms   1.45s    97.77%
    Req/Sec     0.89k   430.66     1.58k    74.39%
  79414 requests in 1.00m, 15.15MB read
Requests/sec:   1321.45
Transfer/sec:    258.10KB
```

2vCPU, 2700 connections, 1 sec sleep, Flask, Gunicorn + gevent workers  
CPU: 98%

```
Running 1m test @ http://99.79.33.246:8000/sleep/1000
  2 threads and 2700 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.03s    59.28ms   1.88s    97.08%
    Req/Sec     1.32k   250.81     2.06k    71.94%
  154219 requests in 1.00m, 29.42MB read
Requests/sec:   2570.10
Transfer/sec:    501.98KB
```

## Pricing

As of May 2019, at equivalent vCPU and memory, ECS Fargate is **2x more expensive** as EC2.

### ECS Fargate pricing
roughly $0.05/hour/vCPUx2GB = $35 / month  
Lowest setup: 0.25vCPU +  512MB = $0.0136/hour = $9.7 / month

### EC2 pricing
t2.small (1vCPUx2GB) = 0.0256/hour    ===> half ECS price     =====> $18.4 / month  
t2.micro (1vCPUx1GB) = 0.0128/hour      =====> $9.2 / month  
t2.nano (1vCPUx0.5GB) = 0.0064/hour    =====> $4.6 / month
