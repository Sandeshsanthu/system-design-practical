# --- CONFIGURATION ---
$ACCOUNT_ID = aws sts get-caller-identity --query "Account" --output text
$CLUSTER_NAME = (aws eks list-clusters --query "clusters" --output text)
$REGION = "us-east-1" # Hardcoded as requested
$POLICY_NAME = "pdf-generator-secrets-policy"
$NAMESPACE = "pdf-gen"

Write-Host "🚀 Starting Automation for Cluster: $CLUSTER_NAME" -ForegroundColor Cyan

# 1. Check for Required Tools
foreach ($tool in @("helm", "eksctl", "kubectl")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "❌ $tool is not installed. Please install it before running this script."
        exit
    }
}

# 2. Setup IAM Policy
Write-Host "Step 1: Checking IAM Policy..." -ForegroundColor Yellow
$POLICY_ARN = "arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY_NAME"
$policyExists = aws iam get-policy --policy-arn $POLICY_ARN 2>$null

if (-not $policyExists) {
    # (Same JSON logic as before...)
    $policyJson = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Action = @("secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret")
                Resource = "arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:prod/db/postgres-credentials-v*"
            },
            @{
                Effect = "Allow"
                Action = @("s3:PutObject", "s3:GetObject", "s3:ListBucket")
                Resource = @("arn:aws:s3:::pdf-generator-sandesh", "arn:aws:s3:::pdf-generator-sandesh/*")
            }
        )
    } | ConvertTo-Json -Depth 10
    $policyJson | Out-File -FilePath secrets-policy.json -Encoding ascii
    aws iam create-policy --policy-name $POLICY_NAME --policy-document file://secrets-policy.json
    Write-Host "✅ Policy Created." -ForegroundColor Green
} else {
    Write-Host "✅ Policy already exists." -ForegroundColor Green
}

# 3. Helm: Install External Secrets Operator
Write-Host "Step 2: Installing External Secrets Operator via Helm..." -ForegroundColor Yellow
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets `
    -n external-secrets-system --create-namespace --wait
Write-Host "✅ Helm Installation Complete." -ForegroundColor Green

# 4. IRSA: Link IAM to Service Account
Write-Host "Step 3: Linking IAM to Service Account (IRSA)..." -ForegroundColor Yellow
eksctl create iamserviceaccount `
    --name pdf-generator-sa `
    --namespace $NAMESPACE `
    --cluster $CLUSTER_NAME `
    --region $REGION `
    --attach-policy-arn $POLICY_ARN `
    --approve `
    --override-existing-serviceaccounts
Write-Host "✅ IRSA Linkage Complete." -ForegroundColor Green

Write-Host "`n🎉 ALL SYSTEMS GO!" -ForegroundColor Cyan
