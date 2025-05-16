#!/bin/bash
csv_file="/opt/users.csv"
while IFS=";" read -r firstName lastName role phone ou street zip city country password; do
	if [ "$firstName" == "First Name" ]; then
		continue
	fi
	username="${firstName,,}.${lastName,,}"
	samba-tool user add "$username" P@ssw0rd;
done < "$csv_file"
