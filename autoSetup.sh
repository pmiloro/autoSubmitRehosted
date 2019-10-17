#!/bin/bash

#Get directory of this script when called
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"



CACTUS_DIR="$HOME/data/Cactus"
SIM_OUTPUT_DIR=$(grep -o "\w*$HOME/\w*/\w*" "${SETTINGS_DIR}defs.local.ini")
STATUS_FILE="status.txt"


echo $DIR
echo $CACTUS_DIR
echo $SIM_OUTPUT_DIR

previousSims=($(ls $SIM_OUTPUT_DIR))
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
	tokenlessPar=$(ls "$SIM_OUTPUT_DIR/$i/" | grep ".par")
	parfileNames+=("PFN:$tokenlessPar")

	parSources+=("PSL:Local")

	simNames+=("SMN:$i")

	dataSourceDirs+=("DSD:$SIM_OUTPUT_DIR/")



	sims=($(showq | grep $USERNAME))

	count=0
	#Check the actual submission queue for more information on the simulations
	for sim in "${sims[@]}"
	do 

		#Split showq output by the delimiter they use (eight spaces)
		IFS="\s\s\s\s\s\s\s\s";  read -ra line <<< $sim
		#Grab the jobID and status from this line
		jobID=${line[0]}
		jobName=$(checkjob $jobID | grep "AName")
		jobName=${jobName:0:${#jobName}}


		if {$i == $jobName}; then
			count+=1

			jobIDs+=("JID:$jobID")

			queueStatus="QUS:${line[2]}"
			queueStatuses+=("QUS:$queueStatus")

			lastRunDate=${line[6]}
			lastRunDates+=("LRD:$lastRunDate")
		else
			#Only do this step once to prevent repeated entries
			if [$count==0]; then
				count+=1
				jobIDs+=("JID:")
				queueStatuses+=("QUS:Unsubmitted")
				#Get the last date recorded in the last line of the log file for this simulation
				lastRunDates+=("LRD:$(tac "$SIM_OUTPUT_DIR$i/log.txt" | grep -o -m1 -P "(?<=\[LOG:).*(?=\])")")
			fi

		fi

		simLoc="$SIM_OUTPUT_DIR$simName"
		activeFolder=$(ls "$simLoc/" | grep "active")
		#Cut the ".par" off of the parfile name to find the directory name of the actual data
		internalFolderName=${parName:0:${#parName[@]}-5}
		#Location where the output data for each simulation is stored
		dataLoc="$simLoc/$activeFolder/$internalFolderName/"

		#Get the last line of the shift tracker data so we can determine how far the simulation has progressed
		lastLine=$(tac "${dataloc}ShiftTracker0.asc" | egrep -m 1 .)
		IFS="\s\t";  read -ra line <<< $lastLine
		lastM=${line[1]}
		previousMaxMs+=("PMM:$lastM")
	done

	#Create status file
	touch "$DIR$STATUS_FILE"
	#Add determined data settings to status file
	for ((i=0;i<numPreviousSims;i++)); do
		sed -i "$i a ${parfileNames[$i]}\t${parSources[$i]}\t${simNames[$i]}\t${jobIDs[$i]}\t${dataSourceDirs[$i]}\t${queueStatuses[$i]}\t${lastRunDates[$i]}\t${previousMaxMs[$i]}"
	done
done



