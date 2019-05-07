#!/usr/bin/env bash
echo "
 _____                        __                 __ ______                        __    
|     \.-----.--.--.--.-----.|  |.-----.---.-.--|  |   __ \.-----.--.--.  .-----.|  |--.
|  --  |  _  |  |  |  |     ||  ||  _  |  _  |  _  |   __ <|  _  |_   _|__|__ --||     |
|_____/|_____|________|__|__||__||_____|___._|_____|______/|_____|__.__|__|_____||__|__|                                                                                        
Version 1.0
"
# check if script is run as root
if [ "$USER" != root ]
    then echo "Please run as root"
    exit
fi

# functions
createDownloadFolders() {
    if [ "$1" = true ]; then
        mkdir /media/storage/jdownloader
        mkdir /media/storage/jdownloader/downloading
        mkdir /media/storage/jdownloader/extracted
        chown -R "$USERNAME":"$USERNAME" /media/storage
    else
        mkdir /home/"$USERNAME"/Downloads/jdownloader
        mkdir /home/"$USERNAME"/Downloads/jdownloader/downloading
        mkdir /home/"$USERNAME"/Downloads/jdownloader/extracted
        chown -R "$USERNAME":"$USERNAME" /media/storage
    fi
}

setupTheSambaServer() {
    apt-get install samba samba-common-bin
    if [ "$1" = true ]; then
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
    else
        echo "
        [NAS]
        comment = NAS folder
        path = /home/$USERNAME/Downloads
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
}

setupJDownloader() {
    apt-get install jq
    su - "$USERNAME"
    mkdir /config/jd2
    if [ "$EXT_STORAGE" = true ]; then
        docker run -d --name jd2 \
        -v /config/jd2:/opt/JDownloader/cfg \
        -v /media/storage/jdownloader/downloading:/downloads \
        plusminus/jdownloader2-headless
    else
        docker run -d --name jd2 \
        -v /config/jd2:/opt/JDownloader/cfg \
        -v /home/"$USERNAME"/Downloads/jdownloader/downloading:/downloads \
        plusminus/jdownloader2-headless
    fi
    echo "Waiting for the docker container to initialize for a minute. While this is running please create a myJDownloader account."
    sleep 90
    docker stop jd2
    # ask for myJDownloader credentials
    read -r -p "Please enter your MyJDownloader Username: " MYJD_USER
    read -r -p "Please enter your MyJDownloader Password: " MYJS_PSWRD
    # update credentials in org.jdownloader.api.myjdownloader.MyJDownloaderSettings.json
    jq --arg "$MYJD_USER" '.email = MYJD_USER' org.jdownloader.api.myjdownloader.MyJDownloaderSettings.json
    jq --arg "$MYJD_PSWRD" '.password = "MYJD_PSRWD"' org.jdownloader.api.myjdownloader.MyJDownloaderSettings.json
    # setup autostart service for docker
    sudo echo "
        [Unit]
        Description=JDownloader
        Requires=docker.service
        After=docker.service

        [Service]
        Restart=always
        ExecStart=/usr/bin/docker start -a jd2
        User=$USERNAME

        [Install]
        WantedBy=multi-user.target" | sudo tee /etc/systemd/system/jdownloader.service
    # enable and start service
    systemctl enable /etc/systemd/system/jdownloader.service
    systemctl start /etc/systemd/system/jdownloader.service
}

# track start
START=$(date +%s)
# update system
apt update
apt upgrade
# ask for username
read -r -p "Please enter your Username: " USERNAME
# ask if user want to use an external storage
read -r -p "Do you wish to use external storage? This will format the drive.  DANGER: ALL YOUR DATA WILL BE LOST! (y/n)?" EXT_STORAGE
case "$EXT_STORAGE" in
    [Yy][Ee][Ss]|[Yy]) EXT_STORAGE=true;;
    [Nn][Oo]|[Nn]) exit;;
esac
if [ "$EXT_STORAGE" = true ]; then
    parted -s -a optimal /dev/sda mklabel msdos -- mkpart primary ext4 0% 100%
    mkfs.ext4 -L STORAGE /dev/sda
    mkdir /media/storage
    mount /dev/sda /media/storage
    echo "/dev/sda /media/storage ext4 defaults 0 0" >> /etc/fstab
fi
createDownloadFolders $EXT_STORAGE
setupTheSambaServer $EXT_STORAGE
#install docker
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
groupadd docker
gpasswd -a "$USERNAME" docker
setupJDownloader $EXT_STORAGE
# give out amount of time the script needed
END=$(date +%s)
echo "Execution time was $(( "$END" - "$START" )) seconds."
exit
