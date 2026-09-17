#!/usr/bin/env python3
"""
Lightweight User-Space NFS & RPC Portmapper Daemon
Fulfills showmount -e, rpcinfo, and direct NFS socket/mount enumeration
without requiring Linux kernel nfsd modules in unprivileged Docker containers.
"""
import socket
import select
import struct
import threading

EXPORT_PATH = "/srv/nfs/public"
FLAG3_CONTENT = "flag{w3_3_nfs_3xp0s3d_sh4r3_3num3r4t10n}\n"

def build_rpc_reply(xid, accept_stat=0):
    # RPC Reply header: XID, MSG_TYPE (1=REPLY), REPLY_STAT (0=ACCEPTED), AUTH_NULL
    return struct.pack('>IIIIII', xid, 1, 0, 0, 0, accept_stat)

def handle_portmap_request(data):
    if len(data) < 24:
        return b''
    xid, msg_type, rpc_vers, prog, vers, proc = struct.unpack('>IIIIII', data[:24])
    if msg_type != 0: # 0 = CALL
        return b''
    
    reply_header = build_rpc_reply(xid, 0)
    
    # PMAPPROC_NULL (0)
    if proc == 0:
        return reply_header
    # PMAPPROC_GETPORT (3) or DUMP (4)
    elif proc in (3, 4):
        # Return port 2049 for NFS / MOUNTD
        return reply_header + struct.pack('>I', 2049)
    else:
        return reply_header + struct.pack('>I', 0)

def handle_nfs_request(data):
    if len(data) < 24:
        return FLAG3_CONTENT.encode('utf-8')
    
    xid, msg_type, rpc_vers, prog, vers, proc = struct.unpack('>IIIIII', data[:24])
    reply_header = build_rpc_reply(xid, 0)

    # If program is MOUNTD (100005) and proc is EXPORT (5)
    if prog == 100005 and proc == 5:
        # Build RPC export list payload for showmount -e
        # exportentry: Value Follows (1), String ("/srv/nfs/public"), groupentry: Value Follows (1), String ("*"), end groups (0), end exports (0)
        path_bytes = EXPORT_PATH.encode('utf-8')
        path_len = len(path_bytes)
        path_pad = (4 - (path_len % 4)) % 4
        
        group_bytes = b"*"
        group_len = 1
        group_pad = 3

        payload = (
            struct.pack('>II', 1, path_len) + path_bytes + b'\x00' * path_pad +
            struct.pack('>II', 1, group_len) + group_bytes + b'\x00' * group_pad +
            struct.pack('>II', 0, 0)
        )
        return reply_header + payload
    else:
        # Default response for NFS read/lookup/banner
        return reply_header + struct.pack('>I', 0) + EXPORT_PATH.encode('utf-8') + b"\n" + FLAG3_CONTENT.encode('utf-8')

def run_portmap_listener():
    try:
        udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        udp_sock.bind(('0.0.0.0', 111))

        tcp_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        tcp_sock.bind(('0.0.0.0', 111))
        tcp_sock.listen(5)
    except Exception as e:
        print(f"Portmapper 111 bind notice: {e}")
        return

    while True:
        try:
            r, _, _ = select.select([udp_sock, tcp_sock], [], [], 1.0)
            for s in r:
                if s is udp_sock:
                    data, addr = udp_sock.recvfrom(4096)
                    resp = handle_portmap_request(data)
                    if resp:
                        udp_sock.sendto(resp, addr)
                elif s is tcp_sock:
                    client, addr = tcp_sock.accept()
                    try:
                        data = client.recv(4096)
                        if len(data) > 4:
                            resp = handle_portmap_request(data[4:])
                            if resp:
                                frag_hdr = struct.pack('>I', 0x80000000 | len(resp))
                                client.sendall(frag_hdr + resp)
                    except Exception:
                        pass
                    finally:
                        client.close()
        except Exception:
            pass

def run_nfs_listener():
    # Listen on Port 2049 UDP and TCP
    udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    udp_sock.bind(('0.0.0.0', 2049))

    tcp_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    tcp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    tcp_sock.bind(('0.0.0.0', 2049))
    tcp_sock.listen(5)

    while True:
        r, _, _ = select.select([udp_sock, tcp_sock], [], [], 1.0)
        for s in r:
            if s is udp_sock:
                data, addr = udp_sock.recvfrom(4096)
                resp = handle_nfs_request(data)
                udp_sock.sendto(resp, addr)
            elif s is tcp_sock:
                client, addr = tcp_sock.accept()
                try:
                    data = client.recv(4096)
                    resp = handle_nfs_request(data)
                    # Send response (with record marking if RPC call)
                    if len(data) >= 4 and (struct.unpack('>I', data[:4])[0] & 0x80000000):
                        frag_hdr = struct.pack('>I', 0x80000000 | len(resp))
                        client.sendall(frag_hdr + resp)
                    else:
                        banner = f"NFS Export Share: {EXPORT_PATH}\nBackups Directory: {EXPORT_PATH}/backups/flag3.txt\nFlag 3: {FLAG3_CONTENT}".encode('utf-8')
                        client.sendall(banner)
                except Exception:
                    pass
                finally:
                    client.close()

def main():
    print("[+] Starting User-Space RPC Portmapper (111) & NFS Server (2049)...")
    t1 = threading.Thread(target=run_portmap_listener, daemon=True)
    t2 = threading.Thread(target=run_nfs_listener, daemon=True)
    t1.start()
    t2.start()
    t1.join()
    t2.join()

if __name__ == '__main__':
    main()
