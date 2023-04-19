echo "Welcome to new Kubespray Job!"
echo "Currently working in $(pwd)"
#export BUILD_PATH="/mnt/nas/kubespray_offline/${BRANCH_NAME}/outputs"
export BASEDIR=$(pwd)

sudo docker build -t kubespray-offline:${BRANCH_NAME} .
echo "Running container with sudo docker run -v $BASEDIR/outputs:/outputs -v /var/run/docker.sock:/var/run/docker.sock kubespray-offline:${BRANCH_NAME}"
sudo docker run -v $BASEDIR/outputs:/outputs -v /var/run/docker.sock:/var/run/docker.sock kubespray-offline:${BRANCH_NAME} || exit 1
echo "Checking outputs dir:"
ls -ltrh $BASEDIR/outputs
echo "Logging full path just in case:"
cd $BASEDIR/outputs
pwd
echo "Offline script exits here. Bye"
exit 0
