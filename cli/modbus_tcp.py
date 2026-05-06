#!/usr/bin/env python3
# -*- coding:utf-8 -*-
import socket
import time
 
s = socket.socket()         # creat socket 
host = '192.180.100.12'        # set ip
port = 4196                 # Set port
 
cmd = [0, 0, 0, 0, 0 ,0 , 0, 0, 0, 0, 0, 0]

cmd[5] = 0x06  #Byte length
cmd[6] = 0x01  #Device address
cmd[7] = 0x05  #command   

s.connect((host, port))     # connect serve
while True:
    for i in range(8):
        cmd[8] = 0
        cmd[9] = i
        cmd[10] = 0xFF
        cmd[11] = 0
        print(cmd)
        s.send(bytearray(cmd))
        time.sleep(2)
        
    for i in range(8):
        cmd[8] = 0
        cmd[9] = i
        cmd[10] = 0
        cmd[11] = 0
        print(cmd)
        s.send(bytearray(cmd))
        time.sleep(2)
s.close()                   # Close the connection
