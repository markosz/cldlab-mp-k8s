#!/bin/bash

sudo apt update

# preparing space for snaps
sudo mkdir /mydata/snap 
echo "/mydata/snap /var/snap none bind 0 0" | sudo tee -a /etc/fstab 
sudo mkdir /var/snap 
sudo mount -a

sudo apt install -y snapd 
sudo snap install multipass
sudo snap install kubectl --classic

sudo mkdir /home/markosz
sudo mount --bind /users/markosz/ /home/markosz

export PATH=$PATH:/snap/bin
echo 'export PATH=$PATH:/snap/bin' >> ~/.bashrc

sudo sed -i 's/\/users\/markosz/\/home\/markosz/g' /etc/passwd

echo "set -g mouse on" >> ~/.tmux.conf

sudo usermod -a -G sudo markosz
echo "You need to log out on all terminals!"



