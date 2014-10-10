#!/bin/sh.distrib
# ---
# Vyatta Core HA Cluster autoconfig script
# for VyattaCore6.6 with AmazonWebServices
# ---
# (c)cloudpack http://cloudpack.jp/
# 2014.10.10 Akira Tsumura < tsumura@cloudpack.jp >
#
# This code provided AS-IS and non-support. 


### System Validate
prog=${0}

### HELP
if [ "$1" = "-h" ]; then
 echo "usage : $prog [--nodownload] [-h]"
 echo "--nodownload is skip download pythons and awscli."
 echo "--configonly is skip download and install awscli"
 echo "-h is this."
 exit
fi

### Configure
_TMP='/home/vyatta/tmp'
_CONFIG='/etc/sysconfig'
_SCRIPT='/opt/cloudpack'
_FAILOVER='/etc/init.d/failover'
_PROFILE='/etc/profile.d/awscli.sh'
_AWS_CONFIG_DIR='/root/.aws'

_AWS_CONFIG_FILE=`echo ${_AWS_CONFIG_DIR}/credentials`
_TMP_FILE=`echo ${_TMP}/$$.tmp`

_LOCAL_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

if [ "$_LOCAL_IP" = "" ]; then
 echo "****************"
 echo "Not working EC2."
 echo "****************"
 exit
fi

### Delete work Directory
if [ -d $_TMP -o -f $_TMP ]; then
 sudo rm -rf $_TMP
fi

### Make Directory
sudo mkdir -p $_CONFIG
sudo mkdir -p $_SCRIPT
sudo mkdir -p $_AWS_CONFIG_DIR
mkdir -p $_TMP
cd $_TMP

### Download awscli
if [ "$1" != "--nodownload" -o "$1" != "--configonly" ]; then
 curl -OL https://pypi.python.org/packages/2.6/s/setuptools/setuptools-0.6c11-py2.6.egg ;\
 curl -OL https://pypi.python.org/packages/source/a/awscli/awscli-0.13.2.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/d/docutils/docutils-0.11.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/a/argparse/argparse-1.1.zip ;\
 curl -OL https://pypi.python.org/packages/source/c/colorama/colorama-0.2.5.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/s/six/six-1.3.0.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/b/bcdoc/bcdoc-0.5.0.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/b/botocore/botocore-0.13.1.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/s/simplejson/simplejson-3.3.0.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/o/ordereddict/ordereddict-1.1.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/p/python-dateutil/python-dateutil-2.1.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/j/jmespath/jmespath-0.0.2.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/p/ply/ply-3.4.tar.gz ;\
 curl -OL https://pypi.python.org/packages/source/r/requests/requests-1.2.0.tar.gz
fi

### Install awscli
if [ "$1" != "--configonly" ]; then
sudo sh.distrib setuptools-0.6c11-py2.6.egg
sudo easy_install docutils-0.11.tar.gz
sudo easy_install argparse-1.1.zip
sudo easy_install colorama-0.2.5.tar.gz
sudo easy_install six-1.3.0.tar.gz
sudo easy_install bcdoc-0.5.0.tar.gz
sudo easy_install simplejson-3.3.0.tar.gz
sudo easy_install ordereddict-1.1.tar.gz
sudo easy_install python-dateutil-2.1.tar.gz
sudo easy_install ply-3.4.tar.gz
sudo easy_install jmespath-0.0.2.tar.gz
sudo easy_install requests-1.2.0.tar.gz
sudo easy_install botocore-0.13.1.tar.gz
sudo easy_install awscli-0.13.2.tar.gz
fi

### Make /etc/profile.d/awscli.sh
cat << '_EOF_' > $_TMP_FILE
if [ -x /usr/local/bin/aws ]; then
    AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    export AWS_DEFAULT_REGION=`echo $AZ | cut -c 1-$((${#AZ} - 1))`
    complete -C aws_completer aws
fi
if [ -f __AWSCONF__ ]; then
    export AWS_CONFIG_FILE=__AWSCONF__
fi
_EOF_

cat $_TMP_FILE \
 | sed -e "s|__AWSCONF__|$_AWS_CONFIG_FILE|g" \
 | sed -e "s|__SCRIPT__|$_SCRIPT|g" \
 | sed -e "s|__CONFIG__|$_CONFIG|g" \
 > $_TMP/awscli.sh
sudo chown root:root $_TMP/awscli.sh
sudo chmod +x $_TMP/awscli.sh
sudo cp -prv $_TMP/awscli.sh $_PROFILE

### Make /etc/sysconfig/associate-nat
cat << '_EOF_' > $_TMP_FILE
#!/bin/sh.distrib
#
# description: Associate NAT

