data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  name               = var.function_name

}

resource "aws_lambda_function" "lambda" {
  filename         = var.source_archive
  function_name    = var.function_name
  handler          = var.handler
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = var.runtime
  source_code_hash = var.source_archive_hash
  timeout          = var.timeout

  environment {
    variables = var.environment_variables
  }
}

