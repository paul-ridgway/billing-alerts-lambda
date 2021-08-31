#!/bin/bash
cd "$( dirname "${BASH_SOURCE[0]}" )" || exit 1
rm -Rf ../functions/notify/vendor
./bundle
cd ../functions/notify || exit 1
rm -f billing-alerts_notify.zip
zip -r billing-alerts_notify.zip *