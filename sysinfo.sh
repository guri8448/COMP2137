
#!/bin/bash
cat <<EOF

System Report generated by $username, $mydate

System information
------------------
Hostname: $hostname
OS:       $PRETTY_NAME
Uptime:   $myuptime

EOF
