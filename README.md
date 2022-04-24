# NIFI Running Scripts

Most scripts are taken from the dockerized NIFI, therefore the options to override parameters for different customizations are the same as the given environment variables shown there with the addition of NIFI_EMBEDDED_ZK and NIFI_EMBEDDED_ZK_MYID which can be set to true and instance number respectively for running NIFI with an embedded zookeeper.

The cluster_prep.sh script is running the NIFI cluster with certificate user authentication in this example, to change the configurations of the cluser you must edit the last command of the script (that runs prep_nifi.sh on each node) and set the wanted parameters using:

--PARAM_NAME [param_value]

only after making the wanted changes on that command, run the cluster_prep.sh script.

## Installing nifi:

1. create servers for the cluster
2. add storage for each machine under nifi_data
3. install JAVA: try **java -version**, if java is not installed then run - **yum install java-1.8.0-openjdk.x86_64**
4. install xmlstarlet: **yum install xmlstarlet**
5. edit /etc/hosts such that each node will contain all the other nodes
6. create the directory /nifi_data/nifi-data on each machine
**different folders are possible with small script change at the nifi_root variable in cluster_prep.sh
7. create a scripts-template folder to the created directory in one main node (for example node1) and copy the scripts from NIFI Secured Cluster Scripts
8. fetch the nifi template for the wanted version and copy it to the directory as well in that node (tested on version 1.15.2)
9. fetch the nifi toolkit for the wanted nifi version and copy it to that node
10. change the nifi_template_dir variable in cluster_prep.sh for the folder copied in (8)
11. set the user and password for the servers in cluster_prep.sh
12. create a nifi-shared-data directory in nifi_data storage in that node
13. create certificates for the cluster in that node: (passwords: -K - key, -P - truststore, -S - keystore, -B certificate, the nifi-certs folder will be created automatically, change the machine names and ips)
	1. ./nifi-toolkit-1.15.2/bin/tls-toolkit.sh standalone -n "node1,node2,node3" -C "CN=admin, OU=NIFI" -o /nifi_data/nifi-shared-data/nifi-certs --subjectAlternativeNames "ip1,ip2,ip3" -B [certificate_pass] -K [key_pass] -P [truststore_pass] -S [keystore_pass]
	2. set the cert_password variable in cluster_prep.sh
14. Use the nifi-share-data for all other machines:
	1. In the machine containing the folder:
		1. Edit the file /etc/exports and add a row sharing the folder to the other machines:
		/nifi_data/nifi-shared-data node*(ro)
		2. Install exportfs if not already installed: **yum install exportfs**
		3. Run **exportfs -r** to share the folder
		4. Validate with **exportfs** that the folder is shared (should print the row added to the file)
	2. In all other machines:
		1. Run **mount node1:/nifi_data/nifi-shared-data /mnt/nifi-shared-data** on the shared machine
		2. Copy the file copy_nifi_shared_files.sh to the machines
		3. Use **crontab -e** to add the rule: (this will copy the content of the mount to /nifi_data/nifi-shared-data, for persistency every 30 minutes)
		00,30 * * * * /root/copy_nifi_shared_files.sh
		4. Validate with **crontab -l**
15. Run the cluster_prep.sh script with the names of the machines
for example: ./scripts-template/cluster_prep.sh node1 node2 node3
16. (optional) Backup existing nifi
17. Run the install script on every machine: scripts/install.sh
18. NIFI is now running
 

### Backup an existing NIFI:

1. Copy the repositories to the new nifi machines at nifi_root as set in cluster_prep.sh:
	1. content_repository
	2. database_repository
	3. flowfile_repository
	4. provenance_repository
2. Copy the file flow.xml.gz from conf/ and put it in the new nifi conf before you run the install script
