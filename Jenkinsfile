@Library('pipelinex@_s3_python3') _
//test

timestamps {
common.notify_slack {
node('centos76') {

    stage('git clone') {
        deleteDir()
        def scm_vars = checkout scm
        env.kubespray_hash = scm_vars.GIT_COMMIT
        currentBuild.description = "hash = ${env.kubespray_hash}"
    }

    def img_name = "kubespray:${env.kubespray_hash}"
    def image = stage('build') {
        withCredentials([string(credentialsId: 'sudo_password', variable: 'sudo_password')]) {
        sh 'echo "Jenkinsfile starts here"'
        echo "Job name is: ${env.JOB_NAME}"
        sh 'echo "WORKSPACE is ${WORKSPACE}"'
        sh "cd ${WORKSPACE} ; bash prepare_offline_version.sh"
        }
    }

    def rel_dir = "build_by_hash/kubespray/${env.kubespray_hash}/pkg/kubespray"
    def nas_dir = "/mnt/nas/${rel_dir}"
    def output_name = 'outputs'  // The name of the directory you want to move
    def nas_target = "${nas_dir}"
    stage('save to nas') {
        withCredentials([string(credentialsId: 'sudo_password', variable: 'sudo_password')]) {
        common.shell(['mkdir', '-p', nas_dir])
        sh "mv ${WORKSPACE}/${output_name} ${nas_target}"
        sh "sudo rm -rf ${WORKSPACE}/${output_name}"
        }
    }
    stage('upload to s3') {
        def bucket = 'iguazio-versions'
        def bucket_region = 'us-east-1'
        def nas_image = "${nas_dir}/${output_name}"
        sh"""
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        """
        common.upload_to_s3(bucket, bucket_region, nas_image, "${rel_dir}/${output_name}")
    }
   }
  }
 }



