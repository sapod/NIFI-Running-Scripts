"${NIFI_HOME}/bin/nifi.sh" install
systemctl start nifi
service nifi start && echo NiFi is running
