#!/bin/bash

# Exit on any error
set -e
. ./config.sh

BASEDIR="."
FILES_DIR=./files
KUBESPRAY_DIR_NAME=kubespray-$KUBESPRAY_VERSION
BASEDIR=$(cd $BASEDIR; pwd)
NGINX_IMAGE=nginx:1.23

select_latest() {
    local latest=$(ls $* | tail -1)
    if [ -z "$latest" ]; then
        echo "No such file: $*"
        exit 1
    fi
    echo $latest
}

/usr/bin/docker rm -f nginx || true

# Deploy nginx and registry, push images to registry
echo "===> Start nginx"
/usr/bin/docker run -d \
    --network host \
    --restart always \
    --name nginx \
    -v ${BASEDIR}:/usr/share/nginx/html \
    ${NGINX_IMAGE}

./setup-offline.sh
./setup-py.sh

# Install cni plugins
echo "==> Install CNI plugins"
mkdir -p /opt/cni/bin
tar xvzf $(select_latest "${FILES_DIR}/kubernetes/cni/cni-plugins-linux-amd64-v*.tgz") -C /opt/cni/bin

echo "==> Load registry, nginx images"
NERDCTL=/usr/bin/docker
pushd ./images
echo "Pushing images to registry..."
for f in docker.io_library_registry-*.tar.gz docker.io_library_nginx-*.tar.gz; do
    $NERDCTL load -i $f
done

if [ -f kubespray-offline-container.tar.gz ]; then
    $NERDCTL load -i kubespray-offline-container.tar.gz
fi

popd

LOCAL_REGISTRY=${LOCAL_REGISTRY:-"localhost:${REGISTRY_PORT}"}

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

load_images
push_images

# Extract kubespray
./extract-kubespray.sh

# Create and activate a venv
/opt/rh/rh-python38/root/usr/bin/python -m venv venv/default
source venv/default/bin/activate

# Install pip and requirements
pip install -U pip
pip install -r $KUBESPRAY_DIR_NAME/requirements.txt

# Create inventory and offline.yml
python3 ./igz_inventory_builder.py ${@}
pushd ./$KUBESPRAY_DIR_NAME
cp -r inventory/sample inventory/igz
cp ../offline.yml inventory/igz/group_vars/all/
cp ../igz_override.yml .
popd 

# Copy playbook for offline repo
cp -r playbook ./$KUBESPRAY_DIR_NAME

cd ./$KUBESPRAY_DIR_NAME

# Run playbook
echo "NEED INVENTORY HERE!!!"
exit 0
ansible-playbook -i ${your_inventory_file} playbook/offline-repo.yml
# TODO - Unify with kubespray deployment

# Run kubespray
ansible-playbook -i inventory/igz/igz_inventory.ini cluster.yml --become --extra-vars=@igz_override.yml

