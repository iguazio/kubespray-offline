#!/bin/bash

# Exit on any error
set -e
# Override configs to avoid replacing the script multiple times
cat ./igz_config.sh > ./config.sh && . ./config.sh

BASEDIR="."
FILES_DIR=./files
KUBESPRAY_DIR_NAME=kubespray-$KUBESPRAY_VERSION
BASEDIR=$(cd $BASEDIR; pwd)
NGINX_IMAGE=iguazio/nginx_server:latest
RESET="no"
SKIP_INSTALL="no"
LOCAL_REGISTRY=${LOCAL_REGISTRY:-"localhost:${REGISTRY_PORT}"}

# Helper functions ######################
select_latest() {
    local latest=$(ls $* | tail -1)
    if [ -z "$latest" ]; then
        echo "No such file: $*"
        exit 1
    fi
    echo $latest
}

load_images() {
    for image in $BASEDIR/images/*.tar.gz; do
        echo "===> Loading $image"
        sudo $NERDCTL load -i $image
    done
}

push_images() {
    images=$(cat $BASEDIR/images/*.list)
    for image in $images; do

        # Removes specific repo parts from each image for kubespray
        newImage=$image
        for repo in registry.k8s.io k8s.gcr.io gcr.io docker.io quay.io; do
            newImage=$(echo ${newImage} | sed s@^${repo}/@@)
        done

        newImage=${LOCAL_REGISTRY}/${newImage}

        echo "===> Tag ${image} -> ${newImage}"
        sudo $NERDCTL tag ${image} ${newImage}

        echo "===> Push ${newImage}"
        sudo $NERDCTL push ${newImage}
    done
}

###### Flow starts here ##########################

# Create YUM repo and file server that will be exposed with nginx
./setup-offline.sh
./setup-py.sh

# Get the deploy options
for arg in "$@"
do
    if [ "$arg" == "--reset" ]; then
        echo "Reset was requested"
        RESET="yes"
    elif [ "$arg" == "--skip-k8s-install" ]; then
        echo "skip-k8s-install was requested"
        SKIP_INSTALL="yes"
    fi
done

# Check if registry is running and bring it up if not
REGISRTY_RUNNNG=$(docker ps --quiet --filter name=docker_registry)
if [[ -n ${REGISRTY_RUNNNG} ]]; then
  echo "Registry is already running"
else
  # Dirty hack - if only I could use Ansible everywhere
  source <(grep -v '^\s*\[.*\]\s*$' /etc/ansible/facts.d/registry.fact)
  echo "ALEXP - $platform_dir"
  pushd $platform_dir/manof
  /usr/local/bin/manof run docker_registry --node-name $system_node_name --data-dir $docker_registry_path --storage-filesystem-maxthreads $registry_fs_maxthreads
  popd
fi


# Not needed?
#/usr/bin/docker rm -f nginx || true

# Start nginx
echo "===> Start nginx"
/usr/bin/docker run -d \
    --network host \
    --restart always \
    --name nginx \
    -v ${BASEDIR}:/usr/share/nginx/html \
    ${NGINX_IMAGE}

# Install cni plugins
echo "==> Install CNI plugins"
mkdir -p /opt/cni/bin
tar xvzf $(select_latest "${FILES_DIR}/kubernetes/cni/cni-plugins-linux-amd64-v*.tgz") -C /opt/cni/bin

# TODO Move to Ansible and upload on all data nodes
load_images
push_images

# Extract kubespray
./extract-kubespray.sh
chown -R iguazio:iguazio $KUBESPRAY_DIR_NAME

# Create and activate a venv
/opt/rh/rh-python38/root/usr/bin/python -m venv venv/default
source venv/default/bin/activate

# Install pip and requirements
pip install -U pip
pip install -r $KUBESPRAY_DIR_NAME/requirements.txt

# Create inventory and copy Iguazio files
python3 ./igz_inventory_builder.py "${@: -3}"

pushd ./$KUBESPRAY_DIR_NAME
cp -r inventory/sample inventory/igz
# Copy and rename file in one line
cat ../igz_offline.yml > inventory/igz/group_vars/all/offline.yml
cp ../igz_override.yml .
cp ../igz_inventory.ini ./inventory/igz
cp ../igz_hosts.toml.j2 .
cp ../config.toml.patch .
cp ../igz_reset.yml .
cp ../igz_post_install.yml .

# Copy playbook for offline repo
cp -r ../playbook .

# Run offline repo playbook
ansible-playbook -i inventory/igz/igz_inventory.ini playbook/offline-repo.yml --become --extra-vars=@igz_override.yml

# Reset Kubespray
if [[ "${RESET}" == "yes" ]]; then
  ansible-playbook -i inventory/igz/igz_inventory.ini reset.yml --become --extra-vars=@igz_override.yml --extra-vars reset_confirmation=yes
  ansible-playbook -i inventory/igz/igz_inventory.ini igz_reset.yml --become --extra-vars=@igz_override.yml
fi

# Run kubespray
if [[ "${SKIP_INSTALL}" == "no" ]]; then
    ansible-playbook -i inventory/igz/igz_inventory.ini cluster.yml --become --extra-vars=@igz_override.yml
    ansible-playbook -i inventory/igz/igz_inventory.ini igz_post_install.yml --become --extra-vars=@igz_override.yml
fi

popd

echo "<=== Kubespray deployed. Happy k8s'ing ===>"
exit 0
