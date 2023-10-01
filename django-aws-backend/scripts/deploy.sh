#!/bin/bash

set -e

# Collect ECS_GROUP_ID and PRIVATE_SUBNET_ID for running migrations
echo "Collecting data..."
ECS_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=prod-ecs-backend --query "SecurityGroups[*][GroupId]" --output text)
PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets  --filters "Name=tag:Name,Values=prod-private-1" --query "Subnets[*][SubnetId]"  --output text)

echo "Running migration task..."
# Construct NETWORK_CONFIGURATON to run migtaion task 
NETWORK_CONFIGURATON="{\"awsvpcConfiguration\": {\"subnets\": [\"${PRIVATE_SUBNET_ID}\"], \"securityGroups\": [\"${ECS_GROUP_ID}\"],\"assignPublicIp\": \"DISABLED\"}}"
# Start migration task
MIGRATION_TASK_ARN=$(aws ecs run-task --cluster prod --task-definition backend-migration --count 1 --launch-type FARGATE --network-configuration "${NETWORK_CONFIGURATON}" --query 'tasks[*][taskArn]' --output text)
echo "Task ${MIGRATION_TASK_ARN} running..."
# Wait migration task to complete
aws ecs wait tasks-stopped --cluster prod --tasks "${MIGRATION_TASK_ARN}"

echo "Updating web..."
# Updating web service
aws ecs update-service --cluster prod --service prod-backend-web --force-new-deployment  --query "service.serviceName"  --output json

echo "Done!"


echo "Updating web..."
aws ecs update-service --cluster prod --service prod-backend-web --force-new-deployment  --query "service.serviceName"  --output json
echo "Updating worker..."
aws ecs update-service --cluster prod --service prod-backend-worker --force-new-deployment  --query "service.serviceName"  --output json
echo "Updating beat..."
aws ecs update-service --cluster prod --service prod-backend-beat --force-new-deployment  --query "service.serviceName"  --output json

echo "Done!"