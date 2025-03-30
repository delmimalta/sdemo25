#!/bin/bash

# Очистим все правила перед применением новых
iptables -F
iptables -t nat -F
iptables -X

# Установим политику по умолчанию - DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешим loopback интерфейс (для локальных соединений)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешим входящий трафик для SSH
iptables -A INPUT -p tcp --dport 19122 -j ACCEPT

# Разрешим входящий трафик для NTP (Chrony)
iptables -A INPUT -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -p udp --sport 123 -j ACCEPT

# Разрешим входящий трафик для NFS
iptables -A INPUT -p tcp --dport 2049 -j ACCEPT      # NFS порт
iptables -A INPUT -p udp --dport 111 -j ACCEPT       # RPC
iptables -A INPUT -p tcp --dport 111 -j ACCEPT       # RPC
iptables -A INPUT -p tcp --dport 20048 -j ACCEPT     # NFS mountd

# Разрешим порты для Samba (DC и DNS)
iptables -A INPUT -p udp --dport 137 -j ACCEPT       # NetBIOS Name Service
iptables -A INPUT -p udp --dport 138 -j ACCEPT       # NetBIOS Datagram Service
iptables -A INPUT -p tcp --dport 139 -j ACCEPT       # NetBIOS Session Service
iptables -A INPUT -p tcp --dport 445 -j ACCEPT       # Microsoft-DS
iptables -A INPUT -p udp --dport 53 -j ACCEPT        # DNS запросы

# Разрешим порты для Zabbix
iptables -A INPUT -p tcp --dport 10051 -j ACCEPT     # Zabbix сервер
iptables -A INPUT -p tcp --dport 10050 -j ACCEPT     # Zabbix агент
iptables -A INPUT -p tcp --dport 80 -j ACCEPT        # HTTP (если используется веб-интерфейс)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT       # HTTPS (если используется веб-интерфейс)

# Разрешим исходящий трафик для всех соединений, связанных с сервером
iptables -A OUTPUT -j ACCEPT

# Разрешим ICMP (ping)
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# Логи для неразрешённого трафика (для анализа)
iptables -A INPUT -j LOG --log-prefix "IPTABLES INPUT DENY: "
iptables -A OUTPUT -j LOG --log-prefix "IPTABLES OUTPUT DENY: "
