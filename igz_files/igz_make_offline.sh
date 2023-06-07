#!/bin/bash

# Exit on any error
set -e
. config.sh

CURRENT_DIR=$(pwd)
KUBESPRAY_DIR=./cache/kubespray-${KUBESPRAY_VERSION}
PATCH_DIR=${CURRENT_DIR}/target-scripts/patches/${KUBESPRAY_VERSION}

# Get some basic stuff
./precheck.sh
./prepare-pkgs.sh
./prepare-py.sh
./get-kubespray.sh
./pypi-mirror.sh

# We need to break the flow to set kube_version and apply the required patches

if [[ ! -d "${PATCH_DIR}" ]]; then
  mkdir -p ${PATCH_DIR}
fi

if [[ ! -d "./igz_patches/${KUBESPRAY_VERSION}" ]]; then
  cp  ./igz_patches/${KUBESPRAY_VERSION}/* $PATCH_DIR/
else
  echo "[WARNING]: No patches provided for the current release ${KUBESPRAY_VERSION}!"
fi

 Check pathes dir
for file in "$PATCH_DIR"/*; do
  if [[ -f "$file" && "${file##*.}" != "patch" ]]; then
    echo "File $file does not have a .patch extension. Exiting."
    exit 1
  else echo "Found patch file $file"
  fi
done

# Apply all patches
for patch in ${PATCH_DIR}/*.patch; do
  echo "===> Apply patch $patch"
  (cd $KUBESPRAY_DIR && patch --force --verbose -p1 < $patch) || exit 1
done

# Continue with the flow
./download-kubespray-files.sh
./create-repo.sh
./copy-target-scripts.sh
./download-additional-containers.sh

echo "<=== Fetching Iguazio scripts ===>"

# Copy Iguazio files
find . -type f -name "igz_*" -exec cp {} /outputs/ \;

# This does not fall under any category
cp ./igz_patches/nvidia/config.toml.patch /outputs

chown -R 1000:1000 /outputs

echo "<=== Kubespray $KUBESPRAY_VERSION is ready for offline deployment ===>"
exit 0
