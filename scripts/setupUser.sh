#!/bin/bash

### Define new user information
NEW_USER="openlane"
NEW_PSWD="openlane123"

### Check for system updates and perform a system upgrade
apt update
apt full-upgrade --yes
apt autoremove --yes
apt clean --yes 
apt autoclean --yes

### Create new user
useradd --create-home --shell /bin/bash "$NEW_USER"
echo "$NEW_USER:$NEW_PSWD" | chpasswd
usermod --append --groups sudo "$NEW_USER"

### Reboot to apply changes
reboot

