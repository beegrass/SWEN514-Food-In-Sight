locals {
  amplify_branch_url = "https://${var.branch_name}.${var.amplify_id}.amplifyapp.com/"
  food_api_invoke_url = "https://${aws_api_gateway_rest_api.Food-In-Sight-API.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod"
  user_api_invoke_url = "https://${aws_api_gateway_rest_api.food_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod/"
}

resource "aws_cognito_user_pool" "food-in-sight-user-pool" {
  name = "food-in-sight-user-pool"

  alias_attributes = ["email"]
  auto_verified_attributes = ["email"]

  schema {
    name     = "email"
    required = true
    attribute_data_type = "String"

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }
}

resource "aws_cognito_user_pool_client" "food-in-sight-user-pool-client" {
  name            = "food-in-sight-client"
  user_pool_id    = aws_cognito_user_pool.food-in-sight-user-pool.id
  generate_secret = false

  # Callback URLs for redirection
  callback_urls = [local.amplify_branch_url]
  logout_urls   = [local.amplify_branch_url]
}

resource "aws_cognito_identity_pool" "food-in-sight-identity-pool" {
  identity_pool_name               = "food-in-sight-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.food-in-sight-user-pool-client.id
    provider_name = "cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.food-in-sight-user-pool.id}"
  }
}

resource "aws_amplify_branch" "main" {
  app_id            = var.amplify_id # Manually setting the app_id to match the existing deployed amplify app
  branch_name       = var.branch_name
  enable_auto_build = true

  environment_variables = {
    VITE_USER_DIET_API_GATEWAY_URL  = local.user_api_invoke_url
    VITE_API_GATEWAY_URL            = local.food_api_invoke_url
    VITE_COGNITO_USERPOOL_ID        = aws_cognito_user_pool.food-in-sight-user-pool.id
    VITE_COGNITO_USERPOOL_CLIENT_ID = aws_cognito_user_pool_client.food-in-sight-user-pool-client.id
    VITE_COGNITO_IDENTITY_POOL_ID   = aws_cognito_identity_pool.food-in-sight-identity-pool.id
  }

  depends_on = [
    aws_cognito_user_pool.food-in-sight-user-pool,
    aws_cognito_user_pool_client.food-in-sight-user-pool-client,
    aws_cognito_identity_pool.food-in-sight-identity-pool
  ]
}

output "amplify_branch_url" {
  value = local.amplify_branch_url
}
