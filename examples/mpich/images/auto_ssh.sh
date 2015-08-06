#!/usr/bin/expect

set server      [lindex $argv 0]

spawn ssh -o "StrictHostKeyChecking no" root@$server
expect -re "#"
send "exit"
