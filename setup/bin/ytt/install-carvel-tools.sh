#!/bin/bash

# https://carvel.dev/ytt/docs/v0.49.x/install/#via-script-macos-or-linux
# System wide installation
wget -O- https://carvel.dev/install.sh >install.sh
sudo bash install.sh && rm install.sh
