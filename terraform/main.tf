provider "aws" {
  region = "us-west-2"
}

# LAMBDA FUNCTIONS

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    },
    {
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "states.amazonaws.com" 
      }
    }]
  })

  inline_policy {
    name = "lambda-dynamodb-access"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action   = "lambda:InvokeFunction",
          Effect   = "Allow",
          Resource = [
            "arn:aws:lambda:us-west-2:208440538069:function:validate_user" ,
            "arn:aws:lambda:us-west-2:208440538069:function:execute_payments",
            "arn:aws:lambda:us-west-2:208440538069:function:register_activity"  # Add the register_activity function ARN
          ]
        },
        {
          Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "step_function_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSStepFunctionsFullAccess"
}

resource "aws_lambda_function" "validate_user" {
  function_name = "validate_user"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "dist/main.handler"
  runtime       = "nodejs18.x"

  source_code_hash = filebase64sha256("../lambda/validate_user.zip")
  filename         = "../lambda/validate_user.zip"

  environment {
    variables = {
      USERS_TABLE = aws_dynamodb_table.users.name
    }
  }
}

resource "aws_lambda_function" "execute_payments" {
  function_name = "execute_payments"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "dist/main.handler"
  runtime       = "nodejs18.x"

  source_code_hash = filebase64sha256("../lambda/execute_payments.zip")
  filename         = "../lambda/execute_payments.zip"

  environment {
    variables = {
      TRANSACTIONS_TABLE = aws_dynamodb_table.transactions.name
      MOCK_API_URL = "${aws_api_gateway_deployment.mock_payment_deployment.invoke_url}/payment"
    }
  }
}

resource "aws_lambda_function" "register_activity" {
  function_name = "register_activity"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "dist/main.handler"
  runtime       = "nodejs18.x"

  source_code_hash = filebase64sha256("../lambda/register_activity.zip")
  filename         = "../lambda/register_activity.zip"

  environment {
    variables = {
      ACTIVITY_TABLE = aws_dynamodb_table.activity.name
    }
  }

  depends_on = [aws_dynamodb_table.transactions]
}

resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn = aws_dynamodb_table.transactions.stream_arn
  function_name    = aws_lambda_function.register_activity.function_name
  starting_position = "LATEST"
}

# MOCK API

resource "aws_lambda_function" "mock_payment" {
  function_name = "mock_payment"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "dist/main.handler"
  runtime       = "nodejs18.x"

  source_code_hash = filebase64sha256("../lambda/mock_payment.zip")
  filename         = "../lambda/mock_payment.zip"
  environment {
    variables = {
      MOCK_API_MESSAGE = "This is a mock payment response"
    }
  }
}

resource "aws_api_gateway_rest_api" "mock_payment_api" {
  name        = "MockPaymentAPI"
  description = "Mock API for Payment Processing"
}

resource "aws_api_gateway_rest_api_policy" "mock_payment_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.mock_payment_api.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Principal: "*",
        Action: "execute-api:Invoke",
        Resource = [
          "${aws_api_gateway_rest_api.mock_payment_api.execution_arn}/*/POST/payment"
        ]
      }
    ]
  })
}

resource "aws_api_gateway_resource" "mock_payment_resource" {
  rest_api_id = aws_api_gateway_rest_api.mock_payment_api.id
  parent_id   = aws_api_gateway_rest_api.mock_payment_api.root_resource_id
  path_part   = "payment"
}

resource "aws_api_gateway_method" "mock_payment_post" {
  rest_api_id   = aws_api_gateway_rest_api.mock_payment_api.id
  resource_id   = aws_api_gateway_resource.mock_payment_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mock_payment_integration" {
  rest_api_id             = aws_api_gateway_rest_api.mock_payment_api.id
  resource_id             = aws_api_gateway_resource.mock_payment_resource.id
  http_method             = aws_api_gateway_method.mock_payment_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.mock_payment.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_mock_payment" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mock_payment.function_name
  principal     = "apigateway.amazonaws.com"
  //source_arn    = "arn:aws:execute-api:us-west-2:208440538069:plgp479xf5/prod/POST/payment"
  source_arn    = "${aws_api_gateway_rest_api.mock_payment_api.execution_arn}/*/POST/payment"
}

resource "aws_api_gateway_deployment" "mock_payment_deployment" {
  rest_api_id = aws_api_gateway_rest_api.mock_payment_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.mock_payment_api.body))
  }
  lifecycle {
    create_before_destroy = true
  }
  stage_name  = "prod"
  depends_on = [aws_api_gateway_method.mock_payment_post, aws_api_gateway_integration.mock_payment_integration]
}

resource "aws_api_gateway_stage" "mock_payment_stage" {
  deployment_id = aws_api_gateway_deployment.mock_payment_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.mock_payment_api.id
  stage_name = "dev"
}
output "mock_api_url" {
  value = "${aws_api_gateway_deployment.mock_payment_deployment.invoke_url}/payment"
}


# API GATEWAY

resource "aws_api_gateway_rest_api" "payment_api" {
  name        = "PaymentAPI"
  description = "API for Payment Processing"
}

# Define the first path segment: /v1
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.payment_api.id
  parent_id   = aws_api_gateway_rest_api.payment_api.root_resource_id
  path_part   = "v1"
}

