@Library('pipelinex@development') _

def config = common.get_config()

def props = [
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '30', numToKeepStr: '1000'))
    ]

if (config.cron.get(env.BRANCH_NAME)) {
    props.add(pipelineTriggers([cron(config.cron.get(env.BRANCH_NAME))]))
}

properties(props)

common.main {
    nodes.builder('tel-ad') {
        timestamps {

            stage('checkout') {
                deleteDir()
                final scm_vars = checkout scm

                env.zoo_hash = scm_vars.GIT_COMMIT
                currentBuild.description = "branch ${env.BRANCH_NAME}, ${env.zoo_hash}"
            }

            stage('build') {
                dir('deployment') {
                    writeFile(file: 'commit', text: env.zoo_hash)
                    writeFile(file: 'branch_name', text: env.BRANCH_NAME)
                    writeFile(file: 'build', text: env.BUILD_NUMBER)
                    writeFile(file: 'version', text: version.iguazio_major_minor)

                    def docker_img_name = "devops/zoo_builder:${env.zoo_hash}"

                    common.shell(['docker', 'build', '-t', docker_img_name, '.'])

                    try {
                        withCredentials([usernamePassword(credentialsId: 'artifactory_iguazio_ro',
                                                        usernameVariable: 'artifactory_user',
                                                        passwordVariable: 'artifactory_password')]) {

                            sh "docker run -v \$(pwd):/myansible --rm ${docker_img_name} \
                                -i inventory/hosts plays/download_artifacts.yml \
                                --extra-vars \"zoo_art_user=${env.artifactory_user} zoo_art_password=${env.artifactory_password}\""
                        }
                    } finally {
                        // let's save time and bandwidth
                        // common.shell(['docker', 'rmi', docker_img_name])
                    }
                }
            }

            stage('upload assets') {
                parallel(
                    'upload_to_nas': {
                        def build_by_hash_dir = "/mnt/nas/build_by_hash/zoo"
                        def nas_dir = "${build_by_hash_dir}/${env.zoo_hash}/pkg/zoo"
                        sh("mkdir -p ${nas_dir}")
                        sh("cp -r deployment/* ${nas_dir}/")
                    },
                    'upload_to_s3': {
                        def bucket = 'iguazio-versions'
                        def bucket_region = 'us-east-1'
                        common.upload_to_s3(bucket, bucket_region, 'deployment', "build_by_hash/zoo/${env.zoo_hash}/pkg/zoo")
                    }
                )
            }
        }
    }
}
