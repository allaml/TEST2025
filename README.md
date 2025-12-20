###############################################################
#    Hoag NetApp FSx Project - Single/Multi AZ Deployment     #
###############################################################

#########################
##   Project Overview   #
#########################

This Terraform project deploys an Amazon FSx for NetApp ONTAP file system with integration to a self-managed Active Directory. The deployment supports both Single-AZ and Multi-AZ configurations. It will allow us to build CIFS shares by building logical volumes. The current code can be used to deploy additional volumes based on the business requirement.

################################
##   Deploymen Prerequisites   #
################################

- AWS CLI configured with appropriate permissions
- AWS Admin role to the deployment user
- Existing VPC and subnets based on the tags, which would be used dynamically to pull the values to deploy NetApp FSx
- Self-managed Active Directory environment already deployed in the SDDC Environment
- Active Directory credentials must be properly formatted in Secrets Manager credential store.
- Need to build the dynamodb and terraform s3 bucket running the bootstrap folder, so that we can save the terraform state file and the lock file in dynamodb table.

#################################################
##    AWS Resources for NetApp FSx Deployment   #
#################################################

- VPC with appropriate subnets including the tags in the required format.
- AWS Secrets Manager secrets for:
  - Active Directory credentials need to be saved in the AWS secrets manager. We can dynamically pull the values.
  - FSx and SVM admin credentials will be created as part of deployment. Password for SVM and FSx are kept same for operational ease.
- Will be using the existing Security Group as it is integrated with SDDC
- Route Tables (for Multi-AZ deployment)

########################################################
##   NetApp FSx Configuration Components Information   #
########################################################

1. AWS NetAPP FSx for NetApp ONTAP File System
2. Storage Virtual Machine (SVM)
3. Active Directory Integration with SVM
4. Existing Security Group configurations integrated with FSx.
5. Logical Volumes. Same deployment code can be used to add  new logical Volumes in the future.

################################
###      Deployment Types      #
################################

1. SINGLE_AZ_1: Single Availability Zone deployment
2. MULTI_AZ_1: Multi-Availability Zone deployment for high availability. Disabled few attributes howwever can be used in the future by enabling the attributes.

################################
###     Required Variables     #
################################

environment          # Environment name (e.g., prod, dev)
name_prefix         # Prefix for resource naming
deployment_type     # SINGLE_AZ_1 or MULTI_AZ_1
storage_capacity    # Storage capacity in GB
throughput_capacity # Throughput capacity
svmname            # Name for the Storage Virtual Machine
netbios_name       # NetBIOS name for AD integration
global_tags        # Map of tags to apply to all resources
Active Directory integration for authentication
Secure credential management through AWS Secrets Manager


#################################################
# Deployment Instructions using Windows Machine #
#################################################

1. Copy the admin secrets keys from AWS console and save it credential file and set the region as per the requirement
2. run the aws cli command to see if we are getting output from the right account
   Example: aws s3 ls   ( It will list all the buckets in that account)
3. terraform fmt                                          # It will format all the terraform files in the current working directory (CWD).
4. terraform validate                                     # It will provide the information if all the code is ready for deployment.
5. terrafrom plan                                         # This will give us the Information of all the resources getting created as part of the current code.
6. terraform plan -out tfsat.plan & 
   terraform show -no-color tfsat.plan > tfsatplan.txt    # It will help us to save the output file in the right format for our review and for future records
7. terraform apply -auto-approve                          # It will start building the infrastructure as per our terraplan output.

#################################################################################
#       Post-Deployment validation Steps  Single AZ / Multi-AZ File System      #
#################################################################################

1. Verify NetApp FSx file system statu
2. Validate the self managed Active Directory integration
3. Perform the ping test for the SMB share IP which we can get from the SVM endpoint tab.
4. Validate the security group rules
5. Validat the SVM configuration and all the Volumes has the right permissions.
6. Validate Resource Management & Lifecycle Management
7. Monitoring and Maintenance for NetApp FSx system metrics through CloudWatch
8. Backups and Maintenance windows validation
9. Validate all secrets are properly configured in AWS Secrets Manager.
10. Multi-AZ deployments require additional subnet and route table configurations

############################################################
#    Support and Maintenance for NetApp FSx File System    #
############################################################

1. For any storage related issues or questions, please contact: Storage Team (#StorageAdmins <StorageAdmin@hoag.org>/#IT Cloud Engineering <ITCloudEngineering@Hoag.org>) 
   via SNOW request.

2. AWS any configuration technical Issues raise a ticket with AWS Support (for FSx-related issues)

############################################################
#        Troubleshooting Common issues and solutions:      #
############################################################

1. Active Directory connectivity issues.
2. Verify DNS settings or AD credentials
3. Review resource limits
4. Performance issues, monitor throughput CloudWatch metrics
5. Review network configurations traffic using network manager/trace flow-CIFS traffic. NFS external storage, check the traffic between VPC-VPC.
6. Check storage capacity utilization and perform regular cleanups.
7. Validate the connected eni issues
8. Validate the routing Issues