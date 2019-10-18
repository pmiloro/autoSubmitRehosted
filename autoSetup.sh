#!/bin/bash

#Get directory of this script when called
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


USERNAME="pmiloro3"
CACTUS_DIR="$HOME/data/Cactus"
SETTINGS_DIR="$CACTUS_DIR/simfactory/etc/"
SIM_OUTPUT_DIR=$(grep -o "\w*$HOME/\w*/\w*" "${SETTINGS_DIR}defs.local.ini")
STATUS_FILE="$DIR/status.txt"


#echo $DIR
#echo $CACTUS_DIR
#echo $SETTINGS_DIR
#echo $SIM_OUTPUT_DIR

previousSims=($(ls $SIM_OUTPUT_DIR))
#for i in "${previousSims[@]}"; do
#	printVal="$i"
#	echo "$printVal"
#done

numPreviousSims=${#previousSims[@]}

parfileNames=()
parSources=()
simNames=()
jobIDs=()
dataSourceDirs=()
queueStatuses=()
lastRunDates=()
previousMaxMs=()
#Find or create the data for all the simulations tracked in the data source folder
for i in "${previousSims[@]}"
do
	tokenlessPar=$(ls "$SIM_OUTPUT_DIR/$i/output-0000/" | grep ".par")
#	echo "tokenlessPar:$tokenlessPar"
	parfileNames+=("PFN:$tokenlessPar")

	parSources+=("PSL:Local")

	simNames+=("SMN:$i")

	dataSourceDirs+=("DSD:$SIM_OUTPUT_DIR/")


#	echo "Checking queue:"
	sims=("$(showq | grep $USERNAME)")
#	for sim in "${sims[@]}";do
#		echo "Contents of sim array are: $sim"
#	done

	count=0
	#Check the actual submission queue for more information on the simulations
	for sim in "${sims[@]}"
	do 
#		echo "Simulation is: $sim"

		#Split showq output into an array by spaces
		line=($sim)
#		echo "Line is: $line"

		#Grab the jobID and status from this line
		jobID=${line[0]}
		jobName=$(checkjob $jobID | grep "AName")
#		echo "$jobName"
		jobName=${jobName:7:${#jobName}-1}
#		echo "$jobName"

		if [ "$i" == "$jobName" ]; then
			count+=1

			jobIDs+=("JID:$jobID")

			queueStatus="QUS:${line[2]}"
			queueStatuses+=("QUS:$queueStatus")

			lastRunDate=${line[6]}
			lastRunDates+=("LRD:$lastRunDate")
		else
			#Only do this step once to prevent repeated entries
			if [ $count==0 ]; then
				count+=1
				jobIDs+=("JID:")
				queueStatuses+=("QUS:Unsubmitted")
				#Get the last date recorded in the last line of the log file for this simulation
				lastRunDates+=("LRD:$(tac "$SIM_OUTPUT_DIR/$i/log.txt" | grep -o -m1 -P "(?<=\[LOG:).*(?=\])")")
			fi

		fi

		simLoc="$SIM_OUTPUT_DIR/$i"
#		echo "simLoc is: $simLoc"
		activeFolder="$(ls "$simLoc/" | grep 'active')"
#		echo "activeFolder is: $activeFolder"
#		echo "activeFolder length is "${#activeFolder}""
		folderNumber="${activeFolder:${#activeFolder}-11:${#activeFolder}-14}"
#		echo "folderNumber is: $folderNumber"
		readNumber=$(($folderNumber-1))

		newestFolder="output-$folderNumber"
#		echo "Newest folder is: $newestFolder"
		
                internalFolderName=${tokenlessPar:0:${#tokenlessPar}-4}
                dataLoc="$simLoc/$newestFolder/$internalFolderName"

		#If the most recent output folder is filled out with the latest data
		if [ -f "$dataLoc/ShiftTracker0.asc" ]; then
			#Grab it
                        lastLine=$(tac "$dataLoc/ShiftTracker0.asc" | egrep -m 1 .)
                        line=($lastLine)
                        lastM=${line[1]}
                        previousMaxMs+=("PMM:$lastM")
		else
			#If there's only one output folder and no data in it, this simulation hasn't been run before,
			#so its max M is zero
			if [ $readNumber == -1 ]; then
				previousMaxMs+=("PMM:0")
			else 
				secondFolder="$(printf '%04d' $readNumber)"
				secondFolder="output-$secondFolder"
				dataLoc="$simLoc/$secondFolder/$internalFolderName"

				lastLine=$(tac "$dataLoc/ShiftTracker0.asc" | egrep -m 1 .)
                        	line=($lastLine)
                        	lastM=${line[1]}
                	        previousMaxMs+=("PMM:$lastM")
			fi
		fi
	done
done

#Create status file, clear it if one already exists
> "$STATUS_FILE"
#Add determined data settings to status file
for ((i=0;i<numPreviousSims;i++)); do
#	echo "${parfileNames[$i]}"
#	echo "${parSources[$i]}"
#	echo "${simNames[$i]}"
#	echo "${jobIDs[$i]}"
#	echo "${dataSourceDirs[$i]}"
#	echo "${queueStatuses[$i]}"
#	echo "${lastRunDates[$i]}"
#	echo "${previousMaxMs[$i]}"

	echo "${parfileNames[$i]}	${parSources[$i]}	${simNames[$i]}	${jobIDs[$i]}	${dataSourceDirs[$i]}	${queueStatuses[$i]}	${lastRunDates[$i]}	${previousMaxMs[$i]}" >> $STATUS_FILE
done

