set -e
set -u

module load NGS_Demultiplex
module load ngs-utils
module load Python
module list

##source config file (zinc-finger.gcc.rug.nl.cfg OR gattaca.cfg)
myhost=$(hostname)
if [[ $myhost == *"gattaca"* ]]
then
	. gattaca.cfg
else
	. ${myhost}
fi

 

### Sequencer is writing to this location: $NEXTSEQDIR
### Looping through to see if all files
for i in $(ls -1 -d ${NEXTSEQDIR}/*/)
do
	## PROJECTNAME is sequencingStartDate_sequencer_run_flowcell
	PROJECTNAME=$(basename ${i})
	DEBUGGER=${LOGSDIR}/${PROJECTNAME}_logger.txt
	OLDIFS=$IFS
	IFS=_
	set $PROJECTNAME
	sequencer=$2
	run=$3
	IFS=$OLDIFS
	## Check if there the run is already completed
	if [ -f ${NEXTSEQDIR}/${PROJECTNAME}/RunCompletionStatus.xml ]
	then
		### Check if the demultiplexing is already started
		if [ ! -f ${LOGSDIR}/${PROJECTNAME}_Demultiplexing.started ]
		then
			### Check if Samplesheet is there
                      	if [ -f ${SAMPLESHEETDIR}/${PROJECTNAME}.csv ]
                        then
				python $EBROOTNGSMINUTILS/automate_demultiplexing/checkSampleSheet.py --input ${SAMPLESHEETDIR}/${PROJECTNAME}.csv
				if [ $? == 1 ]
				then
					echo "There is something wrong in the samplesheet! Exiting" >> ${DEBUGGER}
					exit 1
				else
					echo  "Samplesheet is OK" >> ${DEBUGGER}
					#####
					## RUN PIPELINE PART ##
					#####
					RUNFOLDER="run_${run}_${sequencer}"
					LOGGERPIPELINE=${WORKDIR}/generatedscripts/${RUNFOLDER}/logger.txt
					echo "All checks are done. Logging from now on can be found: ${LOGGERPIPELINE}" >> ${DEBUGGER}

					## Check if Check file (if samplesheet is already there) is existing
                      		 	if [ -f ${SAMPLESHEETDIR}/${PROJECTNAME}_Check.txt ]
					then
						## Remove tmp Check file
                                                rm ${SAMPLESHEETDIR}/${PROJECTNAME}_Check.txt
						echo "rm ${SAMPLESHEETDIR}/${PROJECTNAME}_Check.txt" >> ${LOGGERPIPELINE}
                               		fi
					### Check if runfolder already exists
					if [ ! -d ${WORKDIR}/generatedscripts/$RUNFOLDER ]
					then
						mkdir -p ${WORKDIR}/generatedscripts/${RUNFOLDER}/
						echo "mkdir -p ${WORKDIR}/generatedscripts/${RUNFOLDER}/" >> ${LOGGERPIPELINE}
					fi

					## Direct to generatedscripts folder
					cd ${WORKDIR}/generatedscripts/${RUNFOLDER}/

					## Copy generate script and samplesheet
					cp ${SAMPLESHEETDIR}/${PROJECTNAME}.csv run_${run}_${sequencer}.csv
					echo "copied ${SAMPLESHEETDIR}/${PROJECTNAME}.csv to run_${run}_${sequencer}.csv" >> ${LOGGERPIPELINE}

                            		cp ${EBROOTNGS_DEMULTIPLEX}/generate_template.sh ./
					echo "Copied ${EBROOTNGS_DEMULTIPLEX}/generate_template.sh to ." >> ${LOGGERPIPELINE}
					echo "" >> ${LOGGERPIPELINE}

					### Generating scripts
					echo "Generated scripts" >> ${LOGGERPIPELINE}
					sh generate_template.sh ${sequencer} ${run}
					echo "cd ${WORKDIR}/runs/${RUNFOLDER}/jobs" >> ${LOGGERPIPELINE}
					cd ${WORKDIR}/runs/${RUNFOLDER}/jobs

					sh submit.sh
					echo "jobs submitted, pipeline is running" >> ${LOGGERPIPELINE}
                               		touch ${LOGSDIR}/${PROJECTNAME}_Demultiplexing.started
					echo "De demultiplexing pipeline is gestart, over een aantal uren zal dit klaar zijn \
					en word de data automatisch naar zinc-finger gestuurd, hierna  word de pipeline gestart" | mail -s "Het demultiplexen van ug is gestart op (`date +%d/%m/%Y` `date +%H:%M`)" ${ONTVANGER}
				fi
                        else
				echo "Samplesheet is missing, after 10 times a mail will be send to the user" >> ${DEBUGGER}
                                echo  "Samplesheet is not available" >> ${SAMPLESHEETDIR}/${PROJECTNAME}_Check.txt 
                        fi
                fi
	fi
if [ -f /groups/umcg-gaf/tmp05/Samplesheets/${PROJECTNAME}_Check.txt ]
then
	COUNT=$(cat /groups/umcg-gaf/tmp05/Samplesheets/${PROJECTNAME}_Check.txt | wc -l)
	if [ $COUNT == 10 ]
	then
		echo "Er is geen samplesheet gevonden op deze locatie: /groups/umcg-gaf/tmp05/Samplesheets/${PROJECTNAME}.csv" | mail -s "Er is geen samplesheet gevonden voor ${PROJECTNAME}" ${ONTVANGER}
		echo "mail has been sent to ${ONTVANGER}"
	fi
fi
done
