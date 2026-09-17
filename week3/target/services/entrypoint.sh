#!/bin/bash
set -e

echo "[+] Initializing Target Container Services..."

# 1. Setup Flag 1 (FTP - vsFTPd)
mkdir -p /srv/ftp
echo "Welcome to CyberCorp FTP Server (vsFTPd 3.0.5)." > /srv/ftp/welcome.txt
echo "Flag 1: flag{w3_1_vsftpd_3num_b4nn3r_f4c1l3}" >> /srv/ftp/welcome.txt
chmod 644 /srv/ftp/welcome.txt
mkdir -p /var/run/vsftpd/empty

# Start vsFTPd in background
vsftpd /etc/vsftpd.conf &
echo "[+] Started vsFTPd on port 21"

# 2. Setup Flag 2 (Custom Admin Gateway TCP on port 9001)
python3 /opt/services/banner_service.py &
echo "[+] Started Custom Admin Gateway on port 9001"

# 3. Setup Flag 3 (NFS exposed share)
mkdir -p /srv/nfs/public/backups
echo "flag{w3_3_nfs_3xp0s3d_sh4r3_3num3r4t10n}" > /srv/nfs/public/backups/flag3.txt
chmod -R 777 /srv/nfs/public
python3 /opt/services/nfs_service.py &
echo "[+] Started NFS Server on port 2049 & RPC on port 111"

# 4. Setup Flag 4 (Redis Server on port 6379)
redis-server /etc/redis/redis.conf
sleep 1
redis-cli set "db:config" '{"app_env":"production", "debug_flag":"flag{w3_4_r3d1s_cr3d_l34k_m1sc0nf1g}"}'
echo "[+] Started Redis Server on port 6379"

# 5. Setup Flag 5 (SSH on port 2222 and Flask Dev Portal on port 8080)
# Create sysadmin user if doesn't exist
if ! id "sysadmin" &>/dev/null; then
    useradd -m -s /bin/bash sysadmin
    echo "sysadmin:CyberCorpPassword2026!" | chpasswd
fi

mkdir -p /home/sysadmin/.ssh
chmod 700 /home/sysadmin/.ssh
cat /opt/services/id_rsa.pub > /home/sysadmin/.ssh/authorized_keys
chmod 600 /home/sysadmin/.ssh/authorized_keys
chown -R sysadmin:sysadmin /home/sysadmin/.ssh

echo "flag{w3_5_ch41n3d_vulp0rt_4p1_cr4ck_ssh_m4st3r}" > /home/sysadmin/flag5.txt
chmod 644 /home/sysadmin/flag5.txt
chown sysadmin:sysadmin /home/sysadmin/flag5.txt

# Start SSH daemon on port 2222
mkdir -p /var/run/sshd
/usr/sbin/sshd -p 2222
echo "[+] Started SSH Server on port 2222"

# 6. Apache Web Server on port 80
cp /opt/services/apache_site.html /var/www/html/index.html
service apache2 start
echo "[+] Started Apache Web Server on port 80"

# 7. Flask Developer Portal on port 8080
python3 /opt/services/web_app.py &
echo "[+] Started Flask Dev Portal on port 8080"

echo "[+] All Target Services Started Successfully."

# Keep container running
exec tail -f /dev/null
