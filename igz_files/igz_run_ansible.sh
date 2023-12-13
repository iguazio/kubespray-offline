#!/bin/bash

if [ -z "$docker" ]; then
    docker=docker
    if [ -e /usr/local/bin/nerdctl ]; then
        docker=/usr/local/bin/nerdctl
    fi
fi

$docker run -u $(id -u):$(id -g) \
    -v "${PWD}":/work \
    -v ~/.ssh:/root/.ssh \
    -v /etc/ssh:/etc/ssh \
    -v /etc/ansible/facts.d:/etc/ansible/facts.d \
    --name kubespray_ansible \
    --rm --entrypoint ansible-playbook \
    kubespray-offline-ansible:latest $*
