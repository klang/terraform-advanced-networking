data "aws_iam_account_alias" "current" {}

output "account_alias" {
  value = "${data.aws_iam_account_alias.current.account_alias}"
}