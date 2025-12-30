resource "aws_cloudwatch_log_group" "ssm" {
  name = "/aws/ssm/boostrap-ide"
}

# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up-cwlogs.html
# https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html
# https://docs.aws.amazon.com/systems-manager/latest/userguide/documents-schemas-features.html#automation-doc-syntax-examples
resource "aws_ssm_document" "boostrap" {
  name            = "bootstrap-ide"
  document_type   = "Command"
  document_format = "JSON"
  # specify valid resources, empty means none
  target_type = "/AWS::EC2::Instance"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Bootstrap IDE"

    parameters = {
      # expand using {{ param }}
      BootstrapScript = {
        type        = "String"
        description = "(Optional) Custom bootstrap script to run."
        default     = ""
      }
    }

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "IdeBootstrapFunction"
        inputs = {
          runCommand = [
            templatefile("${path.module}/sh/bootstrap.sh.tpl",
              {
                passwordName           = aws_secretsmanager_secret.ide.name
                instanceIamRoleName    = aws_iam_role.shared.name
                instanceIamRoleArn     = aws_iam_role.shared.arn
                domain                 = aws_cloudfront_distribution.this.domain_name
                splashUrl              = ""
                readmeUrl              = ""
                environmentContentsZip = ""
                extensions             = ""
                terminalOnStartup      = "false"
                codeServerVersion      = "4.93.1"
                installGitea           = file("${path.module}/sh/install-gitea.sh")

                customBootstrapScript = templatefile("${path.module}/sh/custom-bootstrap.sh.tpl",
                  {
                    BUCKET_NAME = aws_s3_bucket.this.bucket
                    # create asset bucket
                    AssetsBucketName    = "ws-assets-prod-iad-r-fra-b129423e91500967"
                    AssetsBucketPrefix  = format("%s/", var.project)
                    WORKSHOP_GIT_URL    = "https://github.com/aws-samples/eks-blueprints-for-terraform-workshop"
                    WORKSHOP_GIT_BRANCH = "mainline"
                  }
                )
            }),
          ]
        }
      }
    ]
  })
}

# run ssm document on ec2
resource "aws_ssm_association" "boostrap" {
  name = aws_ssm_document.boostrap.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  depends_on = [aws_instance.this]
}

# YAML content is nicely formatted in console, JSON is squashed to a huge line
resource "aws_ssm_document" "git" {
  name            = "setup-git"
  document_type   = "Command"
  document_format = "YAML"
  target_type     = "/AWS::EC2::Instance"

  content = <<DOC
    schemaVersion: "2.2"
    description: "Setup git"
    mainSteps:
      - action: "aws:runShellScript"
        name: "SetupGitFunction"
        inputs:
          runCommand:
            - |
    ${indent(14, file("${path.module}/sh/setup-git.sh"))}
  DOC
}


resource "aws_ssm_association" "git" {
  name = aws_ssm_document.git.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  depends_on = [aws_instance.this]
}
