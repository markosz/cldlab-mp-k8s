#!/bin/bash
set -e

echo "==> Executing node image entrypoint ..."

echo "-> Setting up ROS"
source "/opt/ros/$ROS_DISTRO/setup.bash"

echo "==> Container ready"
exec "$@"
