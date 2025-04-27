# DEMO-2025:
**В данном репозитории представлено полное решение демонстрационного экзамена (ДЭ, ДЕМО, ДЭМО) от 2025 года по специальности 09.02.06 Сетевое и системное администрирование. Все задания выполнялись удалённо на машинах с установленной ОС ALT Linux и развёрнутых на Proxmox стендах предоставленных Аэрокосмическим колледжем при Сибирском государственном университете науки и технологий имени академика М.Ф. Решетнёва базирующемся в городе Красноярск. Надеюсь, что моя работа поможет как можно более широкому кругу молодых специалистов, что уже сдают или ещё будут сдавать этот экзамен.**

---
# Схема сети:

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/scheme.png" width="360" height="480">

---
# Таблица адресации:

|  **Имя**   | **Сегмент** |    **Адрес**    |  **Шлюз**   |
| :--------: | :---------: | :-------------: | :---------: |
|  **ISP**   |  Internet   |      DHCP       |     NAT     |
|  **ISP**   |     HQ      | 172.16.4.14/28  |      -      |
|  **ISP**   |     BR      | 172.16.5.14/28  |      -      |
| **HQ-RTR** |     ISP     |  172.16.4.1/28  | 172.16.4.14 |
| **HQ-RTR** |     SRV     |  10.1.1.62/26   |      -      |
| **HQ-RTR** |     CLI     |  10.1.1.78/28   |      -      |
| **BR-RTR** |     ISP     |  172.16.5.1/28  | 172.16.5.14 |
| **BR-RTR** |     SRV     |  10.2.2.30/27   |      -      |
| **HQ-SRV** |     RTR     |   10.1.1.1/26   |  10.1.1.62  |
| **BR-SR**  |     RTR     |   10.2.2.1/27   |  10.2.2.30  |
| **HQ-CLI** |     RTR     | 10.1.1.65-77/28 |  10.1.1.78  |

