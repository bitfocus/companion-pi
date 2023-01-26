#!/bin/bash

# cd /usr/local/src/companion

# if [ -f "UPDATE_IN_PROGRESS" ]; then
#     echo "Companion can not be started, an update operation was interrupted."
#     exit 5
# fi

# run it!
# /opt/fnm/aliases/default/bin/node headless_ip.js 0.0.0.0
/opt/companion/node-runtime/bin/node /opt/companion/main.js
