<powershell>
Start-Transcript -Path C:\Windows\Temp\domain-join01-log.txt -Append
try {
    # Set timezone
    Set-Timezone -Id "Pacific Standard Time"
    # Fix issue where PowerShell doesn't accept input
    Install-PackageProvider NuGet -Force
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module PSReadLine -Repository PSGallery -Force

    # $instanceId = (Get-EC2InstanceMetadata -Category InstanceId).Content
    # $instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id"
    # $region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region"
    # Install required AWS PowerShell modules
    # Write-Host "Installing required AWS PowerShell modules..."
    # Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    # Set-PSRepository PSGallery -InstallationPolicy Trusted
    
	# Domain Information
    $domainName = "hoag.org"
    $NewComputerName = "${instance_name}"
    $targetOU = "OU=AWS Servers,OU=Server Resources,OU=OPERATIONS,DC=hoag,DC=org"
	
    # Get domain join credentials from Secrets Manager
    Write-Host "Getting secret from AWS secrets manager for string: hoagwinsrv-admin"
    $secret = Get-SECSecretValue -SecretId "hoagwinsrv-admin"
    $secretJson = $secret.SecretString | ConvertFrom-Json
	
    # Format the username with domain and create PSCredential object
    $userName = "hoag\$($secretJson.username)"
    Write-Host "Using username: $userName"
    $password = ConvertTo-SecureString $secretJson.password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($userName, $password)
	
    Write-Host "Starting domain join process:"
    Write-Host "Domain: $domainName"
    Write-Host "Current Computer Name: $env:COMPUTERNAME"
    Write-Host "New Computer Name: $NewComputerName"
    Write-Host "Target OU: $targetOU"
	
    # Check if already domain joined
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    if ($computerSystem.PartOfDomain) {
        Write-Host "Computer is already joined to domain: $($computerSystem.Domain)"
        exit 0
    }
    
    # To avoid RPC errors remote procedure call failed, renaming the computer first followed by domain join
    # step01: rename the computer
    Write-Host "######################################################################################################################"
    Write-Host "# Attempting to rename computer as per Hoag Standard Naming convention from: $env:COMPUTERNAME to $NewComputerName   # "
    Write-Host "######################################################################################################################"
    Rename-Computer -NewName $NewComputerName -Force -ErrorAction Stop

    #step02: Reboot computer/ec2
    Restart-Computer -Force
    Write-Host "The New Computer Name is: $NewComputerName"
    Write-Host "Computer rename successful changed. Proceeding with AD domain join"

    # step 03: join the hoag domain to the new computer/ec2
    Write-Host "Joining the EC2/computer to Hoag AD domain:$domainName in progress"
    Add-Computer -DomainName $domainName `
                -Credential $credential `
                -OUPath $targetOU `
                -Force `
                -ErrorAction Stop

    Write-Host "############################################"
    Write-Host "# Successfully joined to AD Hoag Domain.   # "
    Write-Host "############################################"

    Write-Host "Computer joined to domain: $domainName"
    Write-Host "New Computer Name: $NewComputerName"
    Set-Content -Path C:\Windows\Temp\domain-join01-success.txt -Value "Domain join completed successfully at $(Get-Date)"
   

} catch {
    $errorMessage = "AD domain joined failed at $(Get-Date): $_"
    Write-Error $errorMessage
    # Write-ToCloudWatch -Message $errorMessage -LogGroupName $logGroupName -LogStreamName $logStreamName
    Set-Content -Path C:\Windows\Temp\domain-join01-error.txt -Value $errorMessage
    throw
} finally {
    # Write-ToCloudWatch -Message "Script execution completed" -LogGroupName $logGroupName -LogStreamName $logStreamName
    Stop-Transcript
}

</powershell>

