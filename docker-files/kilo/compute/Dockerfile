FROM ubuntu:14.04
MAINTAINER Jaewoo Lee <continuse@icloud.com>

# Ubuntu Cloud archive keyring and repository
RUN apt-get update && apt-get -y install ubuntu-cloud-keyring \
        && echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
                "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list \
        && apt-get update && apt-get -y dist-upgrade

RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8  

RUN apt-get install -y nova-compute sysfsutils
RUN apt-get -y install nfs-common

######## neutron service ###############
RUN apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent

######### controller monitoring #########
RUN apt-get -y install telnet curl

######### /etc/hosts file modify #############
RUN cp /etc/hosts /tmp/hosts \
    && mkdir -p -- /lib-override && cp /lib/x86_64-linux-gnu/libnss_files.so.2 /lib-override \
    && perl -pi -e 's:/etc/hosts:/tmp/hosts:g' /lib-override/libnss_files.so.2

ENV LD_LIBRARY_PATH /lib-override
######### /etc/hosts file modify #############

# Configuration file for Nova/Neutron Service
COPY config/nova/nova.conf /etc/nova/nova.conf
COPY config/neutron/neutron.conf /etc/neutron/neutron.conf
COPY config/neutron/l3_agent.ini /etc/neutron/l3_agent.ini
COPY config/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini
COPY config/neutron//ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
#COPY config/nova/idmapd.conf /etc/idmapd.conf

RUN chown nova:nova /etc/nova/nova.conf \
  && chown root:neutron /etc/neutron/neutron.conf \
  && chown root:neutron /etc/neutron/l3_agent.ini \
  && chown root:neutron /etc/neutron/metadata_agent.ini \
  && chown root:neutron /etc/neutron/plugins/ml2/ml2_conf.ini

COPY hostsctl.sh /hostsctl.sh
COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]

EXPOSE 5900 16509

