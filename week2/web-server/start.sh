#!/bin/sh

# Set up the hidden service directory and flag
mkdir -p /opt/hidden
echo "flag{p0rt_sc4nn1ng_ftw}" > /opt/hidden/flag.txt

# Start the python HTTP server on port 31337 in the background
cd /opt/hidden && python3 -m http.server 31337 &

# Start Nginx in the foreground
nginx -g 'daemon off;'
