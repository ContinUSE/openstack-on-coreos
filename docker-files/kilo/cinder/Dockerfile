FROM ubuntu:14.04
MAINTAINER Jaewoo Lee <continuse@icloud.com>

# Ubuntu Cloud archive keyring and repository
RUN apt-get update && apt-get -y install ubuntu-cloud-keyring \
        && echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
                "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list \
        && apt-get update && apt-get -y dist-upgrade

RUN apt-get -y install qemu
RUN apt-get -y install lvm2
RUN apt-get -y install cinder-volume python-mysqldb
RUN apt-get -y install nfs-kernel-server nfs-common
#RUN apt-get install -y open-iscsi tgt iscsitarget iscsitarget-dkms

######### controller monitoring #########
RUN apt-get -y install telnet curl ssh keepalived

######### /etc/hosts file modify #############
RUN cp /etc/hosts /tmp/hosts \
    && mkdir -p -- /lib-override && cp /lib/x86_64-linux-gnu/libnss_files.so.2 /lib-override \
    && perl -pi -e 's:/etc/hosts:/tmp/hosts:g' /lib-override/libnss_files.so.2

ENV LD_LIBRARY_PATH /lib-override
######### /etc/hosts file modify #############

# NFS Share Volume
VOLUME ["/storage"]

# Configuration file copy for Cinder Service
COPY config/cinder/cinder.conf /etc/cinder/cinder.conf
COPY config/cinder/cinder.conf.org /etc/cinder/cinder.conf.org
COPY config/cinder/lvm.conf /etc/lvm/lvm.conf
COPY config/cinder/idmapd.conf /etc/idmapd.conf
COPY config/cinder/nfs_shares /etc/cinder/nfs_shares
COPY config/cinder/exports /etc/exports

RUN chown cinder:cinder /etc/cinder/cinder.conf
RUN chown cinder:cinder /etc/cinder/cinder.conf.org
RUN chown root:cinder /etc/cinder/nfs_shares

COPY hostsctl.sh /hostsctl.sh
COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]
