#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CACTUS_PAR_DIR="$HOME/data/Cactus/par/"
PAR_REPO_DIRS=("MayaParameterFiles/")
BRANCH_NAMES=("master")
README_FILE="README.md"
STATUS_FILE="$DIR/status.txt"
module load git/2.13.4

count=0
fileNum=0
for dir in "${PAR_REPO_DIRS[@]}"; do
	cd "$CACTUS_PAR_DIR$dir"
	echo "$CACTUS_PAR_DIR$dir"
	#Get the time of the last pull
	prevPull=$(stat -c %Y .git/FETCH_HEAD)
	echo "$prevPull"
​	pullStat=$(git pull origin "${BRANCH_NAMES[$count]}")

	#If the time of the last pull has changed, the pull above was successful 

	#(probably; apparently some failure modes can alter FETCH_HEAD without updating file lists, but whatever)

	nextPull=$(stat -c %Y .git/FETCH_HEAD)
	
	if [ "$prevPull" = "$nextPull" ]; then
    		echo "Failed to update parfile lists for repo $dir"
	else 
		cd "$CACTUS_PAR_DIR$dir"
        	#Check the names of all the files in the repository directory against the contents of the index file README
        	fileNum=0
		for f in $BASE_PAR_REPO*; do
			if [ "$f" != "$README_FILE" ]; then
                		#Remove annoying file extension/filepath
                		f2=$(basename $f)
                		name="${f2/.par}"
                		#See if the parfile name is in the status file
				if grep "$f2" "$STATUS_FILE"; then
					true
				else
                        		#If it isn't, then this is a new parfile, so
                        		#configure data for input to the status file
                        		parfileName="PFN:$f2"
                        		parSource="PSL:$dir"
                        		simName="SMN:$name"
                        		jobID="JI:"
                        		dataSourceDir="DS:"
                        		queueStatus="QU:"
                	        	lastRunDate="LR:"
        	                	previousMaxM="PMM:0"
	                        	echo "Sim name is: $simName"
					#Append information to status file
	                        	echo "$parfileName	$parSource	$simName        $jobID $dataSourceDir  $queueStatus    $lastRunDate    $previousMaxM" >> "$STATUS_FILE"
	                		fileNum=$(($fileNum+1))
				fi			
	            	fi
	        done
	fi
	count=$(($count+1))
done

