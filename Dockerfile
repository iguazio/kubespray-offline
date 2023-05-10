FROM centos:7

COPY . .
RUN mv /igz_files/* .
ENTRYPOINT ["/igz_make_offline.sh"]

