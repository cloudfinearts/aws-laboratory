resource "aws_organizations_policy" "deny_s3_public_access" {
  name        = "DenyS3PublicAccess"
  description = "Prevent S3 Buckets from being made public"
  type        = "SERVICE_CONTROL_POLICY"
  content     = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketAcl",
        "s3:PutBucketPolicy"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": ["public-read", "public-read-write"]
        }
      }
    }
  ]
}
POLICY
}

resource "aws_organizations_policy_attachment" "attach_guardrail" {
  policy_id = aws_organizations_policy.deny_s3_public_access.id
  # attach to root OU to have applicable to all OUs
  target_id = aws_organizations_organization.main.roots[0].id
}
