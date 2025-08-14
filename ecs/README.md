# ECS

https://github.com/aws-containers/retail-store-sample-app/tree/main/terraform/lib

Tasks represents running task definition either standalone or as part of a service!

mysql -h retail-store-db.cpswoiwcqo4q.eu-central-1.rds.amazonaws.com -u catalog -p

aws ecs execute-command --cluster retail-store --task RUNNING_TASK_ARN  --container retailStore --interactive --command "/bin/bash" --profile zero

## Takeway
Working with ECS feels unpredictable

Terraform takes long to refresh state of task defs and services

??Slow updating tasks definitions and services. Bad for debugging config.