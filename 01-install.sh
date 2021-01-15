#!/bin/bash

sudo apt update

# preparing space for snaps
sudo mkdir /mydata/snap 
echo "/mydata/snap /var/snap none bind 0 0" | sudo tee -a /etc/fstab 
sudo mkdir /var/snap 
sudo mount -a

sudo apt install -y snapd 
sudo snap install multipass


sudo mkdir /home/markosz
sudo mount --bind /users/markosz/ /home/markosz

echo 'export PATH=$PATH:/snap/bin' >> ~/.bashrc source ~/.bashrc
sudo sed -i 's/\/users\/markosz/\/home\/markosz/g' /etc/passwd
# not need to login again after this? it worked

