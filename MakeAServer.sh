#!/usr/bin/env bash

echo "
 _____                        __                 __ ______                        __    
|     \.-----.--.--.--.-----.|  |.-----.---.-.--|  |   __ \.-----.--.--.  .-----.|  |--.
|  --  |  _  |  |  |  |     ||  ||  _  |  _  |  _  |   __ <|  _  |_   _|__|__ --||     |
|_____/|_____|________|__|__||__||_____|___._|_____|______/|_____|__.__|__|_____||__|__|                                                                                        
Version 0.1
"
# check if script is run as root
if [ $USER != root ]
  then echo "Please run as root"
  exit
fi
# update system
apt update
apt upgrade
# ask if user want to use an external storage
while true; do
    read -p "Please enter your Username: " USER
    read -p "Do you wish to use a HDD or SSD? This will format the drive.  DANGER: ALL YOUR DATA WILL BE LOST! (y/n)?" yn
    case "$yn" in
        [Yy]* ) STORAGE=true;;
        [Nn]* ) STORAGE=false;;
        * ) echo "Please answer (y)es or (n)o.";;
    esac
    if $STORAGE; then
        # format and mount external storage
        sudo parted --script /dev/sda 
        mktable msdos
        mkpart primary ext4 0% 100%
        sudo mkfs.ext4 -L STORAGE /dev/sda1
        sudo mkdir /media/storage
        sudo mount /dev/sda1 /media/storage
        echo "/dev/sda1 /media/usbhdd ext4 defaults 0 0" >> /etc/fstab
        # create jdownloader folders on external storage
        sudo mkdir /media/storage/jdownloader
        sudo mkdir /media/storage/jdownloader/downloading
        sudo mkdir /media/storage/jdownloader/extracted
        chown -R "$USER":"$USER"
        # setup samba server
        apt-get install samba samba-common-bin
        echo "
        [NAS]
        comment = NAS folder
        path = /media/storage
        create mask = 0755
        directory mask = 0755
        read only = no
        browseable = yes
        security = user
        encrypt passwords = true
        force user = $USER" >> /etc/samba/smb.conf
    fi
    echo "Set a password for the Samba Server"
    smbpasswd -a "$USER"
    echo "Your username is: $USER"
    # install java
    sudo apt install openjdk-11-jre-headless || sudo apt-get install oracle-java8-jdk
    # install jdownloader2
    mkdir ~/bin
    mkdir ~/bin/jdownloader
    cd ~/bin/jdownloader || exit
    wget http://installer.jdownloader.org/JDownloader.jar
    echo "Please create an account for MyJDownloader (https://my.jdownloader.org/login.html#register)"
    java -jar JDownloader.jar -norestart
    echo"
    [Unit]
    Description=JDownloader
    Wants=network.target
    After=network.target

    [Service]
    Type=simple

    ExecStart=/usr/bin/java -jar /home/pi/bin/jdownloader/JDownloader.jar
    User=$USER

    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/jdownloader.service
    systemctl daemon-reload
    systemctl start jdownloader.service
    systemctl enable jdownloader.service
    echo "Please kill the script (CTRL+C) and reboot your system after the jdownloader stucks in the update progress."
    echo "To configure you jdownloader login to you MyJDownloader Account."
    java -jar JDownloader.jar -norestart
done
exit
