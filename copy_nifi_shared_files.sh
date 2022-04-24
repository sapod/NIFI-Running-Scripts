cdate=$(date +"%m_%d_%Y-%H_%M")
mkdir /nifi_data/nifi-shared-data_$cdate
cp -r /mnt/nifi-shared-data/* /nifi_data/nifi-shared-data_$cdate
ln -sfn /nifi_data/nifi-shared-data_$cdate /nifi_data/nifi-shared-data
rm -rf $(find /nifi_data/nifi-shared-data_* -maxdepth 0 -mmin +30)
