FROM       ubuntu:14.04
MAINTAINER Jaewoo Lee <continuse@icloud.com>

RUN apt-get update

RUN apt-get install -y openssh-server
RUN mkdir /var/run/sshd

RUN echo 'root:root' |chpasswd

RUN sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

RUN ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N ""
RUN cd /root/.ssh && cp id_rsa.pub authorized_keys

RUN apt-get install -y python-pip gfortran

# ETCD for python
RUN cd /tmp && wget https://github.com/jplana/python-etcd/archive/0.4.1.tar.gz && \
    tar xvfz 0.4.1.tar.gz && cd python-etcd-0.4.1 && pip install .

# MPICH3 Install
RUN cd /tmp && wget http://www.mpich.org/static/downloads/3.1.4/mpich-3.1.4.tar.gz && \
    tar xvfz mpich-3.1.4.tar.gz && cd mpich-3.1.4 && ./configure --prefix=/tmp/mpich && \
    make && make VERBOSE=1 && make install

RUN apt-get install -y expect telnet curl

COPY entrypoint.sh /entrypoint.sh
COPY pod_ip.py /pod_ip.py
COPY known_hosts.py /known_hosts.py
COPY auto_ssh.sh /auto_ssh.sh
COPY bash_profile /root/.bash_profile

ENV PATH $PATH:/tmp/mpich/bin

EXPOSE 22

CMD    ["/entrypoint.sh"]
