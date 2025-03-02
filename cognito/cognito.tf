# cognito can get pricey
resource "aws_cognito_user_pool" "this" {
  name = "tutorial-user-pool"

  # in console -> sign-up -> required attributes
  auto_verified_attributes = ["email"]
  # allow email for sign up
  username_attributes = ["email"]

  # sign in attributes?
  # https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-attributes.html#cognito-user-pools-standard-attributes
  # required attributes must match cognito standard attributes based on OIDC
  # these attributes are assigned to created user
  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  password_policy {
    minimum_length = 6
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Account Confirmation"
    email_message        = "Your confirmation code is {####}"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

# register app / protected resource
resource "aws_cognito_user_pool_client" "this" {
  name         = "protected-api-client"
  user_pool_id = aws_cognito_user_pool.this.id
  # allow oath 2.0 features such as callback url
  allowed_oauth_flows_user_pool_client = true
  # returns error "not_found" with no trailing slash
  callback_urls = [format("%s/", aws_apigatewayv2_stage.this.invoke_url)]
  # https://docs.aws.amazon.com/cognito/latest/developerguide/authorization-endpoint.html#get-authorize
  # implicit grant will return ID and access token appended to redirect URL, not recommended
  allowed_oauth_flows          = ["code", "implicit"]
  allowed_oauth_scopes         = ["email", "openid"]
  supported_identity_providers = ["COGNITO"]

  # hours
  access_token_validity = 3

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]
}

# enabled managed login via cognito UI for sign-up, provides authentication and authorization services
resource "aws_cognito_user_pool_domain" "this" {
  domain       = "mycryptocompany"
  user_pool_id = aws_cognito_user_pool.this.id
}
