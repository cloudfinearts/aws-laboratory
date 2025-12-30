# not saved in state, supports write-only fields
ephemeral "random_password" "ide" {
  length = 8
}

resource "aws_secretsmanager_secret" "ide" {
  name = format("%s-secret-ide", var.project)
  # do not use scheduled deletion
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ide" {
  secret_id                = aws_secretsmanager_secret.ide.id
  secret_string_wo         = format("{\"password\": \"%s\"}", ephemeral.random_password.ide.result)
  secret_string_wo_version = 1
}

