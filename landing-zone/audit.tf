resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "aws-config-logs-${random_id.suffix.hex}"
  force_destroy = true
  tags          = { Name = "log-bucket" }
}

# ACL is obsolete, AWS creates default ACL that grants resource owner full control
# resource "aws_s3_bucket_acl" "this" {
#   bucket = aws_s3_bucket.log_bucket.id
#   acl    = "log-delivery-write"
# }

data "aws_caller_identity" "this" {
}

data "aws_region" "this" {
}

locals {
  trail = "medium-company-trail"
}

# AWS:PrincipalOrgID or AWS:PrincipalOrgPaths did not work for me
# "Condition": { 
#     "ForAnyValue:StringLike": {
#         "AWS:PrincipalOrgPaths": ["${aws_organizations_organization.main.id}/*"]
#     }
# }},

// add a statement for OR condition
// resource-based vs. identity-based policy
resource "aws_s3_bucket_policy" "config_delivery" {
  bucket = aws_s3_bucket.log_bucket.bucket
  policy = <<-EOT
    {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AWSConfigBucketPermissionsCheck",
        "Effect": "Allow",
        "Principal": {
            "Service": "config.amazonaws.com"
        },
        "Action": "s3:GetBucketAcl",
        "Resource": "${aws_s3_bucket.log_bucket.arn}",
        "Condition": { 
            "StringEquals": {
                "AWS:SourceAccount": "${data.aws_caller_identity.this.account_id}"
            }
        }},
        {
        "Sid": "AWSConfigBucketExistenceCheck",
        "Effect": "Allow",
        "Principal": {
            "Service": "config.amazonaws.com"
        },
        "Action": "s3:ListBucket",
        "Resource": "${aws_s3_bucket.log_bucket.arn}",
        "Condition": { 
            "StringEquals": {
                "AWS:SourceAccount": "${data.aws_caller_identity.this.account_id}"
            }
        }},        {
        "Sid": "AWSConfigBucketDelivery",
        "Effect": "Allow",
        "Principal": {
            "Service": "config.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource": "${aws_s3_bucket.log_bucket.arn}/AWSLogs/*",
        "Condition": { 
            "StringEquals": { 
                "s3:x-amz-acl": "bucket-owner-full-control"
            },
            "StringEquals": {
                "AWS:SourceAccount": "${data.aws_caller_identity.this.account_id}"
            }
        }},
        {
        "Sid": "AWSCloudtrailBucketPermissionsCheck",
        "Effect": "Allow",
        "Principal": {
            "Service": "cloudtrail.amazonaws.com"
        },
        "Action": "s3:GetBucketAcl",
        "Resource": "${aws_s3_bucket.log_bucket.arn}",
        "Condition": { 
            "StringEquals": {
                "AWS:SourceArn": "arn:aws:cloudtrail:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:trail/${local.trail}"
            }
        }},
        {
        "Sid": "AWSCloudtrailWrite",
        "Effect": "Allow",
        "Principal": {
            "Service": "cloudtrail.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource": "${aws_s3_bucket.log_bucket.arn}/AWSLogs/${data.aws_caller_identity.this.account_id}/*",
        "Condition": { 
            "StringEquals": {
                "s3:x-amz-acl": "bucket-owner-full-control",
                "AWS:SourceArn": "arn:aws:cloudtrail:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:trail/${local.trail}"
            }
        }},
        {
        "Sid": "AWSCloudtrailOrganizationWrite",
        "Effect": "Allow",
        "Principal": {
            "Service": "cloudtrail.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource": "${aws_s3_bucket.log_bucket.arn}/AWSLogs/${aws_organizations_organization.main.id}/*",
        "Condition": { 
            "StringEquals": {
                "s3:x-amz-acl": "bucket-owner-full-control",
                "AWS:SourceArn": "arn:aws:cloudtrail:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:trail/${local.trail}"
            }
        }}
    ]
    }
    EOT      
}

resource "aws_iam_role" "config" {
  name = "config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "config.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_attach" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "recorder" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported = true
  }
}

# starts recording config of all supported resources
resource "aws_config_delivery_channel" "channel" {
  name           = "config-channel"
  s3_bucket_name = aws_s3_bucket.log_bucket.id
  #s3_key_prefix = "prefix"
  depends_on = [aws_config_configuration_recorder.recorder, aws_s3_bucket.log_bucket]
}

resource "aws_cloudtrail" "trail" {
  name                          = local.trail
  s3_bucket_name                = aws_s3_bucket.log_bucket.id
  include_global_service_events = true
  enable_log_file_validation    = true
  is_organization_trail         = true
}

resource "aws_guardduty_detector" "main" {
  enable = true
}
