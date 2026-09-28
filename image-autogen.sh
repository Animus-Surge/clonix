#!/bin/bash

# Automation script for creating a generic base image

# TODO: parameters

# Helper to run commands and exit if failed.
run_command () {
  local cmd=$1
  local err_msg=$2
  local c_exit_code=$3

  eval $cmd
  local exitcode=$?
  if [ $exitcode -ne 0 ]; then
    echo "E: run_command: Failed to run $cmd" >&2
    echo "E: $err_msg" >&2
    exit ${c_exit_code:-$exitcode}
  fi
}

# Constants
TARGET_OPENVOX_VERSION="openvox7"
TARGET_UBUNTU_VERSION="24.04"
OPENVOX_FILE="${TARGET_OPENVOX_VERSION}-release-${TARGET_UBUNTU_VERSION}.deb"
OPENVOX_DEB_URL="https://apt.voxpupuli.org/$OPENVOX_FILE"
OPENVOX_SERVER="aspen.cs.vcu.edu"
FQDN="rams.adp.vcu.edu"
BASE_HOSTNAME="egr-u-cs-non-00.$FQDN"

# We can instead source a config file!
# . ./image_autogen.conf

hostnamectl hostname $BASE_HOSTNAME
echo "I: Hostname set to `$BASE_HOSTNAME`"

# Check if openvox is already installed
apt list --installed | grep openvox-agent > /dev/null
if [ $? -ne 0 ]; then
  # Check if we have the repo installed
  apt list --installed | grep $TARGET_OPENVOX_VERSION-release
  if [ $? -ne 0 ]; then
    echo "I: Installing openvox repo..."
    run_command "wget $OPENVOX_DEB_URL" "Failed to download openvox repo."
    run_command "apt install -y $OPENVOX_FILE" "Failed to install openvox repo."
  fi

  apt update
  run_command "apt install openvox-agent" "Failed to install openvox-agent."
  echo "S: Openvox installed successfully."
fi

# Disable openvox
systemctl disable --now openvox-agent

echo "I: Doing system updates..."

# Do system updates
apt update
apt upgrade -y

echo "I: Updating openvox config..."

# The new puppet config
echo "[main]" > /etc/puppetlabs/puppet/puppet.conf
echo "server = $OPENVOX_SERVER" >> /etc/puppetlabs/puppet/puppet.conf
echo "" >> /etc/puppetlabs/puppet/puppet.conf
echo "[agent]" >> /etc/puppetlabs/puppet/puppet.conf
echo "runtimeout = 3h" >> /etc/puppetlabs/puppet/puppet.conf

echo "I: Done."

# Optionally, add reboot flag
