#!/usr/bin/python

import sys

new_hosts = "%s" % sys.argv[1]
old_hosts = "%s.old" % sys.argv[1]

with open(new_hosts) as f:
    new = f.read().splitlines()

with open(old_hosts) as f:
     old = f.read().splitlines()

new1 = set(new)
old1 = set(old)

if old1.issubset(new1) :
    hosts = set.difference(new1, old1)

for i in hosts:
    print i
