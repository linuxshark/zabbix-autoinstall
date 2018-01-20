#!/bin/bash
#
#INSTALACION DE ZABBIX 3 EN SERVIDOR VIRTUALIZADO DE INFRAESTRUCTURA XSM
#Objetivo:
#
#Instalar plataforma de monitoreo con Zabbix 3 en el servidor de infraestructura USFLA0644
#
#Ambiente base:
#
#Server IP: 172.16.1.64
#Centos 7 con repositorio EPEL 7 activo y disponible. SELINUX y FirewallD desactivados
#
#

vim /etc/selinux/config -- SELINUX=disabled (:X! - para salvar cambios)

setenforce 0

systemctl enable firewalld.service
systemctl restart firewalld.service

firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-service=ssh --permanent
firewall-cmd --zone=public --add-port=10050/tcp --permanent
firewall-cmd --zone=public --add-port=10051/tcp --permanent
firewall-cmd --reload

reboot (init 6)

#### SE PROCEDE A EMPEZAR LA INSTALACIÓN CORRECTA DE UN LAMP (Linux + Apache + MariaDB + PhP)  ####
#
#1.- Instalación de Repos de MariaDB 10.1

cd /etc/yum.repos.d
cat <<EOF >MariaDB.repo
# MariaDB 10.1 CentOS repository list - created 2017-10-20 15:23 UTC by Raúl Linares
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

cd /
yum clean all && yum -y update
yum -y install MariaDB MariaDB-server MariaDB-client galera
yum -y install crudini

#NOTA: MySQL no será instalado en modo seguro ya que es un ambiente productivo privado sin exposición de puertos de base de datos a la red pública
#Creación de archivo oculto para las credenciales de MySQL

echo "" > /etc/my.cnf.d/server-xsm.cnf

crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld binlog_format ROW
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld default-storage-engine innodb
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld innodb_autoinc_lock_mode 2
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld query_cache_type 0
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld query_cache_size 0
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld bind-address 0.0.0.0
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld max_allowed_packet 1024M
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld max_connections 1000
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld innodb_doublewrite 1
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld innodb_log_file_size 100M
crudini --set /etc/my.cnf.d/server-xsm.cnf mysqld innodb_flush_log_at_trx_commit 2
echo "innodb_file_per_table" >> /etc/my.cnf.d/server-xsm.cnf

#Habilitamos y reiniciamos el servicio

systemctl enable mariadb.service
systemctl start mariadb.service

/usr/bin/mysqladmin -u root password "1T5upp0rt"

#Creación de archivo oculto con credenciales de la base de datos

echo "[client]" > /root/.my.cnf
echo "user = "root"" >> /root/.my.cnf
echo "password = \"1T5upp0rt\""  >> /root/.my.cnf 
echo "host = \"localhost\""  >> /root/.my.cnf


#2.- Instalación de dependencias (apache, etc.):

yum -y install php-cli php php-gd php-mysql httpd gd \
perl-Archive-Tar perl-MIME-Lite perl-MIME-tools \
perl-Date-Manip perl-PHP-Serialization \
perl-Archive-Zip perl-Module-Load \
php php-mysql php-pear php-pear-DB php-mbstring \
php-process perl-Time-HiRes perl-Net-SFTP-Foreign \
perl-Expect libjpeg-turbo perl-Convert-BinHex \
perl-Date-Manip perl-DBD-MySQL perl-DBI \
perl-Email-Date-Format perl-IO-stringy perl-IO-Zlib \
perl-MailTools perl-MIME-Lite perl-MIME-tools perl-MIME-Types \
perl-Module-Load perl-Package-Constants \
perl-Time-HiRes perl-TimeDate perl-YAML-Syck php

#3.- Instalación de dependencias para php.ini:

yum -y install zlib-devel glibc-devel curl-devel gcc automake \
libidn-devel openssl-devel net-snmp-devel rpm-devel \
OpenIPMI-devel net-snmp net-snmp-utils php-mysql \
php-gd php-bcmath php-mbstring php-xml nmap php \
MariaDB-devel MariaDB-client

