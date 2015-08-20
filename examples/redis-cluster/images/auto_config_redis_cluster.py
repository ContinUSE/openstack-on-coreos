#!/usr/bin/python

import os, sys, json, etcd, time
from rediscluster.cluster_mgt import RedisClusterMgt
from subprocess import call

class JsonObject:
    def __init__(self, d):
        self.__dict__ = d

class EtcdObject:
    def __init__(self, ip, port, namespace, key):
        self.ip = ip
        self.port = int(port)
        self.namespace = namespace
        self.key = key

    def getHosts(self):
        hostIP = set()
        podIP  = []
        hostIP_podIP = {}
        
        client = etcd.Client(host=self.ip, port=self.port)

        etcd_key = "/registry/pods/%s" % self.namespace

        try:
            r = client.read(etcd_key, recursive=True, sorted=True, timeout=1)
            for child in r.children:
                data = json.loads(child.value, object_hook=JsonObject)
           
                if data.metadata.labels.name[0:len(self.key)] == self.key and \
                             data.status.phase == "Running":
                        hostIP.add(data.status.hostIP)
                        podIP.append('%s:6379' % data.status.podIP)
                        if not data.status.hostIP in hostIP_podIP.keys() :
                            hostIP_podIP[data.status.hostIP] = []
                        hostIP_podIP[data.status.hostIP].append('%s:6379' % data.status.podIP)

            return hostIP, podIP, hostIP_podIP
        except Exception:
            return -1, -1, -1

def redis_cluster(hosts):
    startup_nodes = []

    for i in hosts:
        hostIP = i.split(':')
        x = {"host":hostIP[0], "port":hostIP[1]}
        startup_nodes.append(x)

    try:
        r = RedisClusterMgt(startup_nodes)

        return r.slots(), r.nodes()
    except Exception:
        return -1, -1

def distrib_host(hosts, rep) :
    master = []
    slave = []

    i = 0
    while True:
        if len(hosts) == 0:
            break
        #for key in hosts.keys(): 
        for k in sorted(hosts, key=lambda k: len(hosts[k]), reverse=True):
            if len(hosts[k]) != 0:
                pod = hosts[k].pop()
                if (i % (rep+1)) == 0:
                    master.append(pod)
                else :
                    slave.append(pod)
                i += 1
    
            else :
                del hosts[k]

    return master, slave

# Redis Cluster Init Setup
def redis_init_setup(hostIP, podIP, host_podIP, replicas):
    if len(podIP) > 0 and len(podIP) % (replicas + 1) == 0 :
        print "###### The redis cluster create at the first time."
        m, s = distrib_host(hostIP_podIP, replicas)
        x = len(m) 
        y = len(s)
        if (x + y) % (replicas + 1) == 0 and (x + y) >= 3 * (replicas + 1) :
            command1 = "spawn /redis-3.0.3/src/redis-trib.rb create --replicas %d" % replicas
            command2 = ' '.join(m)
            command3 = ' '.join(s)
            command = ' '.join([command1, command2, command3])
            with open('expect.script', 'w') as f:
                f.write("set timeout 30\n")
                f.write("%s\n" % command)
                f.write("expect \"*yes*\"\n")
                f.write("send \"yes\\r\"\n")
                f.write("expect \"All 16384 slots covered\"\n")
                f.write("expect eof\n")
                f.close()

            # expect excute
            command_list = ["/usr/bin/expect", "-f", "expect.script"]
            xx = call(command_list)
    else :
        print 'The redis cluster need at least %d nodes.' % (3 * (replicas + 1) )

def redis_add_setup(hostIP, podIP, hostIP_podIP, replicas, real_master, real_slave):
    # Getting new node info 
    for key in hostIP_podIP.keys():
        diff = set(hostIP_podIP[key]) - (set(real_master) | set(real_slave))
        hostIP_podIP[key] = list(diff)

    new_master, new_slave = distrib_host(hostIP_podIP, replicas)

    f = open('expect.script', 'w')
    f.write("set timeout 30\n")
    for i in new_master:
        command1 = "spawn /redis-3.0.3/src/redis-trib.rb add-node %s %s" % \
                      (i,  real_master[0])
        f.write("%s\n" % command1)
        f.write("expect \"New node added correctly\"\n")

    f.write("expect eof\n")
    f.close()

    # expect excute
    command_list = ["/usr/bin/expect", "-f", "expect.script"]
    call(command_list)

    time.sleep(3)

    # get node id
    ret, nodes = redis_cluster(podIP)

    cluster_length = len(real_master) 
    command1 = "spawn /redis-3.0.3/src/redis-trib.rb reshard %s" % (real_master[0])
    for i in new_master:
        # redis cluster fix processing
        for key in nodes.keys():
            if nodes[key]['role'] == 'master':
                 command_list = []
                 command_list.append("/redis-3.0.3/src/redis-trib.rb")
                 command_list.append("fix")
                 command_list.append(key)
                 call(command_list)

        # reshard for a new node
        cluster_length += 1
        f = open('expect.script', 'w')
        f.write("set timeout 30\n")
        f.write("%s\n"% command1)
        f.write("expect \"How many slots do you want to move\"\n")
        f.write("send \"%d\\r\"\n" % (16384 / cluster_length))
        f.write("expect \"What is the receiving node ID\"\n")
        f.write("send \"%s\\r\"\n" % nodes[i]['node_id'])
        f.write("expect \"Source node #1\"\n")
        f.write("send \"all\\r\"\n")
        f.write("expect \"Do you want to proceed with the proposed reshard plan\"\n")
        f.write("send \"yes\\r\"\n")
        f.write("expect eof\n")
        f.close()

        # expect excute
        command_list = ["/usr/bin/expect", "-f", "expect.script"]
        if call(command_list) != 0:
            command1 = "spawn /redis-3.0.3/src/redis-trib.rb del-node %s %s" % (real_master[0], nodes[i]['node_id'])
            f = open('expect.script', 'w')
            f.write("set timeout 30\n")
            f.write("%s\n"% command1)
            f.write("expect eof\n")
            f.close()
            xx = call(command_list)
            print 'DEL-NODE', xx
            return

    # make slave
    i = 0
    for m in new_master:
        while replicas :
            f = open('expect.script', 'w')
            f.write("set timeout 30\n")
            command2 = "spawn /redis-3.0.3/src/redis-trib.rb add-node --slave %s %s" % \
                          (new_slave[i], m)
            f.write("%s\n"% command2)
            f.write("expect eof\n")
            f.close()
            # expect excute
            command_list = ["/usr/bin/expect", "-f", "expect.script"]
            call(command_list)

            i += 1
            if i % replicas == 0:
                break

