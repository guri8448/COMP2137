#!/bin/bash

# This is the function to run commands via SSH on a remote machine
runSshCommand() {
    ssh remoteadmin@"$1" "$2"
}

# Function to check if a package is installed and install if necessary
checkAndInstallPackage() {
    if ! dpkg -s "$1" &>/dev/null; then
        sudo apt update
        sudo apt install -y "$1"
    fi
}

# Function to check if a line exists in a file and add it if not present
addLineToFile() {
    if ! grep -qF "$1" "$2"; then
        echo "$1" | sudo tee -a "$2" > /dev/null
    fi
}

# Here are the target1 tasks
target1_ip="172.16.1.10"
runSshCommand "$target1_ip" "sudo hostnamectl set-hostname loghost"
runSshCommand "$target1_ip" "sudo ip addr add 192.168.1.3/24 dev eth0"
runSshCommand "$target1_ip" "echo '192.168.1.4 webhost' | sudo tee -a /etc/hosts > /dev/null"
runSshCommand "$target1_ip" "sudo apt update && sudo apt install -y ufw"
runSshCommand "$target1_ip" "sudo ufw allow from 172.16.1.0/24 to any port 514 proto udp"
runSshCommand "$target1_ip" "sudo sed -i '/imudp/s/^#//g' /etc/rsyslog.conf"
runSshCommand "$target1_ip" "sudo systemctl restart rsyslog"

# Here are the target2 tasks
target2_ip="172.16.1.11"
runSshCommand "$target2_ip" "sudo hostnamectl set-hostname webhost"
runSshCommand "$target2_ip" "sudo ip addr add 192.168.1.4/24 dev eth0"
runSshCommand "$target2_ip" "echo '192.168.1.3 loghost' | sudo tee -a /etc/hosts > /dev/null"
runSshCommand "$target2_ip" "sudo apt update && sudo apt install -y ufw apache2"
runSshCommand "$target2_ip" "sudo ufw allow 80/tcp"
runSshCommand "$target2_ip" "echo '. @loghost' | sudo tee -a /etc/rsyslog.conf > /dev/null"

# Now update NMS /etc/hosts file
echo "Updating NMS /etc/hosts file..."
echo "192.168.1.3 loghost" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.1.4 webhost" | sudo tee -a /etc/hosts > /dev/null

# Here we will Verify configuration
echo "Verifying configuration..."
firefox "http://webhost"
webhostLogs=$(ssh gurjant@"$target1_ip" "grep webhost /var/log/syslog")
if [[ "$webhostLogs" != "" ]]; then
    echo "Configuration update succeeded."
else
    echo "Configuration update failed. Check the following:"
    echo "1. Apache server on webhost is not responding properly."
    echo "2. No logs from webhost found on loghost."
fi
