#!/bin/bash

#Auto-Install Script for my servers/desktops

application_set=false

samba_mount=false
samba_passwd=false

ignore_unstated=false

install_zabbix=false

username=false

get_ssh=false


#
#FUNCTION-DEFINITIONS
#
function askSambaMount {
	echo ""
	echo "Do you want to add a Samba mountpoint? (y/n)"
	read samba_mount
	case $samba_mount in
		yes|Yes|YES|Y|y)
			echo "A Samba mountpoint will be added"
			samba_mount=true
			askSambaPasswd
		;;
		no|No|NO|n|N)
			echo "No Samba mountpoint will be added"
			samba_mount=false
		;;
		*)
			echo "ERROR: Please enter a valid answer"
			askSambaMount
		;;
	esac
}
function askSambaPasswd {
	echo ""
        echo "Please enter the password for the Samba mountpoint"
        read -s samba_passwd_1
	echo "Verify:"
	read -s samba_passwd_2
	if [ $samba_passwd_1 == $samba_passwd_2 ]
		then
		echo "Password added"
		samba_passwd=samba_passwd_1

		else
		echo "ERROR: Passwords do not match."
		askSambaPasswd
	fi
}
function installSambaMount {
	echo "installing Samba mount..."
	echo "//192.168.1.22/Nas_Files /media/NAS cifs noauto,users,username=max,passwd=$1 0 0" >> /etc/fstab
	mkdir /media/NAS
	chown $2 /media/NAS
	mount /media/NAS
	mkdir -p /home/$2/Apps/Scripts/
	touch /home/$2/Apps/Scripts/Autostart.sh
	echo "#!/bin/bash" >> /home/$2/Apps/Scripts/Autostart.sh
	echo "mount /media/NAS" >> /home/$2/Apps/Scripts/Autostart.sh
	echo "Done"
}
function askZabbix {
	echo ""
	echo "Do you want to install a Zabbix agent? (y/n)"
	read install_zabbix
        case $install_zabbix in
                yes|Yes|YES|Y|y)
			echo "A Zabbix agent will be installed"
			install_zabbix=true
                ;;
                no|No|NO|n|N)
			echo "No Zabbix agent will be installed"
			install_zabbix=false
                ;;
                *)
                        echo "ERROR: Please enter a valid answer"
                        askZabbix
                ;;
        esac
}
function installZabbix {
	#Installs and configures the Zabbix agent
	echo "Installing Zabbix Agent..."
	wget http://repo.zabbix.com/zabbix/3.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.0-1+xenial_all.deb
	dpkg -i zabbix-release_3.0-1+xenial_all.deb
	apt update
	apt install -y zabbix-agent
	sed s/Server=127.0.0.1/Server=192.168.1.35/g /etc/zabbix/zabbix_agentd.conf
	systemctl enable zabbix-agent.service
	systemctl restart zabbix-agent.service
	rm zabbix-release_3.0-1+xenial_all.deb
	echo "Done"
}
function askApplicationSet {
	#Asks for a application set if none is given
	echo ""
	echo "Please enter the application set that you would like to install:"
	echo "- desktop"
	echo "- server"
	echo "- none"
	read application_set
	echo ""
	case $application_set+$ignore_unstated+$install_zabbix in
		desktop+*+*)
        	        echo "Desktop application set will be installed"
        	;;
	        server+*+true)
        	        echo "Server application set and Zabbix will be installed"
	        ;;
        	server+true+false)
                	echo "Server application set will be installed"
        	;;
        	server+false+false)
                	echo "Server application set will be installed"
                	askZabbix
        	;;
       		none+*+*)
			echo "No applications will be installed"
		;;
        	*+*+*)
                	echo "ERROR: Invalid applicaion set given"
               		askApplicationSet
        	;;
	esac
}
function installApplicationSet {
	case $1 in
        server)
                echo "Installing server application set..."
		apt update && apt -y upgrade
                apt -y install bmon htop iotop openssh-server cifs-utils
                echo "Done."
        ;;
        desktop)
                echo "Installing desktop application set..."
		apt update && apt -y upgrade
                apt -y install chromium-browser htop iotop openvpn steam rhythmbox guake gimp cifs-utils libreoffice
                echo "Done."
	;;
	esac
}
function askGetSSH {
	echo ""
        echo "Do you want to pull the ssh config file? (y/n)"
        read get_ssh
        case $get_ssh in
                yes|Yes|YES|Y|y)
                        echo "The ssh config will be pulled from the Samba mount"
			get_ssh=true
                ;;
                no|No|NO|n|N)
                        echo "The ssh config will not be pulled"
			get_ssh=false
                ;;
                *)
                        echo "ERROR: Please enter a valid answer"
                        askGetSSH
                ;;
        esac
}
function GetSSH {
	echo "Copying SSH config..."
	cp /media/NAS/Homelab/Configs/SSH/config /home/"$2"/.ssh/
        chown "$2" /home/"$2"/.ssh/config
        chmod 600 /home/"$2"/.ssh/config
	echo "Done"
}
#
#/FUCNTION-DEFINITIONS
#


