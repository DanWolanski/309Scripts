#!/bin/bash
# This script will help build up a Application Server for use
#   with the dialogic powermedia XMS JSR309 Service
starttime=`date +"%Y-%m-%d_%H-%M-%S"`
scriptname=$0
STARTPWD=$(pwd)
LOG=${STARTPWD}/JBOSSinstall.log
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
logger -t "${scriptname}" "Starting JBOSS Install via $scriptname script"

#TODO Add arguments
while getopts 'i:w:' flag; do
 case "${flag}" in
	i) MSIP="$OPTARG" ;;
	w) WARFILE="$OPTARG" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done 

if [ "x$MSIP" = "x" ] ; then
echo "Please use -i to specify the media service IP for the 309 connector $MSIP"
exit
fi

JBOSSZIP=$(\ls *jboss-as*.zip | sort | tail -1)
step "Checking for JBOSS Zip file"
if [ -f $JBOSSZIP ] ; then
setpass
next
log "         **************************************************************************"
log "         ${GREEN}Found $JBOSSZIP${NC}"
log "         **************************************************************************"
else
setfail
next
log "         **************************************************************************"
log "         ${RED}Unable to find *jboss-as*.zip${NC}"
log "         **************************************************************************"
fi
next


step "Extracting JBOSS Zip file"
#TODO should check if there and warn
try unzip -o $JBOSSZIP
next

JBOSSHOME=$(basename $JBOSSZIP .zip)
step "Adding JBOSS_HOME to bash_profile"
JBOSS_HOME=${STARTPWD}/${JBOSSHOME}
export JBOSS_HOME
echo "export JBOSS_HOME=${STARTPWD}/${JBOSSHOME}" >> ~/.bash_profile
#source the new profile
source ~/.bash_profile
next
log "         **************************************************************************"
log -e "             ${RED}profile will be active next restart"
log -e "             Load it now with   'source ~/.bash_profile'${NC}"
log "         **************************************************************************"

step "Locating the standalone-sip.xml"
if [ -f ${JBOSS_HOME}/standalone/configuration/standalone-sip.xml ] ; then
setpass
else
setfail
fi
next

step "Making backup copy of standalone-sip.xml"
try cp ${JBOSS_HOME}/standalone/configuration/standalone-sip.xml ${JBOSS_HOME}/standalone/configuration/standalone-sip.xml.backup
next

step "Updating addess information in standalone-sip.xml"
echo "standalone-sip.xml before changes" &>> $LOG
cat ${JBOSS_HOME}/standalone/configuration/standalone-sip.xml &>> $LOG
try sed -i "s/:127.0.0.1/:$(hostname -s)/g" ${JBOSS_HOME}/standalone/configuration/standalone-sip.xml
echo "standalone-sip.xml after changes" &>> $LOG
cat ${JBOSS_HOME}/standalone/configuration/standalone-sip.xml &>> $LOG
next

step "Creating Management user"
${JBOSS_HOME}/bin/add-user.sh --silent=true -u admin -p "Demo17!!" ManagementRealm 

next

#TODO CHeck if there already
step "Adding startjboss alias"
echo "alias startjboss=\"source ~/.bashrc ; source ~/.bash_profile ; ${JBOSS_HOME}/bin/standalone.sh -c standalone-sip.xml\"" >> ~/.bashrc
next


step "Checking for 309 Connector file"
CONNECTORZIP=$(\ls dialogic309*-jboss.tar | sort | tail -1)
if [ -f $CONNECTORZIP ] ; then
setpass
next
log "         **************************************************************************"
log "         ${GREEN}Found $CONNECTORZIP ${NC}"
log "         **************************************************************************"
else
setfail
next
log "         **************************************************************************"
log "         ${RED}Unable to find dialogic309*-jboss.tar${NC}"
log "         **************************************************************************"
fi

step "Unpacking Connector tar file"
try tar -xvf $CONNECTORZIP
next

step "Creating Dialogic Configuration Directoy"
try mkdir ${JBOSS_HOME}/standalone/configuration/Dialogic
next

