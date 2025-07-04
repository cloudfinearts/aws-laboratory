
#!/bin/bash

set -exo pipefail

MAX_ATTEMPTS=60
WAIT_SECONDS=120
DIRECTORY=/home/ec2-user/eks-blueprints-for-terraform-workshop

env
cat ~/.bashrc

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  if [ -d "$DIRECTORY" ]; then
    echo "Directory $DIRECTORY exists. Proceeding with Git setup."
    sudo su - ec2-user -c "ls -la '$DIRECTORY'"
    if [ -f "$DIRECTORY/setup-git.sh" ]; then
      echo "Found setup-git.sh. Executing...",
      sudo su - ec2-user -c "GITOPS_DIR=/home/ec2-user/environment/gitops-repos '$DIRECTORY/setup-git.sh'"
      exit 0
    else
      echo "Error: setup-git.sh not found in $DIRECTORY"
      ls -la "$DIRECTORY"
      exit 1
    fi
  else
    echo "Attempt $i: Directory $DIRECTORY does not exist yet. Waiting..."
    sleep $WAIT_SECONDS
  fi
done
echo "Directory $DIRECTORY did not appear after $MAX_ATTEMPTS attempts. Exiting."
exit 1