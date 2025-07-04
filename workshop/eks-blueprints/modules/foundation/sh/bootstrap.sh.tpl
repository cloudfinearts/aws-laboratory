#!/bin/bash

set -xo pipefail

echo "Retrieving IDE password..."

PASSWORD_SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "${passwordName}" --query 'SecretString' --output text)

export IDE_PASSWORD=$(echo "$PASSWORD_SECRET_VALUE" | jq -r '.password')

echo "Setting profile variables..."

# Set some useful variables
export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F"\"" '{print $4}')
export EC2_PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

tee /etc/profile.d/workshop.sh <<EOF
  export INSTANCE_IAM_ROLE_NAME="${instanceIamRoleName}"
  export INSTANCE_IAM_ROLE_ARN="${instanceIamRoleArn}"

  export AWS_REGION="$AWS_REGION"
  export EC2_PRIVATE_IP="$EC2_PRIVATE_IP"

  export IDE_DOMAIN="${domain}"
  export IDE_URL="https://${domain}"
  export IDE_PASSWORD="$IDE_PASSWORD"

  alias code="code-server"
EOF

source /etc/profile.d/workshop.sh

echo "Setting PS1..."

# Set PS1
tee /etc/profile.d/custom_prompt.sh <<EOF
#!/bin/sh

export PROMPT_COMMAND='export PS1="\\u:\\w:$ "'
EOF

echo "Generating SSH key..."

# Generate an SSH key for ec2-user
sudo -u ec2-user bash -c "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa -m pem <<< y"

echo "Installing AWS CLI..."

# Install AWS CLI
curl -LSsf -o /tmp/aws-cli.zip https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip
unzip -q -d /tmp /tmp/aws-cli.zip
/tmp/aws/install --update
rm -rf /tmp/aws

echo "Installing Docker..."

# Install docker and base package
dnf install -y -q docker git
service docker start
usermod -aG docker ec2-user

echo "Installing code-server..."

# Install code-server
codeServer=$(dnf list installed code-server | wc -l)
if [ "$codeServer" -eq "0" ]; then
  #sudo -u ec2-user "codeServerVersion=${codeServerVersion}" bash -c 'curl -fsSL https://github.com/coder/deploy-code-server/blob/main/deploy-vm/launch-code-server.sh | sh -s -- --version ${codeServerVersion}'
  sudo -u ec2-user "codeServerVersion=${codeServerVersion}" bash -c 'curl -fsSL https://code-server.dev/install.sh | sh -s -- --version ${codeServerVersion}'
  systemctl enable --now code-server@ec2-user
fi

sudo -u ec2-user bash -c 'mkdir -p ~/.config/code-server'
sudo -u ec2-user bash -c 'touch ~/.config/code-server/config.yaml'
tee /home/ec2-user/.config/code-server/config.yaml <<EOF
cert: false
auth: password
password: "$IDE_PASSWORD"
bind-addr: 127.0.0.1:8889
EOF

# Create default directory for workspace
sudo -u ec2-user bash -c 'mkdir -p ~/environment'

ENVIRONMENT_CONTENTS_ZIP=${environmentContentsZip}

if [ ! -z "$ENVIRONMENT_CONTENTS_ZIP" ]; then
  echo "Adding environments archive..."

  if [[ $ENVIRONMENT_CONTENTS_ZIP == s3:* ]]; then
    aws s3 cp $ENVIRONMENT_CONTENTS_ZIP /tmp/environment.zip
  else
    curl -LSsf -o /tmp/environment.zip $ENVIRONMENT_CONTENTS_ZIP
  fi

  sudo -u ec2-user bash -c 'unzip -q /tmp/environment.zip -d ~/environment'

  rm -rf /tmp/environment.zip
fi

STARTUP_EDITOR='none'

TERMINAL_ON_STARTUP="${terminalOnStartup}"
README_URL="${readmeUrl}"

if [ ! -z "$README_URL" ]; then
  echo "Adding README..."
  if [[ $README_URL == s3:* ]]; then
    aws s3 cp $README_URL /home/ec2-user/environment/README.md
  else
    curl -LSsf -o /home/ec2-user/environment/README.md $README_URL
  fi
fi

if [ "$TERMINAL_ON_STARTUP" = "true" ]; then
  STARTUP_EDITOR='terminal'
elif [ -f /home/ec2-user/environment/README.md ]; then
  STARTUP_EDITOR='readme'
fi

echo "Configuring code-server..."

sudo -u ec2-user bash -c 'mkdir -p ~/.local/share/code-server/User'
sudo -u ec2-user bash -c 'touch ~/.local/share/code-server/User/settings.json'
tee /home/ec2-user/.local/share/code-server/User/settings.json <<EOF
{
  "extensions.autoUpdate": false,
  "extensions.autoCheckUpdates": false,
  "security.workspace.trust.enabled": false,
  "workbench.startupEditor": "$STARTUP_EDITOR",
  "task.allowAutomaticTasks": "on",
  "telemetry.telemetryLevel": "off"
}
EOF

sudo -u ec2-user bash -c 'touch ~/.local/share/code-server/User/keybindings.json'
tee /home/ec2-user/.local/share/code-server/User/keybindings.json << 'EOF'
[
  {
    "key": "shift+cmd+/",
    "command": "remote.tunnel.forwardCommandPalette"
  }
]
EOF

if [ ! -z "${splashUrl}" ]; then
echo "Configuring splash URL..."

sudo -u ec2-user bash -c 'touch ~/.local/share/code-server/User/tasks.json'
tee /home/ec2-user/.local/share/code-server/User/tasks.json << 'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Open Splash",
      "command": "$${!input:openSimpleBrowser}",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    }
  ],
  "inputs": [
    {
      "id": "openSimpleBrowser",
      "type": "command",
      "command": "simpleBrowser.show",
      "args": [
        "${splashUrl}"
      ]
    }
  ]
}
EOF
fi

echo "Installing code-server extensions..."

EXTENSIONS="${extensions}"

IFS=',' read -ra array <<< "$EXTENSIONS"

# Iterate over each entry in the array
for extension in "$${!array[@]}"; do
  # Use retries as extension installation seems unreliable
  sudo -u ec2-user bash -c "set -e; (r=5;while ! code-server --install-extension $extension --force ; do ((--r))||exit;sleep 5;done)"
done

if [ ! -f "/home/ec2-user/.local/share/code-server/coder.json" ]; then
  sudo -u ec2-user bash -c 'touch ~/.local/share/code-server/coder.json'
  echo '{ "query": { "folder": "/home/ec2-user/environment" } }' > /home/ec2-user/.local/share/code-server/coder.json
fi

echo "Restarting code-server..."

systemctl restart code-server@ec2-user

echo "Installing Caddy..."

# Install caddy
dnf copr enable -y -q @caddy/caddy epel-9-x86_64
dnf install -y -q caddy
systemctl enable --now caddy

tee /etc/caddy/Caddyfile <<EOF
http://${domain} {
  handle /* {
    reverse_proxy 127.0.0.1:8889
  }
  # placeholder for another block
  #GITEA
}
EOF

echo "Restarting caddy..."

systemctl restart caddy

if [ ! -f "/home/ec2-user/.local/share/code-server/coder.json" ]; then
  sudo -u ec2-user bash -c 'touch ~/.local/share/code-server/coder.json'
  echo '{ "query": { "folder": "/home/ec2-user/environment" } }' > /home/ec2-user/.local/share/code-server/coder.json
fi

${installGitea}

echo "Running custom bootstrap script..."

${customBootstrapScript}
