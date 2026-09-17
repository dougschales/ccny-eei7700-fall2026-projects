#!/usr/bin/env python3
import socket
import sys

def main():
    host = '0.0.0.0'
    port = 9001

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((host, port))
    server_socket.listen(5)
    print(f"Custom Admin Gateway listening on port {port}...")

    while True:
        try:
            client_socket, addr = server_socket.accept()
            banner = (
                "CyberCorp Internal Admin Gateway v1.4.2 [Service: CC-Admin-Gateway]\n"
                "System Status: ONLINE\n"
                "Flag 2: flag{w3_2_n0n_st4nd4rd_p0rt_d1sc0v3ry}\n"
            )
            client_socket.sendall(banner.encode('utf-8'))
            client_socket.close()
        except Exception as e:
            print(f"Error handling connection: {e}")

if __name__ == '__main__':
    main()
