$state = terraform show -json | ConvertFrom-Json
$instances = $state.values.root_module.resources | 
    Where-Object { $_.type -eq "aws_instance" }

$instances | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.address
        AMI = $_.values.ami
        InstanceType = $_.values.instance_type
        PrivateIP = $_.values.private_ip
        SubnetId = $_.values.subnet_id
        AZ = $_.values.availability_zone
    }
} | Export-Csv -Path "instance_details01.csv" -NoTypeInformation






