#!/usr/bin/env bash

# This script sets up a docker development environment and starts an interactive shell.

# Parse input arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c | --clear-cache)
      CLEAR_CACHE="true"
      ;;

    -d | --install-doc-tools)
      DOC_TOOLS="true"
      ;;

    -v | --version)
      ZEPHYR_VERSION="$2"
      shift
      ;;

    --host-config-dir)
      HOST_CONFIG_DIR="$2"
      shift
      ;;

    --host-zmk-dir)
      HOST_ZMK_DIR="$2"
      shift
      ;;

    --docker-config-dir)
      DOCKER_CONFIG_DIR="$2"
      shift
      ;;

    --docker-zmk-dir)
      DOCKER_ZMK_DIR="$2"
      shift
      ;;

    *)
      echo "Unknown option $1"
      exit 1
      ;;

  esac
  shift
done

# Set defaults
[[ -z $ZEPHYR_VERSION ]] && ZEPHYR_VERSION="3.5"

[[ -z $HOST_ZMK_DIR ]] && HOST_ZMK_DIR="$HOME/code/zmk"
[[ -z $HOST_CONFIG_DIR ]] && HOST_CONFIG_DIR="$HOME/code/aurora-sweep"

[[ -z $DOCKER_ZMK_DIR ]] && DOCKER_ZMK_DIR="/workspace/zmk"
[[ -z $DOCKER_CONFIG_DIR ]] && DOCKER_CONFIG_DIR="/workspace/zmk-config"

[[ -z $CLEAR_CACHE ]] && CLEAR_CACHE="false"
[[ -z $DOC_TOOLS ]] && DOC_TOOLS="false"

DOCKER_IMG="zmkfirmware/zmk-dev-arm:$ZEPHYR_VERSION"
DOCKER_CMD="$SUDO docker run --name zmk-$ZEPHYR_VERSION --rm \
    --mount type=bind,source=$HOST_ZMK_DIR,target=$DOCKER_ZMK_DIR \
    --mount type=bind,source=$HOST_CONFIG_DIR,target=$DOCKER_CONFIG_DIR \
    --mount type=volume,source=zmk-root-user-$ZEPHYR_VERSION,target=/root \
    --mount type=volume,source=zmk-zephyr-$ZEPHYR_VERSION,target=$DOCKER_ZMK_DIR/zephyr \
    --mount type=volume,source=zmk-zephyr-modules-$ZEPHYR_VERSION,target=$DOCKER_ZMK_DIR/modules \
    --mount type=volume,source=zmk-zephyr-tools-$ZEPHYR_VERSION,target=$DOCKER_ZMK_DIR/tools"

# Reset volumes
if [[ $CLEAR_CACHE = true ]]; then
  $SUDO docker volume rm $(sudo docker volume ls -q | grep "^zmk-.*-$ZEPHYR_VERSION$")
fi

# Update west if needed
OLD_WEST="/root/west.yml.old"
$DOCKER_CMD -w "$DOCKER_ZMK_DIR" "$DOCKER_IMG" /bin/bash -c " \
    if [[ ! -f .west/config ]]; then west init -l app/; fi \
    && if [[ -f $OLD_WEST ]]; then md5_old=\$(md5sum $OLD_WEST | cut -d' ' -f1); fi \
    && [[ \$md5_old != \$(md5sum app/west.yml | cut -d' ' -f1) ]] \
    && cp app/west.yml $OLD_WEST \
    && west update"

# Install docosaurus
if [[ $DOC_TOOLS = true ]]; then
  $DOCKER_CMD -w "$DOCKER_ZMK_DIR/docs" "$DOCKER_IMG" npm ci
fi

# Start interactive shell
$DOCKER_CMD -w "$DOCKER_ZMK_DIR" -it "$DOCKER_IMG" /bin/bash

# From inside of image:
# - go to /workspace/zmk/app folder
# - run `west update`
# - west build --build-dir build/aurora_sweep/left --pristine --board nice_nano_v2 -s /workspace/zmk/app -- -DSHIELD=splitkb_aurora_sweep_left -DZMK_CONFIG=/workspace/zmk-config/config/ -DZMK_EXTRA_MODULES=/workspace/zmk/zmk-helpers
# - west build --build-dir build/aurora_sweep/right --pristine --board nice_nano_v2 -s /workspace/zmk/app -- -DSHIELD=splitkb_aurora_sweep_right -DZMK_CONFIG=/workspace/zmk-config/config/ -DZMK_EXTRA_MODULES=/workspace/zmk/zmk-helpers
