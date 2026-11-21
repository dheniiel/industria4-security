FROM ubuntu:24.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        iptables net-tools iproute2 iputils-ping \
        openssh-server openssh-client gnupg cron \
        python3 curl nmap \
        telnet ftp rsh-redone-client \
    && mkdir -p /run/sshd

# Scripts de segurança do servidor Ubuntu (firewall, hardening e integridade)
COPY gateway/ /opt/seguranca/
RUN chmod 700 /opt/seguranca /opt/seguranca/*.sh

# Scripts de inicialização de cada contêiner (chamados pelo "command" do docker-compose)
COPY inicializacao/ /opt/inicializacao/
RUN chmod 700 /opt/inicializacao /opt/inicializacao/*.sh
