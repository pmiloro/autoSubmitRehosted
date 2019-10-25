#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#Cygnus file structure information
CACTUS_DIR="$HOME/data/Cactus"
CACTUS_PAR_DIRECTORY="$CACTUS_DIR/par/"
SETTINGS_DIR="$CACTUS_DIR/simfactory/etc/"

#Settings for the run to be submitted; $DEF_CONFIG should be changed to the appropriate configuration in
#./simfactory/bin/sim remote --cygnus list-configurations
DEF_CONFIG="sim"
DEF_WALLTIME="8:00:00"
DEF_PROCS="7"
#Max of number of active simulations you want in queue at one time
MAX_QUEUE_SIZE=10

SIM_OUTPUT_DIR=$(grep -o "\w*$HOME/\w*/\w*" "${SETTINGS_DIR}defs.local.ini")
echo "$SIM_OUTPUT_DIR"

STATUS_FILE="$DIR/status.txt"
USERNAME="pmiloro3"

#Get all simulations listed in queue
SAVEIFS=$IFS   # Save current IFS
IFS=$'\n'      # Change IFS to new line
sims=($(showq | grep $USERNAME))
IFS=$SAVEIFS   # Restore IFS

for i in "${sims[@]}"; do
	true
	#echo "$i"
done
queueSizeCurrent=${#sims[@]}
queueSizeLast=$queueSizeCurrent

#echo "$queueSizeCurrent"

#If the queue is filled, there's nothing more to be done
if [ $queueSizeCurrent -ge $MAX_QUEUE_SIZE ] ; then
	exit 0
fi


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

function getQueueSizeCurrent () {
	#Get all simulations listed in queue
	SAVEIFS=$IFS   # Save current IFS
	IFS=$'\n'      # Change IFS to new line
	sims=($(showq | grep $USERNAME))
	IFS=$SAVEIFS   # Restore IFS
		
	queueSizeCurrent=${#sims[@]}
}

function writeToExternalFile () {
	searchParam=$1
	fieldToken=$2
	#echo "Second parameter is $2"
	#echo "Field token is $fieldToken"
	newData=$3
	destFile=$4

	if grep $searchParam $STATUS_FILE; then
		#Get line text and number of the search parameter in the status file
		statusLine=$(grep "$searchParam" "$STATUS_FILE")
		#echo "Status line is $statusLine"
		statusLineNum=$(grep -n "$searchParam" "$STATUS_FILE" | cut -f1 -d:)
		#echo "Status line number is: $statusLineNum"
		#Grab the text we're going to replace
		dataToReplace=$(echo "$statusLine" | grep -Po "$fieldToken"'[^\s]*')
		#echo "Field token is: $fieldToken"
		#echo "Data to replace is: $dataToReplace"
		#Replace the original data with the new data in-place
		#echo "sed -i "${statusLineNum}s;${dataToReplace};${newData};" $destFile"
		sed -i "${statusLineNum}s;${dataToReplace};${newData};" $destFile
	fi 
}

function updateStatuses () {
	thisID=$1
	sStatus=$2
	isNew=$3
	if [ "$isNew" = true ]; then
		#If the submission spits out an abort message, then cancel the rest of the process and report the error
		if "$sStatus" | grep -q "Aborting"; then
			echo "testing2A"
			writeToExternalFile $thisID "JI:" "JID:ERROR" $STATUS_FILE
			writeToExternalFile $thisID "QU:" "QUS:ERROR" $STATUS_FILE
		else
			#Surprisingly difficult to assess successful entry into Cygnus queue, will have
			#to settle for checking if the queue size increased or not			
			getQueueSizeCurrent
			if [ $queueSizeCurrent -gt $queueSizeLast ]; then
				#Update simulation data with the new run profiles
				line=(${sims[(($queueSizeCurrent-1))]})
				#Update data source directory
				writeToExternalFile "$thisID" "DS:" "DSD:$SIM_OUTPUT_DIR" $STATUS_FILE
				#Update Job ID
				writeToExternalFile "$thisID" "JI:" "JID:${line[0]}" $STATUS_FILE
				#Update queue status
				writeToExternalFile "$thisID" "QU:" "QUS:${line[2]}" $STATUS_FILE
				#Update last run date
				this_LRD="${line[5]} ${line[6]} ${line[7]} ${line[8]}"
				writeToExternalFile "$thisID" "LR:" "LRD:$this_LRD" $STATUS_FILE
			else
				writeToExternalFile "$thisID" "JI:" "JID:ERROR" $STATUS_FILE
				writeToExternalFile "$thisID" "QU:" "QUS:ERROR" $STATUS_FILE

			fi
		fi
	else
		#If the submission spits out an abort message, then cancel the rest of the process and report the error
		if "$sStatus" | grep "Aborting"; then
			writeToExternalFile $thisID "JID:" "JID:ERROR" "$STATUS_FILE"
			writeToExternalFile $thisID "QUS:" "QUS:ERROR" "$STATUS_FILE"
		else
			getQueueSizeCurrent
			if [ $queueSizeCurrent -gt $queueSizeLast ]; then
				#Update simulation data with the new run profiles
				line=(${sims[queueSizeCurrent-1]})
				#Update Job ID
				writeToExternalFile $thisID "JID:" "JID:${line[0]}" $STATUS_FILE
				#Update queue status
				writeToExternalFile $thisID "QUS:" "QUS:${line[2]}" $STATUS_FILE
				#Update last run date
                                this_LRD="${line[5]} ${line[6]} ${line[7]} ${line[8]}"
                                writeToExternalFile "$thisID" "LRD:" "LRD:$this_LRD" $STATUS_FILE

			else
				writeToExternalFile $thisID "JID:" "JID:ERROR" $STATUS_FILE
				writeToExternalFile $thisID "QUS:" "QUS:ERROR" $STATUS_FILE

			fi
		fi
	fi

}

#for i in "${sims[@]}"; do
#	echo "$i"
#done

for i in "${sims[@]}"
do
	#Split showq output by the delimiter they use (eight spaces)
	line=($i)
	#Grab the jobID and status from this line
	jobID=${line[0]}
	#echo "$jobID"
	queueStatus=${line[2]}
#	echo "$queueStatus"
#	echo "JID:$jobID"
	#writeToExternalFile "JID:$jobID" "QUS" "QUS:$queueStatus" "$STATUS_FILE"
#	echo "Queue status written"
done

#Get all simulations in the status file by their parfile name
trackedSims=($(grep -Po 'PFN\:[^\s]*' $STATUS_FILE))
#echo "trackedSims are:"
for i in "${trackedSims[@]}"; do
	#echo "$i"
	true
done

#echo "Tracked sim size is: "${#trackedSims[@]}""

#Separate the new parfiles from ones that have already been run or are running
newPFNs=()
runningOrCompletedJIDs=()
count=0
for i in "${trackedSims[@]}"
do
	count=$((count+=1))
	#echo "$count$i"
	#If that parfile has a job ID
	if grep "$i" $STATUS_FILE | grep -Po 'JID\:[^\s]*'; then
		#then it's already been submitted at least once
		#echo  "Grepped JID is: "$(grep "$i" "$STATUS_FILE" | grep -Po 'JID\:[^\s]*')""
		runningOrCompletedJIDs+=("$(grep "$i" "$STATUS_FILE" | grep -Po 'JID\:[^\s]*')")
	else
		#if it doesn't it's a new parfile to be dealt with
		newPFNs+=("$i")
	fi
done

for i in "${runningOrCompletedJIDs[@]}"
do
	#echo "rOCJID is: "$i""
	true
done

#Separate the running parfiles from the finished ones
completedJIDs=()

for i in "${completedJIDs[@]}";do
	echo "Starting completedJIDs are: $i"
	true
done

for i in "${runningOrCompletedJIDs[@]}"
do
	#Cut the JID: token off of the $i term
	searchParam="$i"
	#echo "Unsliced search param is "$searchParam""
	searchParam="${searchParam:4}"
	matches=0

	if [[ "$i" != "JID:ERROR" ]]; then
		for j in "${sims[@]}"
		do	
			line=($j)
			if [[ "${line[0]}" == "$searchParam" ]]; then
				matches=$(($matches+1))
			fi
		done
	
		if [[ $matches == 0 ]]; then
			completedJIDs+=("$i")
		fi
	fi
done
	
for i in "${completedJIDs[@]}";do
	echo "Completed JIDs are: $i"
done

for i in "${newPFNs[@]}";do
	echo "New PFNs are: "$i"" 
done


#Create new simulations and submit them for new parfiles
for i in "${newPFNs[@]}"
do
	#Get assigned name for this parfile
	simName=$(grep "$i" "$STATUS_FILE" | grep -Po 'SMN\:[^\s]*')
	simName=${simName:4}
	
	parLoc=$(grep "$i" "$STATUS_FILE" | grep -Po 'PSL\:[^\s]*')
	parLoc="${parLoc:4}${i:4}"
	
	#echo "Sim directory is: $SIM_OUTPUT_DIR"
	#echo "parLoc is: $parLoc"
	#echo "simName is: $simName"
 	getQueueSizeCurrent
	#echo "Current queue size is $queueSizeCurrent"
	if [ $queueSizeCurrent -lt $MAX_QUEUE_SIZE ]; then		
		#Try submitting it to the queue with the configured settings, update either with error message or with successful result
		queueSizeLast=$queueSizeCurrent
		#echo "Queue size last is $queueSizeLast"
		cd "$CACTUS_DIR" 
		submitStatus=$("$CACTUS_DIR"/simfactory/bin/sim create-submit "$simName" --configuration="$DEF_CONFIG" --parfile=par/"$parLoc" --walltime="$DEF_WALLTIME" --procs="$DEF_PROCS")
		updateStatuses "$i" "$submitStatus" true
		cd "$DIR"
	fi 
done

#Restart the simulations that have finished, if any, and update their maximum M fields
#echo "Length of completedJIDs is: ${#completedJIDs[@]}"

for i in "${completedJIDs[@]}"; do
	#echo "$i"
	simName=$(grep "$i" "$STATUS_FILE" | grep -Po 'SMN\:[^\s]*')
	parName=$(grep "$i" "$STATUS_FILE" | grep -Po 'PFN\:[^\s]*')
	
	echo "Sim name is: $simName"	

	#Remove tokens
	simName="${simName:4}"
	internalFolderName="${parName:4}"
	
	#echo "Simulation name is: $simName"
	#echo "Parfile name is: $parName"	

	simLoc="$SIM_OUTPUT_DIR/$simName"
	#echo "Sim loc is: $simLoc"
	activeFolder=$(ls "$simLoc/" | grep "active")
	#Location where the output data for each simulation is stored
	dataLoc="$simLoc/$activeFolder/$internalFolderName/"
	
	#echo "Data loc is: $dataLoc"
	#echo "${dataLoc}ShiftTracker0.asc"

	#Get the last line of the shift tracker data so we can determine how far the simulation has progressed
	lastLine=$(tac "${dataLoc}ShiftTracker0.asc" | egrep -m 1 .)
	if [ ! -z "$lastLine" ]; then 
		line=($lastLine)
		lastM=${line[1]}

		#Update the previous maximum M field
		writeToExternalFile "$i" "PMM:" "$lastM" "$STATUS_FILE"

		getQueueSizeCurrent
		if [ $queueSizeCurrent -lt  $MAX_QUEUE_SIZE ]; then
			#Then resubmit/restart the simulation and update statuses accordingly
			#echo "Submitting to queue"
			queueSizeLast=$queueSizeCurrent
			cd "$CACTUS_DIR"
			#submitStatus=$("$CACTUS_DIR"/simfactory/bin/sim submit "$simName" --walltime="$DEF_WALLTIME" --procs="$DEF_PROCS")
			#updateStatuses "$i" "$submitStatus" false
			cd "$DIR"
		fi	
	else
		echo "Could not locate simulation data for simulation $simName"
	fi
done