# System Variable
prog=${0##*/}

# export aws config
if [ -f __AWSCONF__ ]; then
 export AWS_CONFIG_FILE=__AWSCONF__
fi

# User Variavle
ROUTE_TABLE_ID=""
DESTINATION_CIDR="0.0.0.0/0"

# Source Config
if [ -f __CONFIG__/$prog ] ; then
    . __CONFIG__/$prog
fi

# Check Config
if [ "$ROUTE_TABLE_ID" = "" ]; then
 echo "Not Configure ROUTE_TABLE_ID" | logger -s -i -t $prog
 echo "Edit __CONFIG__/$prog" | logger -s -i -t $prog
 exit
fi

if [ "$DESTINATION_CIDR" = "" ]; then
 echo "Not Configure DESTINATION_CIDR" | logger -s -i -t $prog
 echo "Edit __CONFIG__/$prog" | logger -s -i -t $prog
 exit
fi

# Failover
AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
REGION=`echo $AZ | cut -c 1-$((${#AZ} - 1))`
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
aws --region $REGION ec2 replace-route    \
 --destination-cidr-block $DESTINATION_CIDR \
 --route-table-id         $ROUTE_TABLE_ID  \
 --instance-id            $INSTANCE_ID     \
  | logger -s -i -t $prog
exit
_EOF_

cat $_TMP_FILE \
 | sed -e "s|__AWSCONF__|$_AWS_CONFIG_FILE|g" \
 | sed -e "s|__SCRIPT__|$_SCRIPT|g" \
 | sed -e "s|__CONFIG__|$_CONFIG|g" \
 > $_TMP/associate-nat
sudo chown root:root $_TMP/associate-nat
sudo chmod +x $_TMP/associate-nat
sudo cp -prv $_TMP/associate-nat $_SCRIPT/associate-nat

### Make /etc/sysconfig/associate-nat
cat << '_EOF_' > $_TMP_FILE
# ROUTE_TABLE_ID="rtb-xxx"
# DESTINATION_CIDR="0.0.0.0/0"
# * pre-defined route table and CIDR.
_EOF_

cat $_TMP_FILE > $_TMP/conf_associate-nat
sudo chown root:root $_TMP/conf_associate-nat
sudo cp -prv $_TMP/conf_associate-nat $_CONFIG/associate-nat

### Make /opt/cloudpack/associate-eip
cat << '_EOF_' > $_TMP_FILE
#!/bin/sh.distrib
#
# description: Associate EIP

# System Variable
prog=${0##*/}

# export aws config
if [ -f __AWSCONF__ ]; then
 export AWS_CONFIG_FILE=__AWSCONF__
fi

# User Variavle
EIP=""

# Source Config
if [ -f __CONFIG__/$prog ] ; then
    . __CONFIG__/$prog
fi

if [ "$EIP" = "" ]; then
 echo "Not Configure EIP" | logger -s -i -t $prog
 echo "Edit __CONFIG__/$prog" | logger -s -i -t $prog
 exit
fi

# Failover
AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
REGION=`echo $AZ | cut -c 1-$((${#AZ} - 1))`
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

# DisAssociate EIP
aws \
 --region $REGION ec2 disassociate-address \
 --public-ip $EIP \
  | logger -s -i -t $prog

# Associate EIP
aws \
 --region $REGION ec2 associate-address \
 --instance-id $INSTANCE_ID     \
 --public-ip $EIP \
  | logger -s -i -t $prog

exit
_EOF_

cat $_TMP_FILE \
 | sed -e "s|__AWSCONF__|$_AWS_CONFIG_FILE|g" \
 | sed -e "s|__SCRIPT__|$_SCRIPT|g" \
 | sed -e "s|__CONFIG__|$_CONFIG|g" \
  > $_TMP/associate-eip

sudo chown root:root $_TMP/associate-eip
sudo chmod +x $_TMP/associate-eip
sudo cp -prv $_TMP/associate-eip $_SCRIPT/associate-eip

### Make /etc/syscofig/associate-eip
cat << '_EOF_' > $_TMP_FILE
# EIP=""
# * EIP is IPv4 Addr
_EOF_
cat $_TMP_FILE > $_TMP/conf_associate-eip
sudo chown root:root $_TMP/conf_associate-eip
sudo cp -prv $_TMP/conf_associate-eip $_CONFIG/associate-eip

### Make Failover Script
cat << '_EOF_' > $_TMP/failover
# /opt/cloudpack/associate-eip
# /opt/cloudpack/associate-nat
_EOF_

sudo chown root:root $_TMP/failover
sudo chmod +x $_TMP/failover
sudo cp -prv $_TMP/failover $_FAILOVER

### Make Credentials 
cat << '_EOF_' > $_TMP_FILE
[default]
aws_access_key_id=(Access Key)
aws_secret_access_key=(Secret Access Key)
region=ap-northeast-1
# region=ap-southeast-1
# region=ap-southeast-2
# region=eu-west-1
# region=sa-east-1
# region=us-east-1
# region=us-west-1
# region=us-west-2
_EOF_

cat $_TMP_FILE > $_TMP/credentials
sudo chown root:root $_TMP/credentials
sudo chmod +x $_TMP/credentials
sudo cp -prv $_TMP/credentials $_AWS_CONFIG_FILE

### END Message
cat << '_EOF_' | sed -e "s/_LOCALIP_/$_LOCAL_IP/g"

**************************
*** CONFIGURE COMPLETE ***
**************************

Can use aws-cli after re-login vyatta user.
Please edit setting files.
o /root/.aws/credentials - AWSCLI config.
o /etc/sysconfig/associate-eip - EIP Failover config.
o /etc/sysconfig/associate-nat - ROUTE TABLE Failover config.
o /etc/init.d/failover - Failover Script.

Edit AWSCLI credentials file first.
If use IAM role, delete credentials file.

Vyatta clustering sample config on vpc.
o vyatta-a - Primary 169.254.0.1/30
o vyatta-c - Secondary 169.254.0.2/30
* local-ip is this instanse ip addr.
---
set system host-name vyatta-a
set interfaces tunnel tun00 address '169.254.0.[1-2]/30'
set interfaces tunnel tun00 encapsulation 'gre'
set interfaces tunnel tun00 local-ip '_LOCALIP_'
set interfaces tunnel tun00 remote-ip '[Peer LocalIP]'
set interfaces tunnel tun00 multicast enable
 
set cluster interface tun00
set cluster pre-shared-secret cloudpack
set cluster group aws
set cluster group aws primary vyatta-a
set cluster group aws secondary vyatta-c
---

_EOF_

exit

# This code is my first project.
# I want pull reqests.
# Have a nice HACK! :)
