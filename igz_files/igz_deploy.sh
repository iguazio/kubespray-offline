#!/bin/bash

# Exit on any error
set -e
. ./config.sh

BASEDIR="."
KUBESPRAY_DIR_NAME=kubespray-$KUBESPRAY_VERSION
BASEDIR=$(cd $BASEDIR; pwd)
RESET="no"
SKIP_INSTALL="no"
SCALE_OUT="no"
DEPLOYMENT_PLAYBOOK="cluster.yml"

###### Flow starts here ##########################

# Get the deploy options
for arg in "$@"
do
   if [ "$arg" == "--reset" ]; then
       echo "Reset was requested"
       RESET="yes"
   elif [ "$arg" == "--skip-k8s-install" ]; then
       echo "skip-k8s-install was requested"
       SKIP_INSTALL="yes"
   elif [ "$arg" == "--scale" ]; then
       echo "Scale out requested"
       SCALE_OUT="yes"
       DEPLOYMENT_PLAYBOOK="scale.yml"
   fi
done

# Verify deploy options
if [ "$SCALE_OUT" == "yes" ]; then
 RESET="no"
 SKIP_INSTALL="no"
fi

echo "==> Build Iguazio inventory"
python3 ./igz_inventory_builder.py "${@: -4}"

# Don't stop containers in case of scale out - it's a live data node!
if [ "$SCALE_OUT" == "yes" ]; then
  echo -e "\n# Live system flag\nlive_system: true" >> igz_override.yml
else
  echo -e "\n# Live system flag\nlive_system: false" >> igz_override.yml
fi

echo "==> Prepare inventory dir"
pushd ./"$KUBESPRAY_DIR_NAME"
cp -r inventory/sample inventory/igz
cp ../igz_offline.yml inventory/igz/group_vars/all/
cp ../igz_inventory.ini ./inventory/igz

echo "==> Copy Iguazio files"
find ../ -maxdepth 1 -type f -name 'igz_*' -exec cp '{}' . ';'

# Copy playbook for offline repo
cp -r ../playbook .

# Run igz_preinstall playbook
./igz_run_ansible.sh -i inventory/igz/igz_inventory.ini igz_pre_install.yml --become --extra-vars=@igz_override.yml

# Run offline repo playbook
./igz_run_ansible.sh -i inventory/igz/igz_inventory.ini playbook/offline-repo.yml --become --extra-vars=@igz_override.yml

# Reset Kubespray
if [[ "${RESET}" == "yes" ]]; then
  echo "==> Reset Kubernetes"
  ./igz_run_ansible.sh -i inventory/igz/igz_inventory.ini reset.yml --become --extra-vars=@igz_override.yml --extra-vars reset_confirmation=yes
  ./igz_run_ansible.sh -i inventory/igz/igz_inventory.ini igz_reset.yml --become --extra-vars=@igz_override.yml
fi

# Run kubespray
if [[ "${SKIP_INSTALL}" == "no" ]]; then
    echo "==> Install  Kubernetes"
    ./igz_run_ansible.sh -i inventory/igz/igz_inventory.ini $DEPLOYMENT_PLAYBOOK --become --extra-vars=@igz_override.yml
    ./igz_run_ansible.sh -i inventory/igz/igz_inventory.ini igz_post_install.yml --become --extra-vars=@igz_override.yml
fi

popd

echo "<=== Kubespray deployed. Happy k8s'ing ===>"
exit 0
