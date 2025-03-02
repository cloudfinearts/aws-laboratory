data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_for_lambda.name
}

resource "aws_cloudwatch_log_group" "this" {
  name              = format("/aws/lambda/%s", aws_lambda_function.this.function_name)
  retention_in_days = 7
}

// data generates archive during terraform plan in contrast to resource archive type
// data is not part of terraform state then?
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "dummy_backend.py"
  output_path = "dummy_backend.zip"
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "dummy_backend"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "dummy_backend.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  # grant permission to specific resource on AWS service
  # allow any stage and method
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
