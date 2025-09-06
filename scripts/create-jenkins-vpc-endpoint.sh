#!/bin/bash

# Create VPC Endpoint for API Gateway in Jenkins VPC
# This allows Jenkins to bypass WAF when accessing cap-api.testpetlabco.com

# VPC Details:
# - Jenkins VPC: vpc-00eba88dae2a58603
# - Jenkins Instance: i-0c448fe044d2c2fc1
# - Jenkins Security Group: sg-0569dcb7ee8c13701

echo "Creating VPC Endpoint for API Gateway in Jenkins VPC..."

AWS_PROFILE=labs aws ec2 create-vpc-endpoint \
  --vpc-id vpc-00eba88dae2a58603 \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.execute-api \
  --subnet-ids \
    subnet-08d8ea785c76c4b3e \
    subnet-00f8b696e968ae521 \
    subnet-0166d0e54132656c8 \
  --security-group-ids sg-0569dcb7ee8c13701 \
  --private-dns-enabled \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=jenkins-api-gateway-endpoint}]'

echo ""
echo "VPC Endpoint creation initiated!"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for DNS propagation"
echo "2. From Jenkins, test: nslookup cap-api.testpetlabco.com"
echo "   - Should return private IPs (10.x.x.x)"
echo "3. Run your API tests - they should now bypass WAF"