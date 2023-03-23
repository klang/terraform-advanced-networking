locals {
  env = {
    default_account_alias = "iam"
    default_account_id    = "<IAMACCOUNT>"

    training_account_alias        = "training"
    training_account_id           = "<SHAREDSERVICESACCOUNT>"
    training_shared_account_alias = "shared"
    training_shared_account_id    = "<SHAREDSERVICESACCOUNT>"
    training_dev_account_alias    = "dev"
    training_dev_account_id       = "<DEVACCOUNT>"
    training_test_account_alias   = "test"
    training_test_account_id      = "<TESTACCOUNT>"
    training_prod_account_alias   = "prod"
    training_prod_account_id      = "<PRODACCOUNT>"
    
  }
  account_alias = "${lookup(local.env, "${terraform.workspace}_account_alias")}"
  account_id = "${lookup(local.env, "${terraform.workspace}_account_id")}"

  shared_account_alias = "${lookup(local.env, "${terraform.workspace}_shared_account_alias")}"
  shared_account_id = "${lookup(local.env, "${terraform.workspace}_shared_account_id")}"

  dev_account_alias = "${lookup(local.env, "${terraform.workspace}_dev_account_alias")}"
  dev_account_id = "${lookup(local.env, "${terraform.workspace}_dev_account_id")}"

  test_account_alias = "${lookup(local.env, "${terraform.workspace}_test_account_alias")}"
  test_account_id = "${lookup(local.env, "${terraform.workspace}_test_account_id")}"

  prod_account_alias = "${lookup(local.env, "${terraform.workspace}_prod_account_alias")}"
  prod_account_id = "${lookup(local.env, "${terraform.workspace}_prod_account_id")}"
}