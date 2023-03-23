data "aws_iam_account_alias" "current" {}

output "account_alias" {
  value = "${data.aws_iam_account_alias.current.account_alias}"
}


data "aws_iam_account_alias" "shared" {
  provider = aws.shared
}

output "shared_account_alias" {
  value = "${data.aws_iam_account_alias.shared.account_alias}"
}

data "aws_iam_account_alias" "dev" {
  provider = aws.dev
}

output "dev_account_alias" {
  value = "${data.aws_iam_account_alias.dev.account_alias}"
}

data "aws_iam_account_alias" "test" {
  provider = aws.test
}

output "test_account_alias" {
  value = "${data.aws_iam_account_alias.test.account_alias}"
}

data "aws_iam_account_alias" "prod" {
  provider = aws.prod
}

output "prod_account_alias" {
  value = "${data.aws_iam_account_alias.prod.account_alias}"
}