FROM ubuntu:14.04
MAINTAINER Jaewoo Lee <continuse@icloud.com>

RUN apt-get update \
	&& apt-get -y install software-properties-common python-software-properties \
	&& add-apt-repository -y cloud-archive:juno \
	&& apt-get update \
	&& apt-get -y dist-upgrade \
	&& apt-get -y install python-mysqldb 

RUN apt-get -y install nova-compute sysfsutils 

######## neutron service ###############
RUN apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent

########## Let's start with docker in docker service ###########
RUN apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    curl \
    telnet \
    lxc \
    iptables
    
# Install Docker from Docker Inc. repositories.
RUN curl -sSL https://get.docker.com/ubuntu/ | sh
########## Let's end with docker in docker service ###########

### Docker Driver on Openstack:juno ######
RUN apt-get -y install python-pip
RUN usermod -G docker nova
RUN git clone https://github.com/stackforge/nova-docker
RUN cd /nova-docker && git checkout stable/juno \
    && sudo python setup.py install

######### /etc/hosts file modify #############
RUN cp /etc/hosts /tmp/hosts && \
    mkdir -p -- /lib-override && cp /lib/x86_64-linux-gnu/libnss_files.so.2 /lib-override && \
    perl -pi -e 's:/etc/hosts:/tmp/hosts:g' /lib-override/libnss_files.so.2

ENV LD_LIBRARY_PATH /lib-override
######### /etc/hosts file modify #############

# Glance Setup
RUN apt-get -y install glance

COPY nova-compute.conf /etc/nova/nova-compute.conf
COPY docker.filters /etc/nova/rootwrap.d/docker.filters
COPY hostsctl.sh /hostsctl.sh
COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]

EXPOSE 5900 16509