def redis_recovery_setup(ret, real_master, real_slave, podIP, hostIP_podIP, replicas):
    m = {} # master from redis cluster info
    s = {} # slave from redis cluster info
    t = {} # count of slave for master

    # split master / slave from ret dict
    for key in ret.keys():
        if key == 'master':
            for ip in ret[key].keys():
                m[ip] = ret[key][ip]
        if key == 'slave':
            for ip in ret[key].keys():
                s[ip] = ret[key][ip]

    # init count of slave no, of master
    for key in m.keys():
        t[key] = 0

    for v in s.values():
        for k in m.keys():
            if m[k] == v:
                i = t[k] 
                t[k] = i + 1

    be_slave = {}
    diff = set(podIP) - (set(real_master) | set(real_slave))
    for x in diff:
        for y in hostIP_podIP.keys():
            if x in hostIP_podIP[y]:
                be_slave[x] = y

    for x in t.keys():
        for y in hostIP_podIP.keys():
            if x in hostIP_podIP[y]:
                while t[x] < replicas:
                    t[x] = t[x] + 1
                    for z in be_slave.keys():
                        if be_slave[z] != y:
                            command1 = "spawn /redis-3.0.3/src/redis-trib.rb add-node --slave %s %s" % (z, x)
                            f = open('expect.script', 'w')
                            f.write("set timeout 30\n")
                            f.write("%s\n"% command1)
                            f.write("expect eof\n")
                            f.close()
                            # expect excute
                            command_list = ["/usr/bin/expect", "-f", "expect.script"]
                            call(command_list)
                    
etcdctl_peers = os.getenv('ETCDCTL_PEERS')
kube_namespace = os.getenv('KUBE_NAMESPACE')
kube_label = os.getenv('KUBE_LABEL')
replicas = int(os.getenv("REPLICAS"))

# Check for etcdctl_peers is str type
if not isinstance(etcdctl_peers, str) :
    exit(1)

etcd_ip_port = etcdctl_peers.split(',')

# pod info from etcd
flag = 0
for ctrl_ip_port in etcd_ip_port :
    ip, port = ctrl_ip_port.split(':')
    a = EtcdObject(ip, port, kube_namespace, kube_label)
    hostIP, podIP, hostIP_podIP = a.getHosts()

    if isinstance(hostIP_podIP, dict) and isinstance(hostIP, set) and isinstance(podIP, list):
        flag = 1
        break

# redis cluster info
if flag == 1:
    print "Getting information for redis cluster..........."
    time.sleep(5)
    ret, nodes = redis_cluster(podIP)

    if ret == -1:
        ### REDIS INITIAL SETUP ###
        print "Initial setup for the redis cluster.........."
        redis_init_setup(hostIP, podIP, hostIP_podIP, replicas)

    else :
        real_master = ret['master'].keys()
        real_slave = ret['slave'].keys()

        ### Nomal Case (NO CHANGE OR ADD NODE) ###
        if len(real_master) * replicas == len(real_slave) :
            ### THERE IS NO CHANGE THE CLUSTER ###
            if set(real_master) | set(real_slave) == set(podIP): # Normal
                print "There is no change in the redis cluster."
            ### THE REDIS CLUSTER NODE ADD ###
            else :
                print "The redis cluster node add."
                redis_add_setup(hostIP, podIP, hostIP_podIP, replicas, real_master, real_slave)

        ### Abnormal : one or more nodes failure ###
        else :
            print "node failure....."
            redis_recovery_setup(ret, real_master, real_slave, podIP, hostIP_podIP, replicas)

### ETCD CONNECTION ERROR
else :
    print "Error : etcd connection error"

