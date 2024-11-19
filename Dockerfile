FROM rockylinux:8

RUN \
  dnf -y update \
  && dnf install -y wget \
  && dnf install -y curl \
  && dnf install -y jq \
  && dnf install -y vim \
  && dnf install -y sudo \
  && dnf install -y gnupg \
  && dnf install -y procps-ng \
  && dnf install -y openssh-server \
  && dnf install -y openssh-clients \
  && dnf install -y less

RUN dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
RUN dnf -qy module disable postgresql
RUN dnf install -y postgresql16-server
RUN dnf install -y repmgr_16

RUN mkdir -p /pgdata/16/
RUN chown -R postgres:postgres /pgdata
RUN chmod 0700 /pgdata

RUN mkdir -p /var/lib/pgsql/.ssh
RUN chown postgres:postgres /var/lib/pgsql/.ssh
RUN chmod 0700 /var/lib/pgsql/.ssh


COPY pg_custom.conf /
COPY pg_hba.conf /
COPY pgsqlProfile /
COPY id_rsa.pub /
COPY id_rsa /
COPY authorized_keys /

EXPOSE 80
EXPOSE 22
EXPOSE 5432

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

SHELL ["/bin/bash", "-c"]
ENTRYPOINT /entrypoint.sh

