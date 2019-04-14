# Python API frameworks tested
* Flask Restful: https://flask-restful.readthedocs.io/
* Falcon (todo): https://falconframework.org/
* ???

# API endpoints
Implementing two HTTP endpoints.
* **/hello** (GET)  
Returns a "hello world" JSON string.

* **/sleep/_delay_**  (GET)  
The API waits for _delay_ milliseconds before returning a JSON string.  
e.g. /sleep/2000 returns a response after 2 seconds.

# Docker images
## Official Python Docker images
See https://hub.docker.com/_/python?tab=description

### python:3.6
"Fat" image. OS is Debian. Contains a large number of common Debian packages. **Size: 924MB**

### python:3.6-slim
OS is Debian. Contains the minimal packages needed to run python.
**Size: 138MB**

### python:3.6-alpine
OS is Alpine Linux. **Size: 79MB**

Flask library and dependencies add 10MB to the image size.

## Why smaller images are better?
* faster container startup on ECS Fargate. Fargate is a serverless solution. Images are not cached on the Docker Host. The full image has to be pulled from the Docker repository whenever a task is launched.
* security consideration: smaller packages = smaller surface of attack.
* ECR pricing is based on image storage. $0.10 per GB-month.

Read:  
https://stackoverflow.com/questions/51618252/how-to-speed-up-deployments-on-aws-fargate
https://www.reddit.com/r/aws/comments/7ixf1q/ecs_fargate_bluegreen_deployments/
https://stackoverflow.com/questions/48006598/how-fast-can-ecs-fargate-boot-a-container
https://datree.io/blog/migrating-to-aws-ecs-fargate-in-production/


# Flask RESTful
## Popularity
Flask Restful: 4k GitHub stars.  
Flask: 43k stars.

## Library (+ dependencies) size
Size: **5.5MB**
```
pip install flask-restful --user --upgrade --upgrade-strategy -t ./libraries
du -bh ./libraries/ 
```


# Falcon
* Falcon: 6k GitHub stars.