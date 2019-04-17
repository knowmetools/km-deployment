################################################################################
#                                Lambda Function                               #
################################################################################

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

################################################################################
#                                   Log Group                                  #
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = var.log_retention_days
}

################################################################################
#                           IAM Role and Permissions                           #
################################################################################

resource "aws_iam_role" "iam_for_lambda" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  name               = var.function_name
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               Logging Policy                               //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  policy_arn = aws_iam_policy.lambda_logging.arn
  role       = aws_iam_role.iam_for_lambda.name
}

resource "aws_iam_policy" "lambda_logging" {
  description = "Grant ${aws_lambda_function.lambda.function_name} rights to store logs in CloudWatch."
  name        = "${aws_lambda_function.lambda.function_name}-logging"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      aws_cloudwatch_log_group.lambda.arn,
      "${aws_cloudwatch_log_group.lambda.arn}:*:*"
    ]
  }
}