# Define the second path segment: /v1/payments
resource "aws_api_gateway_resource" "payments" {
  rest_api_id = aws_api_gateway_rest_api.payment_api.id
  parent_id   = aws_api_gateway_resource.v1.id  # Set the parent to the /v1 resource
  path_part   = "payments"
}

# Define the POST method for /v1/payments
resource "aws_api_gateway_method" "payment_method" {
  rest_api_id   = aws_api_gateway_rest_api.payment_api.id
  resource_id   = aws_api_gateway_resource.payments.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integrate the POST method with the Lambda function
resource "aws_api_gateway_integration" "payment_integration" {
  rest_api_id             = aws_api_gateway_rest_api.payment_api.id
  resource_id             = aws_api_gateway_resource.payments.id
  http_method             = aws_api_gateway_method.payment_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.validate_user.invoke_arn
}

resource "aws_api_gateway_integration" "post_payments_integration" {
  rest_api_id             = aws_api_gateway_rest_api.payments_api.id
  resource_id             = aws_api_gateway_resource.payments_path.id
  http_method             = aws_api_gateway_method.post_payments.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.start_step_function.invoke_arn
}

resource "aws_api_gateway_deployment" "payment_deployment" {
  rest_api_id = aws_api_gateway_rest_api.payment_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.payment_api.body))
  }
  lifecycle {
    create_before_destroy = true
  }
  stage_name  = "prod"
  depends_on = [aws_api_gateway_method.payment_method, aws_api_gateway_integration.payment_integration]
}

resource "aws_lambda_permission" "apigw_lambda_validate_user" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validate_user.function_name
  principal     = "apigateway.amazonaws.com"
  //source_arn    = "arn:aws:execute-api:us-west-2:208440538069:14h1uy2dc4/prod/POST/v1/payments"
  source_arn    = "${aws_api_gateway_rest_api.payment_api.execution_arn}/*/POST/v1/payments"
}

resource "aws_api_gateway_stage" "payment_stage" {
  deployment_id = aws_api_gateway_deployment.payment_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.payment_api.id
  stage_name = "dev"
}

output "payment_api_url" {
  value = "${aws_api_gateway_deployment.payment_deployment.invoke_url}/v1/payments"
}
output "url_payment_api" {
  value = "${aws_api_gateway_rest_api.payment_api.execution_arn}/*/POST/v1/payments"
}
output "MockPaymentAPI" {
  value = "${aws_api_gateway_rest_api.mock_payment_api.execution_arn}/*/POST/payment"
}



# DYNAMODB

resource "aws_dynamodb_table" "users" {
  name           = "users"
  hash_key       = "user_id"  
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "user_id" 
    type = "S"
  }

   attribute {
    name = "name" 
    type = "S"
  }

   attribute {
    name = "last_name" 
    type = "S"
  }

  global_secondary_index {
    name            = "NameIndex"
    hash_key        = "name"
    projection_type = "ALL"
    read_capacity   = 5
    write_capacity  = 5
  }

  global_secondary_index {
    name            = "LastNameIndex"
    hash_key        = "last_name"
    projection_type = "ALL"
    read_capacity   = 5
    write_capacity  = 5
  }
}

resource "aws_dynamodb_table" "transactions" {
  name           = "transactions"
  hash_key       = "transaction_id"
  billing_mode   = "PAY_PER_REQUEST"
  stream_enabled = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

   global_secondary_index {
    name               = "UserIdIndex"
    hash_key           = "userId"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

}

resource "aws_dynamodb_table" "activity" {
  name           = "activity"
  hash_key       = "activity_id"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "activity_id"
    type = "S"
  }

  attribute {
    name = "transaction_id"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  global_secondary_index {
    name               = "TransactionIndex"
    hash_key           = "transaction_id"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

  global_secondary_index {
    name               = "DateIndex"
    hash_key           = "date"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }
}

resource "aws_dynamodb_table_item" "preload_users" {
  table_name = aws_dynamodb_table.users.name
  hash_key = "user_id"
  
  item = <<ITEM
{
  "user_id": {"S": "f529177d-0521-414e-acd9-6ac840549e97"},
  "name": {"S": "Pedro"},
  "last_name": {"S": "Suarez"}
}
ITEM
}

resource "aws_dynamodb_table_item" "preload_users_2" {
  table_name = aws_dynamodb_table.users.name
  hash_key = "user_id"
  
  item = <<ITEM
{
  "user_id": {"S": "15f1c60a-2833-49b7-8660-065b58be2f89"},
  "name": {"S": "Andrea"},
  "last_name": {"S": "Vargas"}
}
ITEM
}

# STEP FUNCTION

resource "aws_sfn_state_machine" "payment_processing" {
  name     = "PaymentProcessingStateMachine"
  role_arn = aws_iam_role.lambda_execution_role.arn

  definition = jsonencode({
      StartAt = "ValidateUser",
      States = {
        ValidateUser = {
          Type       = "Task",
          Resource   = "${aws_lambda_function.validate_user.arn}",
          Next       = "ExecutePayments",
          ResultPath = "$.userValidationResult"
        },
        ExecutePayments = {
          Type       = "Task",
          Resource   = "${aws_lambda_function.execute_payments.arn}",
          ResultPath = "$.paymentResult",
          End        =  true
        }
      }
  })
}


