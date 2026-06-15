# filename: create-db-dashboard-fixed.ps1
Write-Host "=== Creating Database Dashboard ===" -ForegroundColor Cyan

# Start port-forward if needed
Write-Host "Checking Grafana connection..." -ForegroundColor Yellow
$job = Get-Job | Where-Object { $_.Command -like "*grafana*" } | Select-Object -First 1
if (-not $job -or $job.State -ne "Running") {
    Start-Job -Name "GrafanaPortForward" -ScriptBlock {
        kubectl port-forward -n monitoring svc/grafana 3000:3000
    } | Out-Null
    Start-Sleep -Seconds 5
}

# Test Grafana connection
try {
    $test = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "✓ Grafana is accessible" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot connect to Grafana. Make sure it's running." -ForegroundColor Red
    exit 1
}

# Prepare credentials
$pair = "admin:admin123"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$headers = @{
    "Authorization" = "Basic $base64"
    "Content-Type" = "application/json"
}

# Create dashboard using here-string (THIS IS THE FIX!)
Write-Host "Creating dashboard..." -ForegroundColor Yellow

$body = @'
{
  "dashboard": {
    "title": "Database Performance",
    "tags": ["database"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "10s",
    "panels": [
      {
        "id": 1,
        "type": "graph",
        "title": "Query Latency (ms)",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [{"expr": "rate(write_service_db_query_duration_seconds_sum[1m]) / rate(write_service_db_query_duration_seconds_count[1m]) * 1000", "refId": "A"}],
        "yaxes": [{"format": "ms"}, {"format": "short"}]
      },
      {
        "id": 2,
        "type": "graph",
        "title": "Query Rate",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [{"expr": "rate(write_service_db_queries_total[1m])", "refId": "A"}],
        "yaxes": [{"format": "qps"}, {"format": "short"}]
      },
      {
        "id": 3,
        "type": "graph",
        "title": "DB Connections",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [{"expr": "write_service_db_connections_active", "refId": "A", "legendFormat": "Active"}, {"expr": "write_service_db_connections_idle", "refId": "B", "legendFormat": "Idle"}]
      },
      {
        "id": 4,
        "type": "graph",
        "title": "Redis Hit Rate",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [{"expr": "rate(redis_keyspace_hits_total[1m]) / (rate(redis_keyspace_hits_total[1m]) + rate(redis_keyspace_misses_total[1m])) * 100", "refId": "A"}],
        "yaxes": [{"format": "percent", "min": 0, "max": 100}, {"format": "short"}]
      }
    ]
  },
  "overwrite": true
}
'@

try {
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/dashboards/db" -Method POST -Headers $headers -Body $body

    Write-Host "✓ Dashboard created successfully!" -ForegroundColor Green
    Write-Host "`nDashboard ID: $($response.id)" -ForegroundColor White
    Write-Host "Dashboard URL: http://localhost:3000$($response.url)" -ForegroundColor Cyan

    Start-Sleep -Seconds 2
    Start-Process "http://localhost:3000$($response.url)"

} catch {
    Write-Host "✗ Failed to create dashboard" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow

    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}
