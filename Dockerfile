FROM rockylinux/rockylinux:8.8

RUN dnf install -y dnf-plugins-core
RUN dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
RUN dnf install -y docker-ce docker-ce-cli containerd.io findutils which sudo

COPY . .
RUN mv /igz_files/* .
ENTRYPOINT ["/igz_make_offline.sh"]
