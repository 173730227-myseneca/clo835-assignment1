# Ameya Kokatay's CLO835 Assignment 1

Please follow the steps listed below to for this assignment.

- [Ameya Kokatay's CLO835 Assignment 1](#Ameya-Kokatay's-CLO835-Assignment-1)
  - [Step 1: Generate ssh-key and deploy infrastructure using Terraform](#step-1-generate-ssh-key-and-deploy-infrastructure-using-terraform)
  - [Step 2: Review branches in GitHub and add secrets to the repository to be used by GitHub actions](#step-2-review-branches-in-github-and-add-secrets-to-the-repository-to-be-used-by-github-actions)
  - [Step 3: Push images to Amazon ECR using GitHub Actions](#step-3-push-images-to-amazon-ecr-using-github-actions)
  - [Step 4: Pull images from AWS ECR to the AWS EC2 instance spun up](#step-4-pull-images-from-aws-ecr-to-the-aws-ec2-instance-spun-up)
  - [Step 5: Run and test the mysql container](#step-5-run-and-test-the-mysql-container)
  - [Step 6: Run and test the webapp container](#step-6-run-and-test-the-webapp-container)
  - [Step 7: Confirm that the containers can ping eachother using their hostname](#step-7-confirm-that-the-containers-can-ping-eachother-using-their-hostname)
  - [Step 8: Explain why we can run 3 applications listening on the same port 8080 on a single EC2 instance.](#step-8-explain-why-we-can-run-3-applications-listening-on-the-same-port-8080-on-a-single-ec2-instance)
  - [Step 9: Demonstrate load balancing to the three applications using AWS ALB (BONUS)](#step-9-demonstrate-load-balancing-to-the-three-applications-using-aws-alb-bonus)

## Step 1: Generate ssh-key and deploy infrastructure using Terraform

Generate ssh key to be used to create the Amazon EC2 instance in the terraform folder

```bash
ssh-keygen -f assignment1
```

Deploy the infrastructure for the EC2 instance and the ECR repository and take a note of the public IP address returned as output 

```bash
terraform apply -auto-approve
```

## Step 2: Review branches in GitHub and add secrets to the repository to be used by GitHub actions

GitHub should have a `main` branch for final changes and `development` branch for initial changes.
The following secrets need to be added to the repository for authentication to AWS:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_SESSION_TOKEN

## Step 3: Push images to Amazon ECR using GitHub Actions

Run GitHub actions workflow either by merging a pull request into the main branch or re-running the last workflow if there are no new changes. Verify that the workflow creates new images in AWS ECR.

## Step 4: Pull images from AWS ECR to the AWS EC2 instance spun up

Log into the AWS instance and export your AWS credentials: `ssh -i assignment1 ec2-user@3.220.169.30`

Pull from AWS ECR:

```bash
aws configure
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 579130819361.dkr.ecr.us-east-1.amazonaws.com #here 579130819361 is your aws account number
docker pull 579130819361.dkr.ecr.us-east-1.amazonaws.com/mysql
docker pull 579130819361.dkr.ecr.us-east-1.amazonaws.com/webapp
docker images -a
```

## Step 5: Run and test the mysql container

Create the custom bridge network for deploying the applications into:

```bash
docker network create -d bridge --subnet 172.16.0.1/24 --gateway 172.16.0.1 app-network
docker network ls
```

Run the mysql container in the app-network custom bridge network:

```bash
docker run --name my_db --network app-network -d -e MYSQL_ROOT_PASSWORD=pw 579130819361.dkr.ecr.us-east-1.amazonaws.com/mysql
docker exec -it my_db /bin/bash
mysql -ppw
show databases;
use employees;
show tables;
select * from employee;
exit
exit
```

Inspect the container for its IP address and export variables as seen below:

```bash
docker inspect <container_id>
export DBHOST=172.16.0.2
export DBPORT=3306
export DBUSER=root
export DATABASE=employees
export DBPWD=pw
```

## Step 6: Run and test the webapp container

```bash
docker run --name blue --network app-network -d -p 8081:8080 -e DBHOST=$DBHOST -e DBPORT=$DBPORT -e  DBUSER=$DBUSER -e DBPWD=$DBPWD -e APP_COLOR=blue 579130819361.dkr.ecr.us-east-1.amazonaws.com/webapp:latest
docker run --name pink --network app-network -d -p 8082:8080 -e DBHOST=$DBHOST -e DBPORT=$DBPORT -e  DBUSER=$DBUSER -e DBPWD=$DBPWD -e APP_COLOR=pink 579130819361.dkr.ecr.us-east-1.amazonaws.com/webapp:latest
docker run --name lime --network app-network -d -p 8083:8080 -e DBHOST=$DBHOST -e DBPORT=$DBPORT -e  DBUSER=$DBUSER -e DBPWD=$DBPWD -e APP_COLOR=lime 579130819361.dkr.ecr.us-east-1.amazonaws.com/webapp:latest
docker ps
```

Access the containers from the web using the EC2 public IP obtained in Terraform and the specified host port:
- blue: `http://3.220.169.30:8081`
- pink: `http://3.220.169.30:8082`
- lime: `http://3.220.169.30:8083`

## Step 7: Confirm that the containers can ping eachother using their hostname

For example, log into blue with `docker exec -it blue /bin/bash`, install the ping utility with `apt-get install iputils-ping -y` and then run `ping pink` as well as `ping lime`.

## Step 8: Explain why we can run 3 applications listening on the same port 8080 on a single EC2 instance.

> Since we have created 3 containers from the webapp image, each of them can expose the port 8080. When we bind/map the port 8080 for each of them to individual host port, we can use the IP address of the host, which is an EC2 instance here, and the specified host port, we can access all three applications through applications on the same EC2 instance.

## Step 9: Demonstrate load balancing to the three applications using AWS ALB (BONUS)

Send a request to the load balancer DNS similar to from the Terraform output on port 8080: `app-alb-1968525317.us-east-1.elb.amazonaws.com:8080`