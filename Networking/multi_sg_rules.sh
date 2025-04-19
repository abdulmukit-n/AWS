#!/bin/bash

# Script to add inbound rule to all security groups allowing all traffic from an IP/32
# Region: A Specific region

# Set AWS region
export AWS_DEFAULT_REGION=

# Create a unique tag for this run to track which rules we added
TIMESTAMP=$(date +%Y%m%d%H%M%S)
TAG_VALUE="*speacial tag description*_${TIMESTAMP}"
IP="" # add IP !
Region="" #add region !
TRACKING_FILE="/home/cloudshell-user/track-files/_added_rules_${TIMESTAMP}.txt"

echo "Starting to add inbound rules to security groups in $Region region..."
echo "Source IP: $IP/32"
echo "Allowing: All traffic (All protocols)"
echo "Tracking Tag: $TAG_VALUE"
echo "Tracking File: $TRACKING_FILE"
echo "-------------------------------------------"

# Create tracking file header
echo "# Newly Added Rules" > $TRACKING_FILE
echo "# Created: $(date)" >> $TRACKING_FILE
echo "# Tag: $TAG_VALUE" >> $TRACKING_FILE
echo "# Format: security_group_id" >> $TRACKING_FILE
echo "-------------------------------------------" >> $TRACKING_FILE

# Get all security groups
security_groups=$(aws ec2 describe-security-groups --query "SecurityGroups[*].GroupId" --output text)

# Counter for modified security groups
modified_count=0
skipped_count=0

# Loop through each security group
for sg_id in $security_groups; do
    echo "Processing security group: $sg_id"
    
    # Check if the rule already exists
    rule_exists=$(aws ec2 describe-security-groups --group-ids $sg_id --query "SecurityGroups[*].IpPermissions[?IpRanges[?CidrIp=='$IP/32'] && FromPort==null && ToPort==null && IpProtocol=='-1']" --output text)
    
    if [ -z "$rule_exists" ]; then
        # Add the inbound rule with a description that includes our tracking tag
        # Fixed JSON formatting for IpPermissions parameter
        aws ec2 authorize-security-group-ingress \
            --group-id $sg_id \
            --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": '"$IP/32"', "Description": "newly added rules - '"$TAG_VALUE"'"}]}]'
        
        if [ $? -eq 0 ]; then
            echo "✅ Successfully added inbound rule to security group: $sg_id"
            # Add to tracking file
            echo "$sg_id" >> $TRACKING_FILE
            modified_count=$((modified_count + 1))
        else
            echo "❌ Failed to add inbound rule to security group: $sg_id"
        fi
    else
        echo "⏭️ Rule already exists in security group: $sg_id - Skipping"
        skipped_count=$((skipped_count + 1))
    fi
    
    echo "-------------------------------------------"
done

echo "Summary:"
echo "Total security groups processed: $((modified_count + skipped_count))"
echo "Security groups modified: $modified_count"
echo "Security groups skipped (rule already exists): $skipped_count"
echo ""
echo "Inbound rule details:"
echo "- Source IP: $IP/32"
echo "- Protocol: All"
echo "- Ports: All"
echo "- Description: newly added rules - $TAG_VALUE"
echo ""
echo "Tracking information:"
echo "- Tag Value: $TAG_VALUE"
echo "- Tracking File: $TRACKING_FILE"
echo ""
echo "To delete only the rules added by this script, run the delete script with:"
echo "./delete_inbound_rule.sh $TAG_VALUE"
echo ""
echo "Script completed at: $(date)"

# Print the tracking file path for reference
echo ""
echo "IMPORTANT: Save this tracking tag for deletion: $TAG_VALUE"
echo "You will need this tag to delete only the rules added by this script."
