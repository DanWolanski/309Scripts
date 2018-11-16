#!/bin/bash
# This script will help build up a Application Server for use
#   with the dialogic powermedia XMS JSR309 Service
starttime=`date +"%Y-%m-%d_%H-%M-%S"`
scriptname=$0
STARTPWD=$(pwd)
LOG=${STARTPWD}/occasinstall.log
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
setpass(){
	echo "Manually setting PASS" &>> $LOG
	let ERRCOUNT+=0
}
setfail(){
	echo "Manually setting FAIL" &>> $LOG
	let ERRCOUNT+=1
}
echo
###########################################################################
#######                Start of script                             ########
####i#######################################################################
echo "Starting $scriptname @ $startime" > $LOG
logger -t "${scriptname}" "Starting OCCAS Install via $scriptname script"

#TODO Add arguments
PWD=$(pwd)

OCCASHOME="/home/occas7/occas"
OCCASRESPONSE="${PWD}/occasresponse.file"
while getopts 'i:d:' flag; do
 case "${flag}" in
	i) MSIP="$OPTARG" 
	log "arg - Media Server IP specified as $OPTARG" ;;
	d) OCCASHOME="$OPTARG" 
	log "arg - OCCAS Home specified as $OCCASHOME" ;;
	r) OCCASRESPONSE="$OPTARG" 
	log "arg - OCCAS Install Response file specified as $OCCASRESPONSE" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done 

#if [ "x$MSIP" = "x" ] ; then
#echo "Please use -i to specify the media service IP for the 309 connector $MSIP"
#exit
#fi

step "Checking current user"
USER=$(whoami)

if [ "$USER" = "root" ] ; then
setfail
next
log "         **************************************************************************"
log "         ${RED}Current User is root - restart as non root user${NC}"
log "         **************************************************************************"
else
setpass
next
log "         **************************************************************************"
log "         ${GREEN}Current user is $USER $OCCASINSTALLER${NC}"
log "         **************************************************************************"
fi

OCCASINSTALLER=$(\ls occas_generic.jar | sort | tail -1)
step "Checking for OCCAS installer file"
if [ -f $OCCASINSTALLER ] ; then
setpass
next
log "         **************************************************************************"
log "         ${GREEN}Found $OCCASINSTALLER${NC}"
log "         **************************************************************************"
else
setfail
next
log "         **************************************************************************"
log "         ${RED}Unable to find occas_generic.jar${NC}"
log "         **************************************************************************"
fi

step "Checking for OCCAS Installer response File"
if [ -f $OCCASRESPONSE ] ; then
setpass
next
log "         **************************************************************************"
log "         ${GREEN}Found $OCCASRESPONSE ${NC}"
log "         **************************************************************************"
else
next
log "         **************************************************************************"
log "         ${GREEN}Did not find, $OCCASRESPONSE $ Creating new{NC}"
log "         **************************************************************************"
step "Creating response file"
cat > ${OCCASRESPONSE} <<EOL
[ENGINE]
Response File Version=1.0.0.0.0
[GENERIC]
ORACLE_HOME=/home/${USER}/occas
INSTALL_TYPE=Converged Application Server
MYORACLESUPPORT_USERNAME=
MYORACLESUPPORT_PASSWORD=<SECURE VALUE>
DECLINE_SECURITY_UPDATES=true
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
PROXY_HOST=
PROXY_PORT=
PROXY_USER=
PROXY_PWD=<SECURE VALUE>
COLLECTOR_SUPPORTHUB_URL=
EOL
setpass
next
fi

step "Creating inventory location file"
setpass
ORAINST="/home/${USER}/oraInst.loc"
cat > $ORAINST <<EOL
inventory_loc=/home/${USER}/oraInventory
inst_group=${USER}
EOL
next


step "Installing Occas"
try java -jar ${OCCASINSTALLER} -ignoreSysPrereqs -novalidation -silent -responseFile ${OCCASRESPONSE} -invPtrLoc ${ORAINST}
next

logger -t "$scriptname" "Script Complete, See $LOG for more details"
echo
log "Script Complete! "
log "See $LOG for details"
echo