---
# Содержание:
- [**Модуль №1:**](#модуль-1)  
  ‎ 1. [Конфигурация и адресация](#1-конфигурация-и-адресация)  
  ‎ 2. [VLAN и DHCP](#2-vlan-и-dhcp)  
  ‎ 3. [GRE и OSPF](#3-gre-и-ospf)  
  ‎ 4. [SSH](#4-ssh)  
  ‎ 5. [DNS](#5-dns)  
- [**Модуль №2:**](#модуль-2)  
  ‎ 1. [RAID и NFS](#1-raid-и-nfs)  
  ‎ 2. [Chrony](#2-chrony)  
  ‎ 3. [Ansible и Yandex](#3-ansible-и-yandex)  
  ‎ 4. [MediaWiki в Docker](#4-mediawiki-в-docker)  
  ‎ 5. [Moodle на Apache](#5-moodle-на-apache)  
  ‎ 6. [DNAT и NGINX](#6-dnat-и-nginx)  
  ‎ 7. [Samba DC](#7-samba-dc)  
- [**Проверка:**](#проверка)  
  ‎ 1. [ISP](#1-isp)  
  ‎ 2. [HQ-RTR](#2-hq-rtr)  
  ‎ 3. [BR-RTR](#3-br-rtr)  
  ‎ 4. [HQ-SRV](#4-hq-srv)  
  ‎ 5. [BR-SRV](#5-br-srv)  
  ‎ 6. [HQ-CLI](#6-hq-cli)
  
---
## **Модуль №1:**
### 1. Конфигурация и адресация:
**На ISP, HQ-RTR, BR-RTR пересылка пакетов:**
```
nano /etc/net/sysctl.conf

    net.ipv4.ip_forward = 1
```
**На них же ставим NAT на красный:**
```
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
iptables-save >> /etc/sysconfig/iptables
systemctl enable --now iptables
```
**На всех часовой пояс:**
```
timedatectl set-timezone Asia/Krasnoyarsk
```
**На всех имена свои:**
```
hostnamectl set-hostname hq-rtr.au-team.irpo ; exec bash
nano /etc/sysconfig/network

    HOSTNAME=br-rtr.au-team.irpo
```
**На всех синих адреса свои:**
```
nano ens18/options

    На месте обоих слов dhcp и dhcp4 ставим слово static

nano ens18/ipv4address

    172.16.5.1/28
```
**Ко всем красным шлюзы свои:**
```
nano ens18/ipv4route

    default via 172.16.5.14
```
**На всех:**
```
systemctl restart network
ip -c -br a
ip -c -br r
```
**Больше ISP не трогаем**
### 2. VLAN и DHCP:
**HQ-RTR на сабах:**
```
mkdir ens19.100/
nano ens19.100/options

    TYPE=vlan
    HOST=ens19
    VID=100
    BOOTPROTO=static

nano ens19.100/ipv4address

    10.1.1.62/26

systemctl restart network
```
**На нём же раздача DHCP, клиенту иногда нужна перезагрузка:**
```
apt-get update && apt-get install -y dnsmasq
systemctl enable --now dnsmasq
nano /etc/dnsmasq.conf

    no-resolv
    domain=au-team.irpo
    dhcp-range=10.1.1.65,10.1.1.77,999h
    dhcp-option=3,10.1.1.78
    dhcp-option=6,10.1.1.1
    dhcp-option=15,au-team.irpo
    interface=ens19.200

systemctl restart dnsmasq
```
### 3. GRE и OSPF:
**На HQ-RTR:**
```
mkdir tun0
nano tun0/options

    TYPE=iptun
    TUNTYPE=gre
    TUNLOCAL=172.16.4.1
    TUNREMOTE=172.16.5.1
    TUNTTL=64
    TUNOPTIONS='ttl 64'
    HOST=ens18

nano tun0/ipv4address

    10.10.10.1/30

modprobe gre
systemctl restart network
```
**На BR-RTR:**
```
mkdir tun0
nano tun0/options

    TYPE=iptun
    TUNTYPE=gre
    TUNLOCAL=172.16.5.1
    TUNREMOTE=172.16.4.1
    TUNTTL=64
    TUNOPTIONS='ttl 64'
    HOST=ens18

nano tun0/ipv4address

    10.10.10.2/30

modprobe gre
systemctl restart network
```
**Возвращаемся на HQ-RTR:**
```
apt-get install -y frr
nano /etc/frr/daemons

    Находим и меняем ospfd=no на ospfd=yes

systemctl daemon-reload
systemctl enable --now frr
vtysh

    conf
    router ospf
    network 10.1.1.0/26 area 0
    network 10.1.1.64/28 area 0
    network 10.10.10.0/30 area 0
    exit
    int tun0
    ip ospf authentication message-digest
    ip ospf message-digest-key 1 md5 P@ssw0rd
    do wr
    exit

systemctl restart frr
```
**Возвращаемся на BR-RTR:**
```
apt-get update && apt-get install -y frr
nano /etc/frr/daemons

    Находим и меняем ospfd=no на ospfd=yes

systemctl daemon-reload
systemctl enable --now frr
vtysh

    conf
    router ospf
    network 10.2.2.0/27 area 0
    network 10.10.10.0/30 area 0
    exit
    int tun0
    ip ospf authentication message-digest
    ip ospf message-digest-key 1 md5 P@ssw0rd
    do wr
    exit

systemctl restart frr
```
### 4. SSH:
**На HQ-SRV и BR-SRV:**
```
useradd -u 1010 -m sshuser
passwd sshuser

    P@ssw0rd

gpasswd -a sshuser wheel
EDITOR=nano visudo

    sshuser ALL=(ALL) NOPASSWD: ALL

nano /etc/openssh/sshd_config

    Port 2024
    PermitRootLogin no
    AllowUsers sshuser
    MaxAuthTries 2
    Banner /etc/openssh/banner

nano /etc/openssh/banner

    Authorized access only

systemctl restart sshd
```
**На HQ-RTR и BR-RTR:**
```
useradd -m net_admin
passwd net_admin

    P@$$word

gpasswd -a net_admin wheel
EDITOR=nano visudo

    net_admin ALL=(ALL) NOPASSWD: ALL

nano /etc/openssh/sshd_config

    Port 2024
    PermitRootLogin no

systemctl restart sshd
```
**На HQ-CLI:**
```
nano /etc/openssh/sshd_config

    Port 2024
    PermitRootLogin no

systemctl enable --now sshd
```
### 5. DNS:
**На HQ-SRV:**
```
wget raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/dnsmasq.conf
apt-get update && apt-get install -y dnsmasq wget
systemctl enable --now dnsmasq
rm -rf /etc/dnsmasq.conf
cp -r dnsmasq.conf /etc/
nano /etc/dnsmasq.conf

    Меняем оба адреса клиента на свой

systemctl restart dnsmasq
```
**На нём же:**
```
nano /etc/hosts

    10.1.1.62 hq-rtr.au-team.irpo

nano /etc/resolv.conf

    nameserver 127.0.0.1
    search au-team.irpo

chattr +i /etc/resolv.conf
```
**На BR-SRV:**
```
nano /etc/resolv.conf

    nameserver 10.1.1.1
    nameserver 127.0.0.1
    search au-team.irpo

chattr +i /etc/resolv.conf
```
**На HQ-RTR и BR-RTR:**
```
nano /etc/resolv.conf

    nameserver 10.1.1.1
    search au-team.irpo

chattr +i /etc/resolv.conf
```
**Готово.**

---
## **Модуль №2:**
### 1. RAID и NFS:
 **На HQ-SRV:**
 ```
mdadm --create --verbose /dev/md0 -l 5 -n 3 /dev/sd[b-d]
mdadm --detail -scan > /etc/mdadm.conf
fdisk /dev/md0

    n
    	Кликаем до самого конца Enter
    w

mkfs.ext4 /dev/md0p1
mkdir /raid5
nano /etc/fstab

    /dev/md0p1 /raid5 ext4 defaults 0 0

mount -a
apt-get install -y nfs-server
systemctl enable --now nfs
mkdir /raid5/nfs
chown -R 99:99 /raid5/nfs
chmod 777 /raid5/nfs
nano /etc/exports

    /raid5/nfs 10.1.1.64/28(rw,sync,no_subtree_check)

systemctl restart nfs
touch /raid5/nfs/test
```
**На HQ-CLI:**
```
mkdir /mnt/nfs
nano /etc/fstab

    10.1.1.1:/raid5/nfs /mnt/nfs nfs rw 0 0

mount -a
ls /mnt/nfs
```
### 2. Chrony:
**На HQ-RTR находим и стираем строку pool в самом низу, после добавляем:**
```
nano /etc/chrony.conf

    local stratum 5
    allow 0/0

systemctl restart chronyd
```
**На всех остальных:**
```
nano /etc/chrony.conf

    Находим и меняем pool на pool hq-rtr iburst

systemctl restart chronyd
```
### 3. Ansible:
**На BR-SRV:**
```
apt-get update && apt-get install -y ansible sshpass wget
cd /etc/ansible
wget raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/inventory.yml
nano inventory.yml

    Меняем адрес клиента на свой

nano ansibe.cfg

    interpreter_python = /usr/bin/python3
    inventory = /etc/ansible/inventory.yml
    host_key_checking = false

ansible -m ping all
```
### 4. MediaWiki в Docker:
**На BR-SRV:**
```
apt-get install -y docker-engine docker-compose
systemctl enable --now docker
usermod user -aG docker
wget raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/wiki.yml
mv wiki.yml /home/user
cd /home/user
docker compose -f wiki.yml up -d
```
**В консоли, а затем в браузере на HQ-CLI:**
```
apt-get update && apt-get install -y yandex-browser-stable

    10.2.2.1:8080
    
    Set up the wiki
	
    Далее ->
	
    Далее ->
```
**Имя пользователя базы данных = wiki, а пароль = WikiP@ssw0rd:**

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/wiki1.png">

```
    ☑ Использовать ту же учётную запись
    Далее ->
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/wiki2.png">

```
    Далее ->
    
    Далее ->
    
scp -P 2024 /home/user/Загрузки/LocalSettings.php sshuser@10.2.2.1:/home/sshuser
```
**Возвращаемся на BR-SRV:**
```
mv /home/sshuser/LocalSettings.php /home/user
nano wiki.yml

    Раскомментируем строку

docker compose -f wiki.yml up -d
```
**Возвращаемся в браузер на HQ-CLI:**
```
    10.2.2.1:8080
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/wiki3.png">

### 5. Moodle на Apache:
**На HQ-SRV:**
```
apt-get install -y moodle moodle-apache2 moodle-local-mysql
systemctl enable --now mariadb
systemctl enable --now httpd2
mysql -u root

    CREATE DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    GRANT ALL ON moodle.* TO 'moodle'@'localhost' IDENTIFIED BY 'P@ssw0rd';
    FLUSH PRIVILEGES;
    EXIT

systemctl restart httpd2
systemctl restart mariadb
```
**В браузере на HQ-CLI:**
```
    10.1.1.1/moodle

    Русский (ru)
    Далее >>
    
    Далее >>
    
    MariaDB ("родной"/mariadb)
    Далее >>
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/moodle1.png">

```
    Далее >>
	
    Продолжить
```
**Возвращаемся на HQ-SRV:**
```
nano /etc/php/8.2/apache2-mod_php/php.ini

    Ищем, раскомментируем, меняем на max_input_vars = 6000

systemctl restart httpd2
```
**Возвращаемся в браузер на HQ-CLI и обновляем страницу**:
```
    Продолжить
    
    Продолжить
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/moodle2.png">

```
    Обновить профиль

    Полное название - № вашего места
    Краткое название - № вашего места
    Описание главной - № вашего места
    Часовой пояс - Азия/Красноярск
    Электронная почта - qwe@asd.zxc
	
    Сохранить изменения
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/moodle3.png">

### 6. DNAT и NGINX:
**На BR-RTR:**
```
iptables -t nat -A PREROUTING -p tcp -d 10.2.2.30 --dport 80 -j DNAT --to-destination 10.2.2.1:8080
iptables -t nat -A PREROUTING -p tcp -d 10.2.2.30 --dport 2024 -j DNAT --to-destination 10.2.2.1:2024
iptables-save > /etc/sysconfig/iptables
systemctl restart iptables
```
**На HQ-RTR:**
```
iptables -t nat -A PREROUTING -p tcp -d 10.1.1.62 --dport 2024 -j DNAT --to-destination 10.1.1.1:2024
iptables-save > /etc/sysconfig/iptables
systemctl restart iptables
```
**На HQ-SRV находим и меняем:**
```
nano /var/www/webapps/moodle/config.php

    $CFG->wwwroot = 'http://moodle.au-team.irpo/moodle';

systemctl restart httpd2
systemctl restart mariadb
```
**Возвращаемся на HQ-RTR:**
```
apt-get install -y nginx wget
cd /etc/nginx/conf-available.d/
wget raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/revproxy.conf
rm -rf /etc/nginx/sites-available.d/default.conf
ln -s /etc/nginx/conf-available.d/revproxy.conf /etc/nginx/sites-enabled.d
ls -la /etc/nginx/sites-enabled.d
systemctl restart nginx
```
**В браузере на HQ-CLI:**
```
    http://wiki.au-team.irpo
    http://moodle.au-team.irpo
```
### 7. Samba DC:
**На BR-SRV:**
```
apt-get install -y task-samba-dc
rm -rf /etc/samba/smb.conf
nano /etc/hosts

    10.2.2.1	br-srv.au-team.irpo
```
**На HQ-SRV:**
```
nano /etc/dnsmasq.conf

    server=/au-team.irpo/10.2.2.1

systemctl restart dnsmasq
```
**Возвращаемся BR-SRV:**
```
samba-tool domain provision

    AU-TEAM.IRPO
    AU-TEAM
    dc
    SAMBA_INTERNAL
    10.1.1.1
    P@ssw0rd

mv -f /var/lib/samba/private/krb5.conf /etc/krb5.conf
systemctl enable samba

reboot

samba-tool user add user1.hq P@ssw0rd
samba-tool user add user2.hq P@ssw0rd
samba-tool user add user3.hq P@ssw0rd
samba-tool user add user4.hq P@ssw0rd
samba-tool user add user5.hq P@ssw0rd
samba-tool group add hq
samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq
```
**На HQ-CLI:**

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/samba1.png">

```
Центр управления системой

    toor

Пользователи -> Аутентификация
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/samba2.png">

```
Применить

    Да

```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/samba3.png">

```
    ОК

reboot
```
**Снова на BR-SRV:**
```
apt-repo add rpm http://altrepo.ru/local-p10 noarch local-p10
apt-get update && apt-get install -y sudo-samba-schema
sudo-schema-apply

    Yes
    
    Логин: Administrator
    Пароль: P@ssw0rd
	
    ОК

create-sudo-rule

    OU:			OU=sudoers,dc=AU-TEAM,dc=IRPO
    Имя правила:	hq-rules
    sudoHost		ALL
    sudoCommand:	/bin/cat
    sudoUser:	    	%hq

    ОК
```
**Возвращаемся на HQ-CLI:**
```
apt-get install -y admc
kinit administrator

    P@ssw0rd

admc
```

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/samba4.png">

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/samba5.png">

<img src="https://raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/images/samba6.png">

```
    Применить
    Ок

apt-get install -y sudo libsss_sudo
control sudo public
```
**Ищем и добавляем:**
```
nano /etc/sssd/sssd.conf

    services = nss,pam,sudo

    id_provider = ad
    sudo_provider = ad

nano /etc/nsswitch.conf

    gshadow: files
    sudoers: files sss

reboot

rm -rf /var/lib/ssd/db/*
sss_cache -E
systemctl restart sssd
```
**Опять на BR-SRV, но на экзамене архив уже лежит там:**
```
cd /opt
wget raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/Users.zip
unzip Users.zip
wget raw.githubusercontent.com/delmimalta/sdemo25/refs/heads/main/import.sh
chmod +x import.sh
bash import.sh
```
**Снова на HQ-CLI:**
```
nano /etc/chrony.conf

    Опять находим и меняем pool на pool hq-rtr iburst
	
chattr +i /etc/chrony.conf
```
**Готово.**

---
## **Проверка:**
### 1. ISP:
```
hostname
cat /etc/sysconfig/network
cat /etc/sysconfig/iptables
cat /proc/sys/net/ipv4/ip_forward
ip -c -br a
```
### 2. HQ-RTR:
```
hostname
cat /etc/sysconfig/network
cat /etc/sysconfig/iptables
cat /proc/sys/net/ipv4/ip_forward
ip -c -br a
ip -c -br r
ping google.com
tracepath br-srv
chronyc clients
```
### 3. BR-RTR:
```
hostname
cat /etc/sysconfig/network
cat /etc/sysconfig/iptables
cat /proc/sys/net/ipv4/ip_forward
ip -c -br a
ip -c -br r
ping google.com
tracepath hq-srv
```
### 4. HQ-SRV:
```
hostname
cat /etc/sysconfig/network
ip -c -br a
ip -c -br r
ping google.com
tracepath br-srv
lsblk
cat /etc/mdadm.conf
exportfs
```
### 5. BR-SRV:
```
hostname
cat /etc/sysconfig/network
ip -c -br a
ip -c -br r
ping google.com
tracepath hq-srv
ansible -m ping all
docker ps -a
samba-tool domain info 127.0.0.1
samba-tool user list
```
### 6. HQ-CLI:
```
hostname
cat /etc/sysconfig/network
ip -c -br a
ip -c -br r
ping google.com
tracepath br-srv
ssh -p 2024 sshuser@10.1.1.62

    id
    sudo whoami

ssh -p 2024 sshuser@10.2.2.30

    id
    sudo whoami

ssh -p 2024 net_amdin@10.1.1.62

    sudo whoami
	
ssh -p 2024 net_admin@10.2.2.30

    sudo whoami	

ls /mnt/nfs
chronyc tracking
rpm -q yandex-browser-stable
sudo -l -U user1.hq
```
**В браузере:**
```
    10.2.2.30
    10.1.1.1/moodle

    http://wiki.au-team.irpo/
    http://moodle.au-team.irpo/
```
**Заходим под созданным пользователем:**
```
    user1.hq
    P@ssw0rd

sudo cat /etc/passwd | sudo grep root
sudo id root
```
**Заходим под импортированным пользователем:**
```
    joseph.wise
    P@ssw0rd
```
**Готово.**
