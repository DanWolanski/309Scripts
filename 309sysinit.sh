#!/bin/bash
# This script will help build up a Application Server for use
#   with the dialogic powermedia XMS JSR309 Service

starttime=`date +"%Y-%m-%d_%H-%M-%S"`
scriptname=$0
STARTPWD=$(pwd)
LOG=${STARTPWD}/309sysinit.log
EXITONFAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
OFFSET='\033[60G'
echo_success(){
  echo -en \\033
  echo -en "${OFFSET}[  ${GREEN}OK${NC}  ]\n";
  echo -e "\n**** Step SUCCESS ****\n\n" >> $LOG
}
echo_failure(){
echo -en "${OFFSET}[${RED}FAILED${NC}]\n";
echo -e "\n**** Step FAILURE ****\n\n" >> $LOG
}
step() {
	ERRCOUNT=0
	echo "===========================================================================================" >> $LOG
	echo "====   Step - $@" >> $LOG
	echo "===========================================================================================" >> $LOG
    echo -n -e "$@"
	logger -t "$scriptname" "$@"
	
}
try (){
    $@ &>> $LOG 
    if [[ $? -ne 0 ]] ; then 
		echo "ERROR!!" &>> $LOG
		let ERRCOUNT+=1
     fi
}

next (){
    
    if [[ $ERRCOUNT -ne 0 ]] ; then 
		echo_failure  
     else 
		echo_success 
     fi
	ERRCOUNT=0
}
log(){
    echo -e "$@" |& tee -a $LOG
}
echo
###########################################################################
#######                Start of script                             ########
####i#######################################################################
echo "Starting $scriptname @ $startime" > $LOG
logger -t "${scriptname}" "Starting 309 System Initilization via $scriptname script"

ASTYPE='occas7'
INSTALLGNOME='false'
USERNAME='appserver'
USERPASS='Demo17!!'
JDKVER='jdk8'

while getopts 'ojdu:p:' flag; do
  case "${flag}" in
    o) ASTYPE='occas7' 
	USERNAME='occas7'
	INSTALLGNOME='true'
	JDKVER='jdk8'
	;;
    j) ASTYPE='jboss' 
	USERNAME='jboss'
	JDKVER='jdk7'
	;;
    p) USERPASS="${OPTARG}"
    #   log "Setting Password to ${USERPASS}"
       
	;;
    u) USERNAME="${OPTARG}"
    #   log "Setting user to ${USERNAME}"
	
	;;
    d) log "Setting to install desktop"
	INSTALLGNOME='true'
	;;
    *) error "Unexpected option ${flag}" ;;
  esac
done
log "Setting system env to install $ASTYPE"

if [ $INSTALLGNOME == "true" ] ; then
step "Installing GNOME Desktop"
yum -y groups install "GNOME Desktop"  &>> $LOG
next

step "Issuing startx to complete install"
startx
next

step "Configuring Desktop to start on restart"
try systemctl set-default graphical.target
next
fi

log "Install other system Packages"
PACKAGELIST="vim wget unzip expect nmap abrt tcpdump omping sysstat nc net-tools perl mlocate"
for PACKAGE in $PACKAGELIST
do
	step "    Installing $PACKAGE"
	try yum -y install $PACKAGE 
	next;
done

#update the mlocate db
try updatedb

echo
step "Updating the kernel via yum"
yum -y update kernel &>> $LOG
next;
log "         *********************************************************"
log -e "             ${RED}Note- kernel update requires a system restart${NC}"
log "         *********************************************************"

step "Performing yum update"
yum -y update &>> $LOG
next;


log "Adding TCP firewall exclusions rules"
TCPPORTS="5060 5061 7001 7002 8080 9990 5080 8787"
for PORT in $TCPPORTS
do
step "    $PORT"
try firewall-cmd --permanent --add-port=${PORT}/tcp
next
done

log "Adding UDP firewall exclusions rules"
UDPPORTS="5060 5061 7001 7002 5080 "
for PORT in $UDPPORTS
do
step "    $PORT"
try firewall-cmd --permanent --add-port=${PORT}/udp
next
done

step "Reloading firewall"
try firewall-cmd --reload
try firewall-cmd --list-ports
next

step "Updating /etc/hosts file"
# Defines
myHostName=$(hostname -s)
myFQDN=$(hostname -f)

# Update the Hostname and /etc/hosts
# Replacing whole hosts file here, maybe appending is better, but easier to just set it to known entity to avoid any issues
# however, based on the finial sed there may be some
try cp /etc/hosts /etc/hosts.backup

myIP=$(hostname -I | cut -d ' ' -f 1)
try `sed  -i "1i ${myIP} ${myHostName} ${myFQDN}" /etc/hosts`
next

step "Updating hostname to shortform (${myHostName})"
#updating the hostname to BASE adress
try echo "${myHostName}" > /etc/hostname
try hostnamectl set-hostname ${myHostName}
next

#step "Restarting network service"
#try service network restart
#next


step "Checking ${USERNAME} user:\n"
if id "${USERNAME}" >/dev/null 2>&1; then
        log -n "   ${USERNAME} user already exists"
else
        log "    Creating user ${USERNAME} "
		useradd ${USERNAME} &>> $LOG
		log -n "    Setting Password for user ${USERNAME}"
		echo ${USERPASS} | passwd ${USERNAME} --stdin &>> $LOG
		
fi
next

step "Fetching ${JDKVER} list from oracle web"
if [ $JDKVER == "jdk8" ] ; then
LATESTJDK=$(curl -s http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html | grep -oP 'http://download.oracle.com/otn-pub/java/jdk/8u.*?/jdk-8u.*?-linux-x64.rpm' | tail -1)
else
LATESTJDK=$(curl -s http://www.oracle.com/technetwork/java/javase/downloads/java-archive-downloads-javase7-521261.html | grep -oP 'http://download.oracle.com/otn/java/jdk/7u.*?/jdk-7u.*?-linux-x64.rpm' | head -1)
fi
next
log "    Latest jdk detected as:" 
log "        $LATESTJDK"
echo 
FILENAME=$(echo $LATESTJDK  | grep -oP "jdk-.u.*?-linux-x64.rpm")

if [ -f $FILENAME ] ; then
	step "$FILENAME found in local directory"
else
	step "Downloading $FILENAME"
	curl -v -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o $FILENAME $LATESTJDK &>> $LOG
fi
next;



step "Yum installing $FILENAME"
yum -y install $FILENAME  &>> $LOG
next;
DETECTEDVER=$(java -version |& grep 'java version')
log "         *********************************************************"
log -e "             ${RED}Detected java -version as: "
log -e "                $DETECTEDVER"
log -e "             If this is not showing as above please update"
log -e "                alternatives --config java "
log -e "                alternatives --config javac ${NC}"
log "         *********************************************************"

step "Setting JAVA_HOME"
if [ -e "/usr/java/latest" ] ;
then
	JAVADIR="/usr/java/latest"
else
	JAVADIR=$( ls -d /usr/java/)
fi

echo "export JAVA_HOME=${JAVADIR}" > /etc/profile.d/javaenv.sh
chmod 0755 /etc/profile.d/javaenv.sh
next
#source the new profile
source /etc/profile
log "         *********************************************************"
log -e "             ${RED}profile will be active next restart"
log -e "             Load it now with   'source /etc/profile'${NC}"
log "         *********************************************************"

logger -t "$scriptname" "Script Complete, See $LOG for more details"
echo
log "Script Complete! "
log "See $LOG for details"
log -e "${RED}Please reboot and log in via ${USERNAME} to continue${NC}"
echo
