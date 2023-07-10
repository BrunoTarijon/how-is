resource "aws_iam_role" "lambda_exec" {
  name = "handler-lambda"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "handler" {
  function_name = "handler"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.app.key

  runtime = "go1.x"
  handler = "main"

  source_code_hash = data.archive_file.app.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
  timeout = 10

  environment {
    variables = {
      GIN_MODE = "release"
      OPENAI_API_KEY = var.openai_api_key
    }
  }
}


resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${aws_lambda_function.handler.function_name}"

  retention_in_days = 1
}

data "archive_file" "app" {
  type        = "zip"
  source_file = "../bin/main"
  output_path = "../bin/main.zip"
}

resource "aws_s3_object" "app" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "main.zip"
  source = data.archive_file.app.output_path
  etag   = filemd5(data.archive_file.app.output_path)
}
