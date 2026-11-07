#!/usr/bin/env python3
"""Send console commands to a Factorio server over RCON (scripts/mp.sh).
  scripts/rcon.py <port> <password> "<command>" ["<command>" ...]   prints each reply."""
import socket, struct, sys


def packet(sock, rid, kind, body):
    data = struct.pack("<ii", rid, kind) + body.encode() + b"\x00\x00"
    sock.sendall(struct.pack("<i", len(data)) + data)


def read(sock):
    def exact(n):
        buf = b""
        while len(buf) < n:
            chunk = sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("rcon closed")
            buf += chunk
        return buf
    (size,) = struct.unpack("<i", exact(4))
    data = exact(size)
    rid, kind = struct.unpack("<ii", data[:8])
    return rid, kind, data[8:-2].decode(errors="replace")


def main():
    port, password, commands = int(sys.argv[1]), sys.argv[2], sys.argv[3:]
    with socket.create_connection(("127.0.0.1", port), timeout=30) as s:
        packet(s, 1, 3, password)
        rid, _, _ = read(s)
        if rid == -1:
            sys.exit("rcon: wrong password")
        for i, c in enumerate(commands, start=2):
            packet(s, i, 2, c)
            _, _, body = read(s)
            print(body.rstrip())


if __name__ == "__main__":
    main()
