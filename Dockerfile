FROM rockylinux:8.7

RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-19.03.13.tgz | tar zxvf - --strip 1 -C /usr/local/bin docker/docker
RUN dnf install -y libselinux-utils patch sudo

COPY . .
RUN mv /igz_files/* .
ENTRYPOINT ["/igz_make_offline.sh"]
