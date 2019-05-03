#!/usr/bin/env bash

echo "
 _____                        __                 __ ______                        __    
|     \.-----.--.--.--.-----.|  |.-----.---.-.--|  |   __ \.-----.--.--.  .-----.|  |--.
|  --  |  _  |  |  |  |     ||  ||  _  |  _  |  _  |   __ <|  _  |_   _|__|__ --||     |
|_____/|_____|________|__|__||__||_____|___._|_____|______/|_____|__.__|__|_____||__|__|                                                                                        
Version 0.2
"
# check if script is run as root
if [ $USER != root ]
  then echo "Please run as root"
  exit
fi
#track start
START=$SECONDS
# update system
apt update
apt upgrade
# ask if user want to use an external storage
if [ "0" ]; then STORAGE=true; else STORAGE=false;
while true; do
    read -p "Please enter your Username: " USERNAME
    while true; do
     read -p "Do you wish to use a HDD or SSD? This will format the drive.  DANGER: ALL YOUR DATA WILL BE LOST! (y/n)?" yn
     case "$yn" in
         [Yy][Ee][Ss]|[Yy]) return 1;;
         [Nn][Oo]|[Nn]) return 0;;
         * ) echo "Please answer (y)es or (n)o.";;
     esac
    done
    if $STORAGE; then
        # format and mount external storage
        sudo parted -s -a optimal /dev/sda mklabel msdos -- mkpart primary ext4 0% 100%
        sudo mkfs.ext4 -L STORAGE /dev/sda
        sudo mkdir /media/storage
        sudo mount /dev/sda1 /media/storage
        echo "/dev/sda /media/storage ext4 defaults 0 0" >> /etc/fstab
        # create jdownloader folders on external storage
        sudo mkdir /media/storage/jdownloader
        sudo mkdir /media/storage/jdownloader/downloading
        sudo mkdir /media/storage/jdownloader/extracted
        chown -R "$USERNAME":"$USERNAME" /media/storage
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
        force user = $USERNAME" >> /etc/samba/smb.conf
    fi
    echo "Set a password for the Samba Server"
    smbpasswd -a "$USERNAME"
    echo "Your username is: $USERNAME"
    # install java
    sudo apt install openjdk-11-jre-headless || sudo apt-get install oracle-java8-jdk
    # install jdownloader2
    mkdir ~/bin
    mkdir ~/bin/jdownloader
    cd ~/bin/jdownloader || exit
    wget http://installer.jdownloader.org/JDownloader.jar
    read -r -p "Please create an account for MyJDownloader now. (https://my.jdownloader.org/login.html#register). When you are done press [ENTER]." KEY
        if [ $KEY=$'\x0a' ]; then
            sudo -u $USERNAME java -jar JDownloader.jar -norestart
            echo"
            [Unit]
            Description=JDownloader
            Wants=network.target
            After=network.target

            [Service]
            Type=simple

            ExecStart=/usr/bin/java -jar /home/pi/bin/jdownloader/JDownloader.jar
            User=$USERNAME

            RemainAfterExit=yes

            [Install]
            WantedBy=multi-user.target" > /etc/systemd/system/jdownloader.service
            systemctl daemon-reload
            systemctl start jdownloader.service
            systemctl enable jdownloader.service
        fi
    sudo -u $USERNAME java -jar JDownloader.jar -norestart
    sleep 30s
    killall /usr/bin/java -jar /home/$USERNAME/bin/jdownloader/JDownloader.jar
    # give out amount of time the script needed
    DURATION=$(( $SECONDS - $START ))
    echo "Finished in $DURATION sec."
    echo "Rebooting.."
    sleep 10s
    sudo reboot
done
exit
