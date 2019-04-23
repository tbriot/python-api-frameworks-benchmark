# Python API frameworks tested
* Flask Restful: https://flask-restful.readthedocs.io/
* Falcon (todo): https://falconframework.org/
* ???

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
See reddit thread: https://www.reddit.com/r/aws/comments/bg448q/ecs_fargate_latency_issue/


AWS Deep dive on Container Networking : https://www.youtube.com/watch?v=1upInHReIxI&list=WL&index=67&t=1770s

1 thread 1 connection
```
wrk --duration 10s --threads 1 --connections 1 --timeout 10 http://10.0.1.78:8000
```

t2.micro ec2 instance to t2.micro ec2 instance in the same subnet (public subnet):
* with private IP: 1.20ms
* with public IP: 1ms (slightly faster)

Same test with apache http server, serving static html file: 0.45ms

home desktop to t2.micro ec2 instance in public subnet: 17.5ms

t2.micro ec2 instance to ecs fargate task in the same subnet (public subnet):
* with private IP: 14ms !!! :(
* with public IP: 13ms (slightly faster)

home desktop to ecs fargate task (public subnet): 17ms

t2.micro ec2 instance to ecs task  (ec2 launch type, t2.micro) in the same subnet (public subnet):
* with private IP: 1ms
* with public IP: 1ms

home desktop to ecs task (ec2 launch type, t2.micro) (public subnet): 17ms

Conclusion: something is wrong with ECS Fargate 'awsvpc' Network Mode. Adds 12ms latency to calls originating from the same subnet.

Boosting ECS Fargate task to 1vCPU and 2GB : latency = 0.9ms !!
v2: 0.25vCPU / 512MB : 14ms
v4: 0.25vCPU / 1GB: 9ms
v5: 0.25vCPU / 2GB: 9ms
v6: 0.5vCPU / 1GB: 1ms
v3: 1vCPU / 2GB : 0.9ms
v7: 4vCPU / 8GB : 0.9ms

## Load testing
Using **wrk** benchmark tool. See https://github.com/wg/wrk.

```
# Example: 30 seconds, 4 threads, 5 connections
wrk --duration 30s --threads 4 --connections 4 --timeout 10 http://35.182.155.194:5000/
```

Results: around 1000 req/sec per vCPU provisioned.


# Falcon
* Falcon: 6k GitHub stars.