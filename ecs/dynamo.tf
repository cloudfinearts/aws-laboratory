data "aws_iam_policy_document" "dynamo" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:table/*"]
  }
}

resource "aws_iam_role_policy" "dynamo" {
  policy = data.aws_iam_policy_document.dynamo.json
  role   = aws_iam_role.task.name
  name   = "CartsDynamoDB"
}

resource "aws_dynamodb_table" "carts" {
  name         = "retail-store-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_customerId"
    hash_key        = "customerId"
    projection_type = "ALL"
  }
}
