#!/usr/bin/env python3
# -*- coding:utf-8 -*-
import socket               
import pycrc
import time

 
s = socket.socket()         # create socket 
host = '192.180.100.12'        # set ip
port = 4196                 # Set port

s.connect((host, port))     # connect serve
cmd = [0, 0, 0, 0, 0, 0, 0, 0]

cmd[0] = 0x01  #Device address
cmd[1] = 0x05  #command
cmd[2] = 0x00
cmd[3] = 0x01
cmd[4] = 0x00
cmd[5] = 0x00
crc = pycrc.ModbusCRC(cmd[0:6])
cmd[6] = crc & 0xFF
cmd[7] = crc >> 8
print("Sending: "+' '.join(f'{b:02X}' for b in cmd))
s.send(bytearray(cmd))
print("\tReply:  " + ' '.join(f'{b:02X}' for b in s.recv(1024)))
        
s.close()                   # Close the connection