#!/bin/bash

# Function to display status 
printStats() {
  echo "[$(date )] $1"
}

# Function to handle errors
handleError() {
  local errorMessage="$1"
  echo "[$(date )] ERROR: $errorMessage" >&2
  exit 1
}

# Function to check is package installed
isPackageInstalled() {
  dpkg -s "$1" >/dev/null 2>&1
}

# Function to check is user exists
isUserExists() {
  id -u "$1" >/dev/null 2>&1
}

# Function to check if a file contains specific line
specificLine() {
  grep -Fxq "$1" "$2"
}

# Function to add a line to a file if it doesn't exist
addFile() {
  if ! specificLine "$1" "$2"; then
    echo "$1" | sudo tee -a "$2" >/dev/null
  fi
}

# Function to update a line in file if it exists
updateLine() {
  sudo sed -i "s|$1|$2|" "$3"
}

# Function to enable a service
enableService() {
  sudo systemctl enable "$1" >/dev/null 2>&1
}

# Function to restart a service
restartService() {
  sudo systemctl restart "$1" >/dev/null 2>&1
}

# Check and modify hostname
presentHostname=$(hostname)
desiredHostname="autosrv"

if [ "$presentHostname" != "$desiredHostname" ]; then
  sudo hostnamectl set-hostname "$desiredHostname" || handleError "Failed to set hostname"
  printStats "Hostname updated to: $desiredHostname"
fi

# Check and modify network configuration
networkInterface="ens34" 
desiredAddress="192.168.16.21/24"
desiredGateway="192.168.16.1"
desiredDnsServer="192.168.16.1"
desiredSearchDomains="home.arpa localdomain"

currentAddress=$(sudo ip -o -4 addr show "$networkInterface" | awk '{print $4}')
currentGateway=$(sudo ip route show default | awk '/default/ {print $3}')

if [ "$currentAddress" != "$desiredAddress" ]; then
  sudo nmcli con mod "$networkInterface" ipv4.address "$desiredAddress" || handleError "Failed to set network address"
  printStats "Network address updated to: $desiredAddress"
fi

if [ "$currentGateway" != "$desiredGateway" ]; then
  sudo nmcli con mod "$networkInterface" ipv4.gateway "$desiredGateway" || handleError "Failed to set network gateway"
  printStatus "Network gateway updated to: $desiredGateway"
fi

# Configure DNS settings
dnsFile="/etc/resolv.conf"
dnsConfig="nameserver $desiredDnsServer\nsearch $desiredSearchDomains"

echo -e "$dnsConfig" | sudo tee "$dnsFile" >/dev/null || handleError "Failed to set DNS configuration"
printStats "DNS configuration is updated"

# Check and install required software packages
requiredPackages=("openssh-server" "apache2" "squid" "ufw")

for package in "${requiredPackages[@]}"; do
  if ! isPackageInstalled "$package"; then
    sudo apt-get install -y "$package" || handleError "Failed to install package: $package"
    printStats "Package installed: $package"
  fi
done

# Configure SSH server
sshConfigFile="/etc/ssh/sshd_config"
sshKeyAuthLine="PasswordAuthentication no"

if ! specificLine "$sshKeyAuthLine" "$sshConfigFile"; then
  addLine "$sshKeyAuthLine" "$sshConfigFile"
  restartService "ssh"
  printStatus "SSH server configured for key authentication"
fi

# Configure Apache2
apacheConfigFile="/etc/apache2/ports.conf"
apacheHttpLine="Listen 80"
apacheHttpsLine="Listen 443"

if ! specificLine "$apacheHttpLine" "$apacheConfigFile"; then
  addLine "$apacheHttpLine" "$apacheConfigFile"
  printStats "Apache2 configured to listen on port 80"
fi

if ! specificLine "$apacheHttpsLine" "$apacheConfigFile"; then
  addLine "$apacheHttpsLine" "$apacheConfigFile"
  printstats "Apache2 configured to listen on port 443"
fi

# Configure Squid
squidConfigFile="/etc/squid/squid.conf"
squidProxyPort="3128"

if ! specificLine "httpPort $squidProxyPort" "$squidConfigFile"; then
  addLine "httpPort $squidProxyPort" "$squidConfigFile"
  printStats "Squid configured to listen on port $squidProxyPort"
fi

# Configure UFW firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3128
sudo ufw enable >/dev/null 2>&1
printStats "UFW firewall configured"

# Create user accounts
userList=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
sshKey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI gurjant@generic-vm"

for user in "${userList[@]}"; do
  addUser "$user" "$sshKey"
done

# Function to add user with the specified configuration
addUser() {
  local username="$1"
  local sshKey="$2"

  if ! isUserExists "$username"; then
    sudo useradd -m -s /bin/bash "$username" || handleError "Failed to create user: $username"
    printStats "User created: $username"
  fi

  sudo mkdir -p "/home/$username/.ssh"
  addLine "AllowUsers $username" "$sshConfigFile"
  printStats "SSH access allowed for user: $username"

  addLine "$ssh_key" "/home/$username/.ssh/authorized_keys"
  printStats "SSH key added for user: $username"
}

# Restart services if necessary
restartService "apache2"
restartService "squid"

# Print completion message
printStats "System configuration Done successfully"
