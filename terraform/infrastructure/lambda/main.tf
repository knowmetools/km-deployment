resource "aws_iam_role" "iam_for_lambda" {
  name = var.function_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_lambda_function" "lambda" {
filename = var.source_archive
function_name = var.function_name
handler = var.handler
role = aws_iam_role.iam_for_lambda.arn
runtime = var.runtime
source_code_hash = filebase64sha256(var.source_archive)
timeout = var.timeout

environment {
variables = var.environment_variables
}
}

