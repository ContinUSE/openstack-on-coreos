FROM ubuntu:14.04
MAINTAINER Jaewoo Lee <continuse@icloud.com>

# Ubuntu Cloud archive keyring and repository
RUN apt-get update && apt-get -y install ubuntu-cloud-keyring \
        && echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
                "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list \
        && apt-get update && apt-get -y dist-upgrade

RUN apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent

######### controller monitoring #########
RUN apt-get -y install telnet curl ssh keepalived

######### /etc/hosts file modify #############
RUN cp /etc/hosts /tmp/hosts \
    && mkdir -p -- /lib-override && cp /lib/x86_64-linux-gnu/libnss_files.so.2 /lib-override \
    && perl -pi -e 's:/etc/hosts:/tmp/hosts:g' /lib-override/libnss_files.so.2

ENV LD_LIBRARY_PATH /lib-override
######### /etc/hosts file modify #############

# Configuration file copy for Neutron Service
COPY config/neutron/neutron.conf /etc/neutron/neutron.conf
COPY config/neutron/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
COPY config/neutron/l3_agent.ini /etc/neutron/l3_agent.ini
COPY config/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini
COPY config/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini
COPY config/neutron/dnsmasq-neutron.conf /etc/neutron/dnsmasq-neutron.conf

RUN chown root:neutron /etc/neutron/neutron.conf \
 && chown root:neutron /etc/neutron/plugins/ml2/ml2_conf.ini \
 && chown root:neutron /etc/neutron/l3_agent.ini \
 && chown root:neutron /etc/neutron/dhcp_agent.ini \
 && chown root:neutron /etc/neutron/metadata_agent.ini \
 && chown root:neutron /etc/neutron/dnsmasq-neutron.conf

COPY hostsctl.sh /hostsctl.sh
COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]

EXPOSE 9696
