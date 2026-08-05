# filename: db-init-job.tf

# ---------------------------------------------------------------
# ConfigMap — Python init script, no credentials inside
# ---------------------------------------------------------------
resource "kubernetes_config_map" "db_init_script" {
  metadata {
    name      = "db-init-script"
    namespace = "default"
  }

  data = {
    "init_db.py" = <<-PYTHON
      import boto3, json, psycopg2, sys, os

      REGION      = os.environ["AWS_REGION"]
      SECRET_NAME = os.environ["SECRET_NAME"]
      DB_HOST     = os.environ["DB_HOST"]
      DB_PORT     = int(os.environ.get("DB_PORT", "5432"))

      DATABASES = [
        "gateway_db",
        "customer_db",
        "payment_db",
        "fraud_db",
        "bank_connector_db",
        "ledger_db",
        "notification_db",
      ]
      APP_ROLE = "payments"

      print(f"[1/4] Fetching credentials from Secrets Manager: {SECRET_NAME}")
      client = boto3.client("secretsmanager", region_name=REGION)
      secret = json.loads(
          client.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
      )
      db_user = secret["username"]
      db_pass = secret["password"]
      print(f"      Connected as: {db_user}")

      # Connect to default postgres db to run CREATE DATABASE
      conn = psycopg2.connect(
          host=DB_HOST, port=DB_PORT,
          dbname="postgres",
          user=db_user, password=db_pass,
          sslmode="require", connect_timeout=15
      )
      conn.autocommit = True   # required for CREATE DATABASE
      cur = conn.cursor()

      print("[2/4] Creating role 'payments' if not exists...")
      cur.execute(f"""
          DO $$
          BEGIN
            IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{APP_ROLE}') THEN
              CREATE ROLE {APP_ROLE} LOGIN PASSWORD '{db_pass}';
            END IF;
          END
          $$;
      """)
      print(f"      Role '{APP_ROLE}' ready")

      print("[3/4] Creating databases...")
      for db in DATABASES:
          cur.execute(f"SELECT 1 FROM pg_database WHERE datname = '{db}'")
          if cur.fetchone():
              print(f"      SKIP  {db} (already exists)")
          else:
              cur.execute(f"CREATE DATABASE {db}")
              print(f"      CREATE {db}")

      print("[4/4] Granting privileges...")
      for db in DATABASES:
          cur.execute(f"GRANT ALL PRIVILEGES ON DATABASE {db} TO {APP_ROLE}")
          print(f"      GRANT {db} → {APP_ROLE}")

      cur.close()
      conn.close()

      print("\n✅  DB init complete — all databases created and grants applied")
      sys.exit(0)
    PYTHON
  }

  depends_on = [aws_db_instance.postgres]
}

# ---------------------------------------------------------------
# Job — runs once, credentials fetched from cloud at runtime
# ---------------------------------------------------------------
resource "kubernetes_job" "db_init" {
  metadata {
    name      = "db-init-job"
    namespace = "default"
    labels = {
      app = "db-init"
    }
  }

  spec {
    # Never restart on failure — force explicit re-run if needed
    backoff_limit = 2

    template {
      metadata {
        labels = {
          app = "db-init"
        }
      }

      spec {
        service_account_name = "payment-api-sa"   # IRSA — cloud creds only
        restart_policy       = "Never"

        container {
          name    = "db-init"
          image   = "python:3.11-slim"

          command = ["/bin/sh", "-c"]
          args    = ["pip install --quiet boto3 psycopg2-binary && python /scripts/init_db.py"]

          # Zero credentials here — all resolved at runtime via IRSA
          env {
            name  = "SECRET_NAME"
            value = aws_secretsmanager_secret.db_secret.name
          }
          env {
            name  = "DB_HOST"
            value = aws_db_instance.postgres.address
          }
          env {
            name  = "DB_PORT"
            value = tostring(aws_db_instance.postgres.port)
          }
          env {
            name  = "AWS_REGION"
            value = "us-east-2"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "script-volume"
            mount_path = "/scripts"
          }
        }

        volume {
          name = "script-volume"
          config_map {
            name = kubernetes_config_map.db_init_script.metadata[0].name
          }
        }
      }
    }
  }

  # Block terraform apply until Job completes successfully
  wait_for_completion = true

  timeouts {
    create = "5m"
    update = "5m"
  }

  depends_on = [
    aws_db_instance.postgres,
    aws_secretsmanager_secret_version.db_secret_val,
    kubernetes_config_map.db_init_script,
  ]
}

