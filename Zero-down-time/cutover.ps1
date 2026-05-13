$ErrorActionPreference = "Stop"

$env:PGPASSWORD = "SecretPassword123"
$INI_PATH = "./pgbouncer/pgbouncer.ini"

Write-Output "=== STAGE 1: Bootstrapping Infrastructure ==="
docker compose up -d
Start-Sleep -Seconds 5

Write-Output "=== STAGE 2: Setting up Logical Replication Stream ==="
# Export Schema across instances using PowerShell pipeline
docker exec -t pg_old pg_dump -U app_user -d prod_db --schema-only | docker exec -i pg_new psql -U app_user -d prod_db

# Construct Publication and Subscription using isolated single-quoted strings
$pubSql = 'CREATE PUBLICATION prod_pub FOR ALL TABLES;'
$subSql = 'CREATE SUBSCRIPTION prod_sub CONNECTION ''host=pg_old port=5432 user=app_user password=SecretPassword123 dbname=prod_db'' PUBLICATION prod_pub;'

docker exec -t pg_old psql -U app_user -d prod_db -c $pubSql
docker exec -t pg_new psql -U app_user -d prod_db -c $subSql

Write-Output "Allowing replication stream to sync (5 seconds)..."
Start-Sleep -Seconds 5

Write-Output "=== STAGE 3: Initiating PgBouncer Traffic Pause ==="
$pauseSql = 'PAUSE prod_db;'
docker exec -t pgbouncer psql -h 127.0.0.1 -p 6432 -U app_user -d pgbouncer -c $pauseSql

Write-Output "=== STAGE 4: Reconfiguring Routing Topography ==="
# Read, replace text, and write back to the INI file
(Get-Content -Path $INI_PATH) -replace 'host=pg_old', 'host=pg_new' | Set-Content -Path $INI_PATH

Write-Output "=== STAGE 5: Harmonizing Primary ID Sequences ==="
# Fetch sequence tracker position and trim whitespace
$getSeqSql = 'SELECT last_value FROM orders_id_seq;'
$SEQ_VAL = (docker exec -t pg_old psql -U app_user -d prod_db -t -c $getSeqSql).Trim()

# Sync sequence tracker position onto target node using subexpression expansion
$setSeqSql = "SELECT setval('orders_id_seq', $($SEQ_VAL), true);"
docker exec -t pg_new psql -U app_user -d prod_db -c $setSeqSql

Write-Output "=== STAGE 6: Reload and Resume Database Pipelines ==="
$reloadSql = 'RELOAD;'
$resumeSql = 'RESUME prod_db;'

docker exec -t pgbouncer psql -h 127.0.0.1 -p 6432 -U app_user -d pgbouncer -c $reloadSql
docker exec -t pgbouncer psql -h 127.0.0.1 -p 6432 -U app_user -d pgbouncer -c $resumeSql

Write-Output "=== CUTOVER COMPLETE ==="
