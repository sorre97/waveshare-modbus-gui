#!/usr/bin/env python3
# -*- coding:utf-8 -*-
import socket
import pycrc
import argparse
from enum import Enum

# === CONFIGURABLE PARAMETERS ===
host = '192.180.100.21'   # Device IP
port = 4196               # Device port
device_address = 0x01     # Modbus device address

class ModbusFunctionCode(Enum):
    READ_COILS             = 0x01  # Read relay status
    READ_HOLDING_REGISTERS = 0x03  # Read address/version
    WRITE_SINGLE_COIL      = 0x05  # Write single relay
    WRITE_SINGLE_REGISTER  = 0x06  # Set baud rate / address
    WRITE_MULTIPLE_COILS   = 0x0F  # Write all relays

class ModbusSubcommandCode(Enum):
    RELAY_ON     = 0xFF00
    RELAY_OFF    = 0x0000
    RELAY_TOGGLE = 0x5500

# === ARGUMENT PARSING ===
parser = argparse.ArgumentParser(description="Minimal Modbus TCP control script")
parser.add_argument("-c", "--command", required=True, choices=["read", "write", "toggle","READ", "WRITE", "TOGGLE"], help="Command: read, write, toggle")
parser.add_argument("-r", "--relay", type=int, help="Relay number (0-7)")
parser.add_argument("-a", "--all", action="store_true", help="Apply to all relays (0-7)")
parser.add_argument("-v", "--value", choices=["on", "off", "ON", "OFF"], help="Value to write (only for -c write)")
args = parser.parse_args()

# === VALIDATION ===
if not args.all and (args.relay is None or not (0 <= args.relay <= 7)) and args.command.lower()!="read":
    parser.error("Please specify -r 0..7 or use -a for all")

if args.command.lower() == "write" and args.value is None:
    parser.error("-v [on|off] is required when using -c write")

# === FUNCTION AND VALUE SELECTION ===
cmd_lower = args.command.lower()
if cmd_lower == "read":
    function_code = ModbusFunctionCode.READ_COILS.value
    subcommand = 0x0000  # Dummy
elif cmd_lower == "write":
    function_code = ModbusFunctionCode.WRITE_SINGLE_COIL.value
    subcommand = ModbusSubcommandCode.RELAY_ON.value if args.value.lower() == "on" else ModbusSubcommandCode.RELAY_OFF.value
elif cmd_lower == "toggle":
    function_code = ModbusFunctionCode.WRITE_SINGLE_COIL.value
    subcommand = ModbusSubcommandCode.RELAY_TOGGLE.value

def make_cmd(subaddr, value):
    cmd = [0]*8
    cmd[0] = device_address
    cmd[1] = function_code
    cmd[2] = 0x00
    cmd[3] = subaddr
    cmd[4] = (value >> 8) & 0xFF
    cmd[5] = value & 0xFF
    crc = pycrc.ModbusCRC(cmd[0:6])
    cmd[6] = crc & 0xFF
    cmd[7] = crc >> 8
    return cmd

# === EXECUTION ===
s = socket.socket()
s.connect((host, port))

try:
    if cmd_lower == "read":
        targets = range(1) 
        subcommand = 0x0008
    elif args.all:
        targets = range(8) 
    else: 
        targets= [args.relay]
    for i in targets:
        cmd = make_cmd(i, subcommand)
        print("Command: " + ' '.join(f'{b:02X}' for b in cmd))
        s.send(bytearray(cmd))
        resp = s.recv(1024)
        
        if cmd_lower == "read" and len(resp) >= 4:
            status = resp[3]
            print("\nRelay states: \n\n\t[", ' '.join(f'{i}:{"\033[32mON " if status & (1<<i) else "\033[31mOFF "}\033[39m|' for i in range(8)) + "\b]\n\n")
        else:
            print("\nReply:  " + ' '.join(f'{"\033[32m" if resp == bytearray(cmd)else "\033[31m"}{b:02X}' for b in resp)+f'{" [CMD_ACK]"if resp == bytearray(cmd)else" [CMD_NOT_OK]"}\033[39m\n')
        
finally:
    s.close()
