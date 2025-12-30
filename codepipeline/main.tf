provider "aws" {
  region = "eu-central-1"
}

# codecommit is deprecated and works only for existing repos
# resource "aws_codecommit_repository" "store" {
#   repository_name = "retail-store"
# }

# replaces null_resource 
resource "terraform_data" "init_repo" {
  provisioner "local-exec" {
    command = templatefile("${path.module}/init-repo.sh.tpl", {
      ROOT_DIR = "${path.module}/temp/"
      REPO_URL = "https://gitlab.com/cheeky-bob/aws-workshop-retail-store.git"
    })
  }
}

resource "aws_ecr_repository" "ui" {
  name                 = "retail-store-ui"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ssm_parameter" "image" {
  name  = "/codebuild/retail-store-ui-image"
  type  = "String"
  value = "latest"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_codebuild_project" "ui" {
  name         = "retail-store-ui"
  service_role = aws_iam_role.build.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "ECR_URI"
      value = aws_ecr_repository.ui.repository_url
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest-amd64"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  source_version = "refs/heads/main"

  depends_on = [terraform_data.init_repo]
}

resource "random_id" "pipeline" {
  byte_length = 4
}

resource "aws_s3_bucket" "pipeline" {
  bucket        = "retail-store-pipeline-${random_id.pipeline.hex}"
  force_destroy = true
}

# connection created in pending state, go to  CodePipeline, Settings -> Connections, sign in to the repo via OAuth
# codeconnections seems to be new name for codestart connection
resource "aws_codeconnections_connection" "gitlab" {
  name          = "gitlab-connection"
  provider_type = "GitLab"
}

resource "aws_codepipeline" "store" {
  name     = "retail-store-sample-app"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      version  = "1"
      # name output of this stage, saved in the bucket
      output_artifacts = ["source"]

      provider = "CodeStarSourceConnection"
      configuration = {
        ConnectionArn    = aws_codeconnections_connection.gitlab.arn
        FullRepositoryId = "cheeky-bob/aws-workshop-retail-store"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "build_ui"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["build_artifact"]
      # run_order        = 1

      # run codebuild project
      configuration = {
        ProjectName = aws_codebuild_project.ui.name
      }
    }
  }

  # missing deploy section, got removed from AWS workshop meanwhile :)
  depends_on = [aws_codebuild_project.ui]
}

