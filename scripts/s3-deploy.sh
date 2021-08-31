#!/bin/bash
cd "$( dirname "${BASH_SOURCE[0]}" )" || exit 1
./zip.sh
aws s3 cp --acl public-read ../functions/notify/billing-alerts_notify.zip s3://5052/billing-alerts_notify.zip
rm -r ../functions/notify/billing-alerts_notify.zip
