#!/bin/bash
./zip.sh
aws s3 cp billing-alerts_notify.zip s3://5052/billing-alerts_notify.zip
rm -r billing-alerts_notify.zip
