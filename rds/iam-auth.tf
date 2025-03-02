#========
# IAM database authentication
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.IAMPolicy.html
#=======

data "aws_caller_identity" "this" {
}

data "aws_region" "this" {
}

# assume role and generate token for PGPASSWORD, wrong user/role will get connection error on PAM authentication
# --profile will assume IAM role for the generation
# aws rds generate-db-auth-token --hostname rds-pg-labs.cpswoiwcqo4q.eu-central-1.rds.amazonaws.com 
# --region eu-central-1 --username iam_db_user --port 5432 --profile rds
data "aws_iam_policy_document" "access" {
  statement {
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [format("arn:aws:rds-db:%s:%s:dbuser:%s/iam_db_user", data.aws_region.this.name,
    data.aws_caller_identity.this.account_id, aws_db_instance.this.id)]
  }
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [format("arn:aws:iam::%s:user/zerojoe", data.aws_caller_identity.this.account_id)]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "assume" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "cli-access-rds"
}

# inline policy
resource "aws_iam_role_policy" "this" {
  policy = data.aws_iam_policy_document.access.json
  role   = aws_iam_role.assume.id
}