#
#INIT
#Initializes the script by checking for root, parsing argumen
#
#Checks for root priviliges
if [ "$EUID" -ne 0 ]
	then
	echo "FATAL: This script needs root permissions. Exiting..."
	exit 2
fi
#Grabs options and outputs what options have been chose
echo "The script will do the following without further confirmation:"
echo ""
while getopts :A:siu:ZOS opt; do
	case $opt in
	A)
		#Set application_set to $OPTARG
		application_set=$OPTARG
		echo "- (-A) Install the following application set: $OPTARG"
	;;
	s)
		#Set $samba_mount to true
		samba_mount=true
		echo "- (-s) Create a Samba mountpoint"
	;;
	S)
		#Set $get_ssh to true
		get_ssh=true
		echo "- (-S) Get the ssh config file"
	;;
	i)
		#Set $ignore_unstated to true
		ignore_unstated=true
	;;
	Z)
		#Set $install_zabbix to true
		install_zabbix=true
		echo "- (-Z) Install a Zabbix agent"
	;;
	u)
		#Set $username to $OPTARG
		username=$OPTARG
		echo "- (-u) Use the username $OPTARG for configuration"
	esac
done
echo ""
case $ignore_unstated in
	false)
		echo "And ask for any step not mentioned above"
	;;
	true)
		echo "And skip any steps not mentioned above (-i)"
	;;
esac


#Warn that OpenVPN, and SSH setup are not possible without -s

#Confirmation that everything is ok
echo ""
echo "Is this correct?"
read confirm
case $confirm in
	y|Y|yes|Yes|YES)
	;;
	*)
		echo "Abort"
		exit 1
	;;
esac
echo ""
#
#/INIT
#


#
#CONFIGURE
#
#Configures the username
case $username in
	false)
		echo "Please enter the username to use for config"
		read username
		echo "Username $username set"
	;;
	*)
		echo "Username $username set"
	;;
esac
#Configures the application set
case $application_set+$ignore_unstated+$install_zabbix in
	desktop+*+*)
		echo "Desktop application set will be installed"
	;;
	server+*+true)
		echo "Server application set will be installed"
		echo "A Zabbix agent will be installed"
	;;
	server+true+false)
		echo "Server application set will be installed"
		echo "No Zabbix agent will be installed"
	;;
	server+false+false)
		echo "Server application set will be installed"
		askZabbix
	;;
	false+true+*)
		echo "No applications will be installed"
	;;
	false+false+*)
		askApplicationSet
	;;
	*+*+*)
		echo "ERROR: Invalid parameters"
		askApplicationSet
	;;
esac
#Configures Samba config entry
case $samba_mount+$ignore_unstated in
	true+*)
		echo "A Samba mountpoint will be added"
		askSambaPasswd
	;;
	false+true)
		echo "No Samba mountpoint will be added"
	;;
	false+false)
		askSambaMount
	;;
	*+*)
		echo "ERROR: Invalid parameters"
		askSambaMount
	;;
esac
echo ""
#Configures SSH file copy
case $get_ssh+$ignore_unstated+$samba_mount in
	*+*+false)
		echo "NOTE: Skipping SSH, as no Samba share wil be mounted"
	;;
	true+*+true)
		echo "The ssh config will be pulled from the Samba share"
	;;
	false+true+true)
		echo "The ssh config will not be pulled"
	;;
	false+false+true)
		askGetSSH
	;;
	*+*+*)
		echo "ERROR: Invalid parameters"
		askGetSSH
	;;
esac
#
#/CONFIGURE
#


#
#VERIFY
#
#Print config
echo ""
echo "-----------------------------------------------"
echo "The following options have been set:"
echo "Username: $username"
echo "Install Application set: $application_set"
echo "Install Zabbix: $install_zabbix"
echo "Mount Samba share: $samba_mount"
echo "Get SSH config: $get_ssh"
echo "------------------------------------------------"
#Confirmation that everything is ok
echo ""
echo "Is this correct?"
read confirm
case $confirm in
        y|Y|yes|Yes|YES)
        ;;
        *)
                echo "Abort"
                exit 3
        ;;
esac
echo ""
echo "Confirmed. Script will start in 3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
echo "GO!"
#
#/VERITFY
#


#
#INSTALL
#
case $application_set in
	desktop)
		installApplicationSet desktop
	;;
	server)
		installApplicationSet server
	;;
esac
case $install_zabbix in
	true)
		installZabbix
	;;
esac
case $samba_mount in
	true)
		installSambaMount "$samba_passwd" "$username"
	;;
esac
case $get_ssh in
	true)
		GetSSH
	;;
esac
#
#/INSTALL
#

#
#CLEANUP
#
