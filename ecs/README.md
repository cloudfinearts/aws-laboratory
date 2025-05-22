# ECS

https://github.com/aws-containers/retail-store-sample-app/tree/main/terraform/lib

aws ecs execute-command --cluster retail-store --task TASK_ARN  --container retailStore --interactive --command "/bin/bash" --profile zero