# https://harsh05.medium.com/enhancing-api-security-with-aws-cognito-a-hands-on-tutorial-3b533c9ea230

provider "aws" {
  region = "eu-central-1"
}

resource "aws_apigatewayv2_api" "this" {
  name          = "cognito-integration"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "this" {
  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.this.invoke_arn
  integration_method = "POST"
}

// create endpoint authorizer
resource "aws_apigatewayv2_authorizer" "this" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  name             = "authorizer"
  identity_sources = ["$request.header.Token"]

  jwt_configuration {
    # clientID, intended audience for JWT is verified
    audience = [aws_cognito_user_pool_client.this.id]
    issuer   = format("https://%s", aws_cognito_user_pool.this.endpoint)
  }
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /"
  target    = format("integrations/%s", aws_apigatewayv2_integration.this.id)

  # lock down endpoint for only authorized requests, e.g. DynamoDB is not able to restrict access
  # 401 unauthorized without Bearer token
  authorizer_id        = aws_apigatewayv2_authorizer.this.id
  authorization_scopes = ["email"]
  authorization_type   = "JWT"
}

resource "aws_iam_role" "api_gateway_cloudwatch_logs" {
  name = "api-gateway-cloudwatch-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api" {
  role       = aws_iam_role.api_gateway_cloudwatch_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# account's setting
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_logs.arn
}

resource "aws_cloudwatch_log_group" "api" {
  name              = format("/aws/api-gw/%s", aws_apigatewayv2_api.this.name)
  retention_in_days = 7
}

# deploy api to get invoke url
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "dev"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

output "config" {
  value = {
    stage_url = aws_apigatewayv2_stage.this.invoke_url
  }
}


