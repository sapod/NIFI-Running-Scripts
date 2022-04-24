#!/bin/bash

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "give the list of machines as args: cluster_prep.sh node1 node2 node3"
else
  user=[server_username]
  password=[server_password]
  nifi_root=/nifi_data/nifi-data
  nifi_certs_folder=/nifi_data/nifi-shared-data/nifi-certs
  nifi_template_dir=$nifi_root/nifi-1.15.2
  scripts_dir=$nifi_root/scripts-template
  cert_password='[chosen_password]'
  
  # prepare configurations
  i=1
  all_user_identities='<property name="Initial User Identity 1"></property>'
  all_node_identities=''
  all_zk_str=''
  all_nodes=''
  zookeeper_props=''
  for node in "$@"; do
    user_identity="\n        <property name=\"Initial User Identity $((i+1))\">CN=$node, OU=NIFI</property>"
    node_identity="\n        <property name=\"Node Identity $i\">CN=$node, OU=NIFI</property>"
    lowercase_node_name=$(echo $node | tr '[:upper:]' '[:lower:]') 
 
    host_ip=$(sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "hostname -i" | awk '{print $2}')
    node_ips[i-1]=$host_ip
    
    zookeeper_props="$zookeeper_props""server.$i=$host_ip:2888:3888;2181\n"

    all_user_identities="$all_user_identities$user_identity"
    all_node_identities="$all_node_identities$node_identity"
    
    all_zk_str="$all_zk_str$host_ip:2181,"
    all_nodes="$all_nodes$lowercase_node_name,"
    i=$((i + 1))
  done
  
  all_zk_str="${all_zk_str:0:-1}"
  all_nodes="${all_nodes:0:-1}"
  
  i=0
  for node in "$@"; do
    # copy template files
    echo "copy template files to $node"
    sshpass -p $password scp -r $nifi_template_dir $user@$node:$nifi_root/nifi-current
    sshpass -p $password scp -r $scripts_dir $user@$node:$nifi_root/nifi-current/scripts
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "chmod -R +x  $nifi_root/nifi-current/scripts"
  
    echo "setting environment variables"
    # forever
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "echo $(cat ~/.bashrc | grep JAVA_HOME || echo export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk >> ~/.bashrc) 1> /dev/null"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "echo $(cat ~/.bashrc | grep NIFI_HOME || echo export NIFI_HOME=$nifi_root/nifi-current >> ~/.bashrc) 1> /dev/null"
  
    echo "configuring nifi.properties repositories on $node"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|nifi.database.directory=./database_repository|nifi.database.directory=$nifi_root/database_repository|'  $nifi_root/nifi-current/conf/nifi.properties"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|nifi.flowfile.repository.directory=./flowfile_repository|nifi.flowfile.repository.directory=$nifi_root/flowfile_repository|'  $nifi_root/nifi-current/conf/nifi.properties"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|nifi.content.repository.directory.default=./content_repository|nifi.content.repository.directory.default=$nifi_root/content_repository|'  $nifi_root/nifi-current/conf/nifi.properties"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|nifi.provenance.repository.directory.default=./provenance_repository|nifi.provenance.repository.directory.default=$nifi_root/provenance_repository|'  $nifi_root/nifi-current/conf/nifi.properties"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|nifi.status.repository.questdb.persist.location=./status_repository|nifi.status.repository.questdb.persist.location=$nifi_root/status_repository|'  $nifi_root/nifi-current/conf/nifi.properties"

    echo "configuring zookeeper.properties on $node"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|server.1=$|$zookeeper_props|'  $nifi_root/nifi-current/conf/zookeeper.properties"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|<property name=\\\"Initial User Identity 1\\\"></property>|$all_user_identities|'  $nifi_root/nifi-current/conf/authorizers.xml"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "sed -i -e 's|<property name=\\\"Node Identity 1\\\"></property>|$all_node_identities|'  $nifi_root/nifi-current/conf/authorizers.xml"
    
    echo "configuring cluster & security on $node"
    sshpass -p $password ssh -o StrictHostKeyChecking=no -q $user@$node "env NIFI_HOME=$nifi_root/nifi-current $nifi_root/nifi-current/scripts/prep_nifi.sh --AUTH tls --KEYSTORE_PATH $nifi_certs_folder/$node/keystore.jks --KEYSTORE_TYPE JKS --KEYSTORE_PASSWORD $cert_password --TRUSTSTORE_PATH $nifi_certs_folder/$node/truststore.jks --TRUSTSTORE_TYPE JKS --TRUSTSTORE_PASSWORD $cert_password --INITIAL_ADMIN_IDENTITY 'CN=admin, OU=NIFI' --NIFI_CLUSTER_IS_NODE true --NIFI_CLUSTER_ADDRESS $node --NIFI_CLUSTER_NODE_PROTOCOL_PORT 9991 --NIFI_CLUSTER_NODE_PROTOCOL_MAX_THREADS 10 --NIFI_ZK_ROOT_NODE $nifi_root --NIFI_ELECTION_MAX_WAIT '1 mins' --NIFI_SENSITIVE_PROPS_KEY $cert_password --HOSTNAME ${node_ips[i]} --NIFI_ZK_CONNECT_STRING $all_zk_str --NIFI_EMBEDDED_ZK true --NIFI_EMBEDDED_ZK_MYID $((i+1)) --NIFI_WEB_PROXY_HOST $all_nodes"
  
    i=$((i + 1))
  done
  
fi
