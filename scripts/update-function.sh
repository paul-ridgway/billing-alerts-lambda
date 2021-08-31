#!/bin/bash
set -e

export AWS_REGION=eu-west-1
cd "$( dirname "${BASH_SOURCE[0]}" )"
ZIP=../functions/notify/billing-alerts_notify.zip

if [ ! -f "$ZIP" ]; then
    echo "Creating zip"
    ./zip.sh
fi

ARN=$(aws lambda list-functions --output json --query 'Functions[].[FunctionName]' --output text | grep Billing)

if [ -z "$ARN" ]; then
    echo "No Billing function"
    exit 1
fi

echo "Updating: $ARN"
aws lambda update-function-code --function-name "$ARN" --zip-file "fileb://$ZIP" --no-paginate