step "Updating profile for verification config"
echo 'export SAMPLE_PROPERTY_FILE=${JBOSS_HOME}/standalone/configuration/Dialogic/dlgc_sample_demo.properties' >> ~/.bashrc
next

step "Updating standalone.config"
cat << __EOF >> ${JBOSS_HOME}/bin/standalone.conf
### Dialogic additions
JAVA_OPTS="$JAVA_OPTS -Dlog4j.configurationFile=${JBOSS_HOME}/standalone/configuration/Dialogic/log4j2.xml"
### END – Dialogic additions
__EOF
next

step "Copying log4j2.xml"
try cp DlgcJSR309/properties/log4j2.xml ${JBOSS_HOME}/standalone/configuration/Dialogic
next

step "Copying dlgc_sample_demo.properties"
cp DlgcJSR309/properties/dlgc_sample_demo.properties ${JBOSS_HOME}/standalone/configuration/Dialogic
next

step "Checking dlgc_sample_demo.properties"
if [ -f ${JBOSS_HOME}/standalone/configuration/Dialogic/dlgc_sample_demo.properties ] ; then
setpass
else
setfail
fi
next

log "Updating dlgc_sample_demo.properties"
step "    connector.sip.address"
try sed -i "s/connector.sip.address=.*/connector.sip.address=$(hostname -i |cut -f 1 -d ' ')/g" ${JBOSS_HOME}/standalone/configuration/Dialogic/dlgc_sample_demo.properties
next
step "    connector.sip.port"
try sed -i "s/connector.sip.port=.*/connector.sip.port=5080/g" ${JBOSS_HOME}/standalone/configuration/Dialogic/dlgc_sample_demo.properties
next
step "    mediaserver.sip.address"
try sed -i "s/mediaserver.sip.address=.*/mediaserver.sip.address=$MSIP/g" ${JBOSS_HOME}/standalone/configuration/Dialogic/dlgc_sample_demo.properties
next
step "    mediaserver.sip.port"
try sed -i "s/mediaserver.sip.port=.*/mediaserver.sip.port=5060/g" ${JBOSS_HOME}/standalone/configuration/Dialogic/dlgc_sample_demo.properties
next


#step "Copying 3rd party jars to deployment lib"
#try cp DlgcJSR309/3rdPartyLibs/*.jar ${JBOSS_HOME}/standalone/lib
#next

#step "Copying 309 connector jars to deployment lib"
#try cp DlgcJSR309/dialogic309Connector/*.jar ${JBOSS_HOME}/standalone/lib
#next

step "Copying dlgc_sample_demo.war to deployments directory"
try cp DlgcJSR309/application/dlgc_sample_demo.war ${JBOSS_HOME}/standalone/deployments
next

step "Backing up mss dar file"
cp ${JBOSS_HOME}/standalone/configuration/dars/mobicents-dar.properties ${JBOSS_HOME}/standalone/configuration/dars/mobicents-dar.properties.backup
next

step "Updating mss to route INVITEs verification"
sed -i "s/INVITE: (\"WebsocketSample\"/INVITE: (\"DialogicSampleDemo\"/g" ${JBOSS_HOME}/standalone/configuration/dars/mobicents-dar.properties
next
log "         **************************************************************************"
log "         This can be updated at http://$(hostname -i|cut -f 1 -d ' '):8080/sip-servlets-management/"
log "         **************************************************************************"

if [ "x${WARFILE}" != "x" ] ; then
step "Adding additional war file ${WARFILE}"
try cp ${WARFILE} ${JBOSS_HOME}/standalone/deployments
next
fi
logger -t "$scriptname" "Script Complete, See $LOG for more details"
echo
log "Script Complete! "
log "See $LOG for details"
log -e "${RED}Please continue setup via the WebUI at http://$(hostname -i|cut -f 1 -d ' '):8080 ${NC}"
log -e "JBOSS AS can be started via startjboss alias"
echo
