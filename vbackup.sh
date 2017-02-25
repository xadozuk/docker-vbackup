#!/bin/bash

BASE="/backups"

CONF_FILE=$BASE/config.json

DOCKER=docker
IMAGE=xadozuk/vbackup

printf "[$(date +"%b %d %T")] Starting backup\n"

this_id=$(cat /proc/self/cgroup | grep "name" | head -n 1 | sed "s/.*docker\///g")
containers=$($DOCKER ps -aqf name=data | xargs docker inspect 2>/dev/null | jq -c ".[] | { id: .Id, name: .Name , volumes: [.Mounts[].Destination] }")
for container in $containers
do
	name=$(echo $container | jq -r ".name")
	id=$(echo $container | jq -r ".id")
    excluded_volumes=

    printf "Container $name"

    if [ -e $CONF_FILE ]; then
        conf=$(jq -c ".exclude[] | select(.container == \"$(echo $name | sed 's/\///g')\")" $CONF_FILE)

        if [ -n "$conf" ]; then
            excluded_volumes=$(echo $conf | jq -c ".volumes")

            if [ -z "$excluded_volumes" ] || [ "$excluded_volumes" == "null" ]; then
                printf "\t\t[\e[93mSKIPPED\e[39m]\n"
                continue
            fi
        fi         
    fi

	printf "\n"

	mkdir -p $BASE$name
	
	for volume in $(echo $container | jq -r ".volumes[]")
	do
		printf "\tarchiving $volume"

        if [ -n "$excluded_volumes" ]; then
            vol=$(echo $excluded_volumes | jq -r ".[] | select(. == \"$volume\")")

            if [ -n "$vol" ]; then
                printf "\t[\e[93mSKIPPED\e[39m]\n"
                continue
            fi
        fi
        
        volume_name=$(echo $volume | sed "s/\//_/g")
		$DOCKER run --rm --volumes-from $id --volumes-from $this_id $IMAGE tar -zcf "${BASE}${name}${volume_name}.$(date +"%Y%m%d%H%M%S").tar.gz" $volume > /var/log/vbackup.log 2>&1
		
		if [ $? -eq 0 ]; then
			printf "\t[\e[92mOK\e[39m]\n"
		else
			printf "\t[\e[91mFAIL\e[39m]\n"
		fi
	done
done

if [ -z "$containers" ]; then
    printf "[$(date +"%b %d %T")] No data container found\n"
fi

# Cleaning old backups
printf "Cleaning old backups"
dirs=$(find $BASE/* -maxdepth 1 -type d)
for dir in $dirs
do
    volumes=$(find $dir/* -type f -exec basename {} \; | cut -d '.' -f 1 | uniq)
    
    for v in $volumes
    do
        find $dir -name "$v*.tar.gz" -type f | sort | head -n -7 | xargs rm > /dev/null 2>&1
    done 
done

printf "\t[\e[92mOK\e[39m]\n"

printf "[$(date +"%b %d %T")] Finish backuping\n"

