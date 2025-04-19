#!/bin/bash

# Script to delete inbound rules from security groups that were added by the multi_sg_rule.sh script
# Region: your region

# Set AWS region
export AWS_DEFAULT_REGION= #*add region*

IP = "" #add IP

# Check if tag value is provided
if [ -z "$1" ]; then
    echo "Error: Missing tag value parameter."
    echo "Usage: ./delete_inbound_rule.sh <TAG_VALUE>"
    echo "Example: ./delete_inbound_rule.sh *speacial tag description*_*the exact date time string*" # this value is the one created from multi_sg_rules.sh
    exit 1
fi

TAG_VALUE="$1"
echo "Starting to delete inbound rules with tag: $TAG_VALUE"
echo "Source IP to remove: $IP/32"
echo "-------------------------------------------"

# Look for tracking file (optional, will work even if file is missing)
TRACKING_FILE="/home/cloudshell-user/track-files/_added_rules_${TAG_VALUE}.txt"
if [ -f "$TRACKING_FILE" ]; then
    echo "Found tracking file: $TRACKING_FILE"
    echo "Will use it to target specific security groups."
    # Extract security group IDs from tracking file (skip header lines)
    TARGETED_SGS=$(grep -v "^#" "$TRACKING_FILE" | grep -v "^---" | grep -v "^$")
else
    echo "No tracking file found at $TRACKING_FILE"
    echo "Will scan all security groups for rules with the specified tag."
    # Get all security groups if no tracking file
    TARGETED_SGS=$(aws ec2 describe-security-groups --query "SecurityGroups[*].GroupId" --output text)
fi

# Counter for modified security groups
removed_count=0
skipped_count=0

# Loop through each security group
for sg_id in $TARGETED_SGS; do
    echo "Processing security group: $sg_id"
    
    # Get all rules with the specific CIDR and protocol
    # First get the security group details
    sg_details=$(aws ec2 describe-security-groups --group-ids $sg_id)
    
    # Use jq to filter rules with our specific CIDR and check for the tag in description
    # Install jq if not already installed
    if ! command -v jq &> /dev/null; then
        echo "Installing jq for JSON processing..."
        sudo apt-get update -qq && sudo apt-get install -y -qq jq
    fi
    
    # Find rules with our CIDR and tag in description
    # First, check if the rule exists with the specific CIDR and protocol
    matching_rules=$(echo "$sg_details" | jq -r --arg cidr "$IP/32" '.SecurityGroups[0].IpPermissions[] | 
        select(.IpProtocol == "-1") | 
        select(.IpRanges != null) | 
        select(.IpRanges[] | select(.CidrIp == $cidr))')
    
    if [ -n "$matching_rules" ]; then
        # For each matching rule, check if it has a Description that is a string and contains our tag
        rule_found=false
        
        # Extract all matching rules with the specific CIDR
        all_matching_rules=$(echo "$sg_details" | jq -r --arg cidr "$IP/32" '.SecurityGroups[0].IpPermissions[] | 
            select(.IpProtocol == "-1") | 
            select(.IpRanges != null) | 
            select(.IpRanges[] | select(.CidrIp == $cidr)) | 
            .IpRanges[] | select(.CidrIp == $cidr)')
        
        # Check each rule's Description field
        while read -r rule; do
            if [ -n "$rule" ]; then
                # Extract the Description field if it exists
                description=$(echo "$rule" | jq -r 'if has("Description") and (.Description | type) == "string" then .Description else "" end')
                
                # Check if the Description contains our tag
                if [ -n "$description" ] && [[ "$description" == *"$TAG_VALUE"* ]]; then
                    # Found a rule with our tag
                    rule_found=true
                    
                    # Remove the inbound rule with the specific description
                    aws ec2 revoke-security-group-ingress \
                        --group-id $sg_id \
                        --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "$IP/32", "Description": "'"$description"'"}]}]'
                    
                    if [ $? -eq 0 ]; then
                        echo "✅ Successfully removed tagged inbound rule from security group: $sg_id"
                        removed_count=$((removed_count + 1))
                    else
                        echo "❌ Failed to remove tagged inbound rule from security group: $sg_id"
                    fi
                    
                    # We only need to remove one rule per security group
                    break
                fi
            fi
        done <<< "$(echo "$all_matching_rules" | jq -c '.')"
        
        if [ "$rule_found" = false ]; then
            echo "⏭️ No rule with tag '$TAG_VALUE' found in security group: $sg_id - Skipping"
            skipped_count=$((skipped_count + 1))
        fi
    else
        echo "⏭️ No matching rules found in security group: $sg_id - Skipping"
        skipped_count=$((skipped_count + 1))
    fi
    
    echo "-------------------------------------------"
done

echo "Summary:"
echo "Total security groups processed: $((removed_count + skipped_count))"
echo "Security groups modified (tagged rule removed): $removed_count"
echo "Security groups skipped (no tagged rule found): $skipped_count"
echo ""
echo "Removed rule details:"
echo "- Source IP: $IP/32"
echo "- Protocol: All"
echo "- Ports: All"
echo "- Tag: $TAG_VALUE"
echo ""
echo "Script completed at: $(date)"

# Clean up tracking file if it exists
if [ -f "$TRACKING_FILE" ]; then
    rm -f "$TRACKING_FILE"
    echo "Tracking file removed: $TRACKING_FILE"
fi
