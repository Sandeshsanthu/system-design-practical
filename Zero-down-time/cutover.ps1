$ErrorActionPreference = "Stop"

$env:PGPASSWORD = "SecretPassword123"
$INI_PATH = "./pgbouncer/pgbouncer.ini"

Write-Output "=== STAGE 1: Bootstrapping Infrastructure ==="
docker compose up -d
Start-Sleep -Seconds 5

Write-Output "=== STAGE 2: Setting up Logical Replication Stream ==="
# Injecting PGPASSWORD into both old and new containers during the pipe
docker exec -t -e PGPASSWORD=$env:PGPASSWORD pg_old pg_dump -U app_user -d prod_db --schema-only | docker exec -i -e PGPASSWORD=$env:PGPASSWORD pg_new psql -U app_user -d prod_db

# Construct Publication and Subscription
$pubSql = 'CREATE PUBLICATION prod_pub FOR ALL TABLES;'
$subSql = 'CREATE SUBSCRIPTION prod_sub CONNECTION ''host=pg_old port=5432 user=app_user password=SecretPassword123 dbname=prod_db'' PUBLICATION prod_pub;'

docker exec -t -e PGPASSWORD=$env:PGPASSWORD pg_old psql -U app_user -d prod_db -c $pubSql
docker exec -t -e PGPASSWORD=$env:PGPASSWORD pg_new psql -U app_user -d prod_db -c $subSql

Write-Output "Allowing replication stream to sync (5 seconds)..."
Start-Sleep -Seconds 5

Write-Output "=== STAGE 3: Initiating PgBouncer Traffic Pause ==="
$pauseSql = 'PAUSE prod_db;'
# Injecting PGPASSWORD into the pgbouncer container
docker exec -t -e PGPASSWORD=$env:PGPASSWORD pgbouncer psql -h 127.0.0.1 -p 6432 -U app_user -d pgbouncer -c $pauseSql

Write-Output "=== STAGE 4: Reconfiguring Routing Topography ==="
(Get-Content -Path $INI_PATH) -replace 'host=pg_old', 'host=pg_new' | Set-Content -Path $INI_PATH

Write-Output "=== STAGE 5: Harmonizing Primary ID Sequences ==="
$getSeqSql = 'SELECT last_value FROM orders_id_seq;'
$SEQ_VAL = (docker exec -t -e PGPASSWORD=$env:PGPASSWORD pg_old psql -U app_user -d prod_db -t -c $getSeqSql).Trim()

$setSeqSql = "SELECT setval('orders_id_seq', $($SEQ_VAL), true);"
docker exec -t -e PGPASSWORD=$env:PGPASSWORD pg_new psql -U app_user -d prod_db -c $setSeqSql

Write-Output "=== STAGE 6: Reload and Resume Database Pipelines ==="
$reloadSql = 'RELOAD;'
$resumeSql = 'RESUME prod_db;'

# Injecting PGPASSWORD into the pgbouncer container for reload and resume steps
docker exec -t -e PGPASSWORD=$env:PGPASSWORD pgbouncer psql -h 127.0.0.1 -p 6432 -U app_user -d pgbouncer -c $reloadSql
docker exec -t -e PGPASSWORD=$env:PGPASSWORD pgbouncer psql -h 127.0.0.1 -p 6432 -U app_user -d pgbouncer -c $resumeSql

Write-Output "=== CUTOVER COMPLETE ==="
