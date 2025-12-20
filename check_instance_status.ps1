param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId,
    
    [Parameter(Mandatory=$true)]
    [string]$Region
)

$MaxRetries = 15
$RetryInterval = 30
$Success = $false

Write-Host "Waiting for instance $InstanceId to pass all initialization and post validation status checks. please be patient"

for ($i = 1; $i -le $MaxRetries; $i++) {
    try {
        $Status = aws ec2 describe-instance-status `
            --instance-ids $InstanceId `
            --region $Region `
            --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' `
            --output text

        if ($Status -match "ok.*ok") {
            Write-Host "Instance $InstanceId has passed all status checks!"
            $Success = $true
            break
        }

        Write-Host "Attempt $($i)/$($MaxRetries): Instance not ready yet. current status is under INTIALIZING STATUS CHECK STATE Waiting $($RetryInterval) seconds..."
        Start-Sleep -Seconds $RetryInterval
    }
    catch {
        Write-Host "Error checking instance status: $($_)"
        Start-Sleep -Seconds $RetryInterval
    }
}

if (-not $Success) {
    Write-Host "Timeout waiting for instance $InstanceId to become ready"
    exit 1
}