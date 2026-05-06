import asyncio
import pycrc


class MockModbusServer:
    def __init__(self, host="127.0.0.1", port=4196, verbose=False):
        self.host = host
        self.port = port
        self.verbose = verbose
        self.relays = [False] * 8

    async def start(self):
        server = await asyncio.start_server(self.handle_client, self.host, self.port)
        addr = server.sockets[0].getsockname()
        print(f"[Mock Modbus] Listening on {addr[0]}:{addr[1]}")
        async with server:
            await server.serve_forever()

    async def handle_client(self, reader, writer):
        peer = writer.get_extra_info("peername")
        print(f"[Mock Modbus] Client connected from {peer}")
        try:
            while True:
                data = await reader.read(1024)
                if not data:
                    break

                if len(data) < 4:
                    continue

                func = data[1]
                addr = data[0]

                if func == 0x01:  # Read coils
                    # Only log reads in verbose mode — they fire every second
                    if self.verbose:
                        print(f"[Mock Modbus] READ  -> {data.hex()}")

                    status = 0
                    for i, state in enumerate(self.relays):
                        if state:
                            status |= 1 << i

                    resp = bytearray([addr, func, 1, status])
                    crc = pycrc.ModbusCRC(resp)
                    resp.append(crc & 0xFF)
                    resp.append(crc >> 8)
                    writer.write(resp)
                    await writer.drain()

                elif func == 0x05:  # Write single coil
                    subaddr = data[3]
                    val = data[4]

                    if subaddr < 8:
                        if val == 0xFF:
                            self.relays[subaddr] = True
                        elif val == 0x00:
                            self.relays[subaddr] = False
                        elif val == 0x55:
                            self.relays[subaddr] = not self.relays[subaddr]

                    state_str = "ON" if self.relays[subaddr] else "OFF"
                    print(
                        f"[Mock Modbus] WRITE  relay {subaddr + 1} -> {state_str}  (raw: {data.hex()})"
                    )

                    # ACK: echo the command back
                    writer.write(data)
                    await writer.drain()

                else:
                    print(
                        f"[Mock Modbus] Unknown function code 0x{func:02X} — ignoring"
                    )

        except asyncio.CancelledError:
            pass
        except Exception as e:
            print(f"[Mock Modbus] Error: {e}")
        finally:
            print(f"[Mock Modbus] Client {peer} disconnected")
            writer.close()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Mock Waveshare Modbus TCP Server")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host")
    parser.add_argument("--port", type=int, default=4196, help="Bind port")
    parser.add_argument("--verbose", action="store_true", help="Log read polls too")
    args = parser.parse_args()

    asyncio.run(
        MockModbusServer(host=args.host, port=args.port, verbose=args.verbose).start()
    )