#Se ejecuta el comando siguiente:

ldconfig -v

#Se modifica php.ini via crudini:

crudini --set /etc/php.ini PHP max_execution_time 300
crudini --set /etc/php.ini PHP max_input_time 300
crudini --set /etc/php.ini PHP memory_limit 256M
crudini --set /etc/php.ini PHP date.timezone "America/Caracas"
crudini --set /etc/php.ini PHP mbstring.func_overload 0

#Se reinicia apache:

systemctl enable httpd
systemctl start httpd


#4.- Creación de la BD de zabbix3:

#Usando los siguientes comandos, se crea la BD y usaurio para zabbix3:

mysql -e "CREATE DATABASE zabbixdb default character set utf8;"
mysql -e "GRANT ALL ON zabbixdb.* TO 'zabbixdbuser'@'%' IDENTIFIED BY 'Z@Bb1XdB2017';"
mysql -e "GRANT ALL ON zabbixdb.* TO 'zabbixdbuser'@'127.0.0.1' IDENTIFIED BY 'Z@Bb1XdB2017';"
mysql -e "GRANT ALL ON zabbixdb.* TO 'zabbixdbuser'@'localhost' IDENTIFIED BY 'Z@Bb1XdB2017';"
mysql -e "FLUSH PRIVILEGES;"


#5.- Instalación de Zabbix 3.2

#Se instala el repositorio de zabbix y se ejecuta un update general:

cd /etc/yum.repos.d

rpm -ivh http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm

yum clean all && yum -y update

#NOTA: En caso de un update de kernel, ejecutar un "reboot".

#Se instalan los paquetes de zabbix:

yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent

#Se procede a poblar la base de datos:

mkdir /workdir
cp /usr/share/doc/zabbix-server-mysql-3.2.9/create.sql.gz /workdir
cd /workdir
gunzip create.sql.gz
mysql -u zabbixdbuser -h localhost -pZ@Bb1XdB2017 zabbixdb < /workdir/create.sql

#Se crea el siguiente archivo de sudo:

vim /etc/sudoers.d/zabbix

#Con el contenido:

Defaults:zabbix !requiretty
Defaults:zabbixsrv !requiretty
zabbix ALL=(ALL) NOPASSWD:ALL
zabbixsrv ALL=(ALL) NOPASSWD:ALL

#Y se cambia su permisología:

chmod 0440 /etc/sudoers.d/zabbix

#Se edita el siguiente archivo:

vim /etc/zabbix/zabbix_server.conf

#Se cambian los siguientes parámetros:

DBHost=localhost
DBName=zabbixdb
DBUser=zabbixdbuser
DBPassword=Z@Bb1XdB2017

#Se salva el archivo y se arranca el servicio:

systemctl start zabbix-server.service
systemctl enable zabbix-server.service

systemctl start zabbix-server.service
systemctl enable zabbix-server.service

#Y se recarga apache:

systemctl restart httpd
systemctl enable httpd


#6.- Configuración del módulo WEB de zabbix.
#
#Una vez que el servidor esté activo, se ingresa al URL:
#
#http://172.16.1.64/zabbix
#
#Se hace click a "next" en el wizard hasta llegar a la sección de base de datos. Se colocan la siguiente información:
#
#Database type: mysql
#Database host: localhost
#Database port: 3306
#Database name: zabbixdb
#User: zabbixdbuser
#Password: Z@Bb1XdB2017
#
#Se hace click en next.
#
#En la siguiente pantalla se dejan los datos por defecto (localhost y 10051) pero se coloca en el nombre: XSM Zabbix Server
#
#Se hace click en "next" hasta el final.
#
#Los datos por defecto para ingreso son:
#
#Usuario: Admin
#Password: zabbix
#
#Se hace redirect del default index de apache hacia el aplicativo zabbix
#
#vim /etc/httpd/conf/httpd.conf
#Y en la directiva DocumentRoot cambiar la dirección
#
#DocumentRoot /usr/share/zabbix
#
#Guardar los cambios y salir.
