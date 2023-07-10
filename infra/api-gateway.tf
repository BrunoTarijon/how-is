resource "aws_apigatewayv2_api" "howis" {
  name          = "howis"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "howis-prod" {
  api_id = aws_apigatewayv2_api.howis.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.howis-api-gw.arn

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
      }
    )
  }
}

resource "aws_cloudwatch_log_group" "howis-api-gw" {
  name = "/aws/api-gateway/${aws_apigatewayv2_api.howis.name}"

  retention_in_days = 1
}

resource "aws_apigatewayv2_integration" "howis" {
  api_id = aws_apigatewayv2_api.howis.id

  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.handler.invoke_arn
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.howis.id
  route_key = "GET /"

  target = "integrations/${aws_apigatewayv2_integration.howis.id}"
}

resource "aws_lambda_permission" "api-gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.howis.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api_mapping" "main" {
  api_id      = aws_apigatewayv2_api.howis.id
  domain_name = aws_apigatewayv2_domain_name.howis.id
  stage       = aws_apigatewayv2_stage.howis-prod.id
}
