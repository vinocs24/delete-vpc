#!/usr/bin/env bash
touch delete_default_vpc.log
LOG_FILE=/home/ec2-user/delete_default_vpc.log

  echo `date +"%D %R"` - Removing default VPC process started. | tee -a ${LOG_FILE}
  # get list of region
  echo `date +"%D %R"` - Get list of regions. | tee -a ${LOG_FILE}
for region in $(aws ec2 describe-regions --filters "Name=endpoint,Values=*ap-south-1*" | jq -r .Regions[].RegionName); do

  echo "* Region ${region}" |tee -a ${LOG_FILE}

  # get default vpc
  echo `date +"%D %R"` - Get list of VPC. | tee -a ${LOG_FILE}    
  vpc=$(aws ec2 --region ${region} \
    describe-vpcs --filter Name=isDefault,Values=true \
    | jq -r .Vpcs[0].VpcId)
  if [ "${vpc}" = "null" ]; then
    echo "No default vpc found" | tee -a ${LOG_FILE}
    continue
  fi
  echo "Found default vpc ${vpc}" | tee -a ${LOG_FILE} 

  # get subnets
  echo `date +"%D %R"` - Deleted Subnets. | tee -a ${LOG_FILE}   
  subnets=$(aws ec2 --region ${region} \
    describe-subnets --filters Name=vpc-id,Values=${vpc} \
    | jq -r .Subnets[].SubnetId)
  if [ "${subnets}" != "null" ]; then
    for subnet in ${subnets}; do
      echo "Deleting subnet ${subnet}" | tee -a ${LOG_FILE} 
      aws ec2 --region ${region} \
        delete-subnet --subnet-id ${subnet}
    done
  fi  

  # get internet gateway
  echo `date +"%D %R"` - Deleted Internet Gateway. | tee -a ${LOG_FILE}  
  igw=$(aws ec2 --region ${region} \
    describe-internet-gateways --filter Name=attachment.vpc-id,Values=${vpc} \
    | jq -r .InternetGateways[0].InternetGatewayId)
  if [ "${igw}" != "null" ]; then
    echo "Detaching and deleting internet gateway ${igw}" | tee -a ${LOG_FILE}   
    aws ec2 --region ${region} \
      detach-internet-gateway --internet-gateway-id ${igw} --vpc-id ${vpc}
    aws ec2 --region ${region} \
      delete-internet-gateway --internet-gateway-id ${igw}
  fi
  
  # delete default vpc
  echo `date +"%D %R"` - Deleted defult VPC. | tee -a ${LOG_FILE}   
  echo "Deleted vpc ${vpc}" | tee -a ${LOG_FILE}   
  aws ec2 --region ${region} \
    delete-vpc --vpc-id ${vpc}  
done

  echo `date +"%D %R"` - Successfully deleted default VPC, Subnet and IGW. | tee -a ${LOG_FILE}

  aws s3 cp delete_default_vpc.log s3://new-test-prodbuckettestingvalidate/

  #rm -rf delete_default_vpc.log
