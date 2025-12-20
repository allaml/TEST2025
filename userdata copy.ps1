<powershell>
# Set timezone
Set-Timezone -Id "Pacific Standard Time"

# Fix issue where PowerShell doesn't accept input
Install-PackageProvider NuGet -Force
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PSReadLine -Repository PSGallery -Force
Import-Module AWSPowerShell

# Get domain join credentials from Secrets Manager
$secret = Get-SECSecretValue -SecretId "${secretid}" | Select-Object -ExpandProperty SecretString | ConvertFrom-Json

# Domain Information
$domainName = $secret.domain_name
$userName = "hoag\$($secret.username)"
$NewComputerName = "${instance_name}"
$targetOU = "${oupath}"

# Create credential object
$password = ConvertTo-SecureString $secret.password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userName, $password)

# Configure DNS with IPs from secret
$dnsIPs = $secret.dns_ips_list -split ','
$networkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
Set-DnsClientServerAddress -InterfaceIndex $networkAdapter.ifIndex -ServerAddresses $dnsIPs

# Join the domain and specify the OU
try {
    Add-Computer -DomainName $domainName -Credential $credential -NewName $NewComputerName -OUPath $targetOU -Force -Restart
    
    Write-Output "Successfully joined domain and renamed computer"
} catch {
    Write-Output "Failed to join domain or rename computer: $_"
    Set-Content -Path C:\Windows\Temp\domain-join-error.txt -Value "Domain join failed at $(Get-Date) with error: $_"
    throw $_
} 

finally {
    Stop-Transcript
}
</powershell>
