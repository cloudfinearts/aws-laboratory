provider "aws" {
  region = "eu-central-1"
}

data "aws_organizations_organization" "current" {
}

data "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

data "aws_organizations_organizational_unit_child_accounts" "security" {
  parent_id = data.aws_organizations_organizational_unit.security.id
}

locals {
  account_ids = [for account in data.aws_organizations_organizational_unit_child_accounts.security.accounts : account.id if account.name == "SecurityAccount"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    # this role is created automatically in member accounts
    resources = ["arn:aws:iam::${local.account_ids[0]}:role/OrganizationAccountAccessRole"]
  }
}

resource "aws_iam_policy" "this" {
  policy = data.aws_iam_policy_document.trust.json
  name   = "SwitchRoleSecurityAccount"
}

data "aws_iam_user" "this" {
  user_name = "myuser"
}

# Switch role from top right menu as myuser to access another member account
resource "aws_iam_user_policy_attachment" "this" {
  policy_arn = aws_iam_policy.this.arn
  user       = data.aws_iam_user.this.user_name
}
