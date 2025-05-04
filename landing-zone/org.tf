provider "aws" {
  region = "eu-central-1"
}


# myuser can create organization :)
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = ["cloudtrail.amazonaws.com"]
  feature_set                   = "ALL"
  enabled_policy_types          = ["SERVICE_CONTROL_POLICY"]
}

resource "aws_organizations_organizational_unit" "security_ou" {
  name = "Security"
  # reference root OU
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# warning! closed account enters suspended state for 90 days while it can be reopened
# cannot remove non-management account from org since it does not have billing set up to operate as a standalone
resource "aws_organizations_account" "security_account" {
  name      = "SecurityAccount"
  email     = "security@bob.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.security_ou.id
  # let it fail on removing account from org
  #close_on_deletion = true
}

