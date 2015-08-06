#!/usr/bin/python

import os, sys, json, etcd

class JsonObject:
    def __init__(self, d):
        self.__dict__ = d

class EtcdObject:
    def __init__(self, ip, port, namespace):
        self.ip = ip
        self.port = int(port)
        self.namespace = namespace

    def getHosts(self):
        client = etcd.Client(host=self.ip, port=self.port)

        etcd_key = "/registry/pods/%s" % self.namespace

        try:
            r = client.read(etcd_key, recursive=True, sorted=True, timeout=1)
            for child in r.children:
                data = json.loads(child.value, object_hook=JsonObject)
                if data.status.phase == "Running":
                    print data.status.podIP

            return 0
        except Exception:
            return -1

etcdctl_peers = os.getenv('ETCDCTL_PEERS')
if isinstance(etcdctl_peers, str) :
    etcd_ip_port = etcdctl_peers.split(',')

    for ctrl_ip_port in etcd_ip_port :
        ip, port = ctrl_ip_port.split(':')
        a = EtcdObject(ip, port, sys.argv[1])
        if a.getHosts() == 0 :
            exit(0)
