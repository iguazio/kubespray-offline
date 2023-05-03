#!/usr/bin/env bash
set -e

dir_name=$(dirname ${0})
component=${1}
if [[ "${component}" == "kubespray" ]]; then
  cd $dir_name/outputs
  BASEDIR=$(pwd)
  sudo ./igz_deploy.sh ${@:2}
else
  source ${dir_name}/venv/bin/activate
  export ANSIBLE_STRATEGY_PLUGINS=${dir_name}/venv/lib/python2.7/site-packages/ansible_mitogen/plugins/strategy
  export ANSIBLE_HOST_KEY_CHECKING=False
  export MITOGEN_POOL_SIZE=256
  ${dir_name}/${component}/run.py ${@:2}
  deactivate
fi
