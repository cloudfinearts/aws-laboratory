data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
