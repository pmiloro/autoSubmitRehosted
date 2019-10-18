#!/bin/bash

#Cygnus file structure information
CACTUS_DIR="$HOME/data/Cactus"
CACTUS_PAR_DIRECTORY="$CACTUS_DIR/par/"
SETTINGS_DIR="$CACTUS_DIR/simfactory/etc/"

#Settings for the run to be submitted; $DEF_CONFIG should be changed to the appropriate configuration in
#./simfactory/bin/sim remote --cygnus list-configurations
DEF_CONFIG="newSub"
DEF_WALLTIME="24:00:00"
DEF_PROCS="112"


SIM_OUTPUT_DIR=$(grep -o "\w*$HOME/\w*/\w*" "${SETTINGS_DIR}defs.local.ini")

STATUS_FILE="status.txt"
USERNAME="pmiloro3"

#Get all simulations listed in queue
sims=($(showq | grep $USERNAME))
queueSizeCurrent=${#sims[@]}


#Field Tokens:
#PFN: Parfile Name
#PSL: Parfile Source Loc
#SMN: Simulation Name
#JID: Job ID (Queue ID, not simfactory ID)
#DSD: Data Source Directory (where simulation data is output to on Cygnus)
#QUS: Queue Status
#LRD: Last Run Date
#PMM: Previous Maximum M

#Partial Tokens (for incomplete fields):
#JI: Unset Job ID
#QU: Unset Queue Status
#LR: Unset Last Run Date
#DS: Unset Data Source Directory

#Simulations are always assumed to have at least a parfile, parfile source, and name;
#Previous Maximum M is reset with every run, so no need to repeatedly update it anyway

function writeToExternalFile () {
	searchParam=$1
	fieldToken=$2
	newData=$3
	destFile=$4

	#Get line text and number of the search parameter in the status file
	statusLine=$(grep $searchParam $STATUS_FILE)
	statusLineNum=$(grep -n $searchParam $STATUS_FILE | cut -f1 -d:)
	#Grab the text we're going to replace
	dataToReplace=$(echo $statusLine | grep -o "\w*$fieldToken\:\w*")

	#Replace the original data with the new data in-place
	sed -i "${statusLineNum}s/${dataToReplace}/${newData}/" $destFile

}

function updateStatuses () {
	thisID=$1
	sStatus=$2
	isNew=$3
	if isNew; then
		#If the submission spits out an abort message, then cancel the rest of the process and report the error
		if [$sStatus | grep "Aborting"]; then
			writeToExternalFile $thisID "JI" "JID:ERROR" $STATUS_FILE
			writeToExternalFile $thisID "QU" "QUS:ERROR" $STATUS_FILE
		else
			#Surprisingly difficult to assess successful entry into Cygnus queue, will have
			#to settle for checking if the queue size increased or not
			sims=($(showq | grep $USERNAME))
			if [${#sims[@]} > queueSizeCurrent]; then
				queueSizeCurrent=${#sims[@]}
				#Update simulation data with the new run profiles
				IFS="\s\s\s\s\s\s\s\s";  read -ra line <<< ${sims[$queueSizeCurrent-1]}
				#Update Job ID
				writeToExternalFile $thisID "JI" "JID:${line[0]}" $STATUS_FILE
				#Update queue status
				writeToExternalFile $thisID "QU" "QUS:${line[2]}" $STATUS_FILE
				#Update last run date
				writeToExternalFile $thisID "LR" "LRD:${line[4]}" $STATUS_FILE
			else
				writeToExternalFile $thisID "JI" "JID:ERROR" $STATUS_FILE
				writeToExternalFile $thisID "QU" "QUS:ERROR" $STATUS_FILE

			fi
		fi
	else
		#If the submission spits out an abort message, then cancel the rest of the process and report the error
		if [$sStatus | grep "Aborting"]; then
			writeToExternalFile $thisID "JID" "JID:ERROR" $STATUS_FILE
			writeToExternalFile $thisID "QUS" "QUS:ERROR" $STATUS_FILE
		else
			#Surprisingly difficult to assess successful entry into Cygnus queue, will have
			#to settle for checking if the queue size increased or not
			sims=($(showq | grep $USERNAME))
			if [${#sims[@]} > queueSizeCurrent]; then
				queueSizeCurrent=${#sims[@]}
				#Update simulation data with the new run profiles
				line=(${sims[queueSizeCurrent-1]})
				#IFS="\s\s\s\s\s\s\s\s";  read -ra line <<< ${sims[$queueSizeCurrent-1]}
				#Update Job ID
				writeToExternalFile $thisID "JID" "JID:${line[0]}" $STATUS_FILE
				#Update queue status
				writeToExternalFile $thisID "QUS" "QUS:${line[2]}" $STATUS_FILE
				#Update last run date
				writeToExternalFile $thisID "LRD" "LRD:${line[4]}" $STATUS_FILE
			else
				writeToExternalFile $thisID "JID" "JID:ERROR" $STATUS_FILE
				writeToExternalFile $thisID "QUS" "QUSs:ERROR" $STATUS_FILE

			fi
		fi
	fi

}

for i in "${sims[@]}"
do
	#Split showq output by the delimiter they use (eight spaces)
	#IFS="\s\s\s\s\s\s\s\s";  read -ra line <<< $i
	line=($i)
	#Grab the jobID and status from this line
	jobId=${line[0]}
	queueStatus=${line[2]}
	writeToExternalFile "JID:$jobID" "QUS" "QUS:$queueStatus" $STATUS_FILE
done

#Get all simulations in the status file by their parfile name
trackedSims=($(grep -o "\w*PFN\:w*" $STATUS_FILE))

#Separate the new parfiles from ones that have already been run or are running
newPFNs=()
runningOrCompletedJIDs=()
for i in "${trackedSims[@]}"
do
	#If that parfile has a job ID
	if [grep $i $STATUS_FILE | grep -o "\w*JID\:\w*"]; then
		#then it's already been submitted at least once
		runningOrCompletedJIDs+=(grep $i $STATUS_FILE | grep -o "\w*JID\:\w*")
	else
		#if it doesn't it's a new parfile to be dealt with
		newPFNs+=($i)
	fi
done


#Separate the running parfiles from the finished ones
completedJIDs=${runningOrCompletedJIDs}
for i in "${runningOrCompletedJIDs[@]}"
do
	for j in "${sims[@]}"
	do
		#If we find the tracked sim in the sims array, it's still in queue, so 
		#remove it from the array of sims we need to take action on
		if [echo $j | grep $i]; then
			completedJIDs=${newOrCompletedJIDs[@]/$i}
		fi
	done
done

#Create new simulations and submit them for new parfiles
for i in "${newPFNs[@]}"
do
	#Get assigned name for this parfile
	simName=$(grep $i $STATUS_FILE | grep -o "\w*SMN\:\w*")
	parName="$CACTUS_PAR_DIRECTORY$i"
	#Try submitting it to the queue with the configured settings, update either with error message or with successful result
	submitStatus=$($CACTUS_DIR/simfactory/bin/sim create-submit $simName --configuration=$DEF_CONFIG --parfile=par/$parName --walltime=$DEF_WALLTIME --procs=$DEF_PROCS)
	updateStatuses $i $submitStatus
	writeToExternalFile $i $DS "$DSD:$SIM_OUTPUT_DIR$simName" $STATUS_FILE
done

#Restart the simulations that have finished, if any, and update their maximum M fields
for i in "${completedJIDs[@]}":
do
	simName=$(grep $i $STATUS_FILE | grep -o "\w*SMN\:\w*")
	parName=$(grep $i $STATUS_FILE | grep -o "\w*PFN\:\w*")
	
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

	#Update the previous maximum M field
	writeToExternalFile $i $PMM $lastM $STATUS_FILE

	#Then resubmit/restart the simulation and update statuses accordingly
	submitStatus=$($CACTUS_DIR/simfactory/bin/sim submit $simName --walltime=$DEF_WALLTIME --procs=$DEF_PROCS)
	updateStatuses $i $submitStatus
done



