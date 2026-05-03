resource "random_password" "db_pass" {
    length  = 20
    special = true
    override_special = "!#$%&*()-_=+[]{}<>?" 
  
}

resource "aws_secretsmanager_secret" "db_secret" {
  name        = "prod/db/postgres-credentials"
  description = "RDS Postgres credentials"
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
    secret_id     = aws_secretsmanager_secret.db_secret.id
    secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_pass.result
    dbname   = "production_db"
  })

  
}