#!/bin/bash
####Setting variables#####
CURR_TS=$(date +'%d/%m/%Y %H:%M:%S:%3N')
DATE=$(date +'%d_%m_%Y')
SCRIPT_NAME="$0"
SCRIPT_NAME_WITHOUT_EXTENSTION=`basename -s .sh $SCRIPT_NAME`
TIME_DATE=`date`
MONITORING_LOG_FILE=/data/monitoring1/python/$SCRIPT_NAME_WITHOUT_EXTENSTION.log

RUNNING_PIPELINE_INFO_FILE=/data/monitoring1/python/runningPipelineInfo

PIPELINE_STATUS_INFO_FILE=/data/monitoring1/python/pipelineStatusInfoHistory_${DATE}
PIPELINE_STATUS_INFO_FILE_LATEST=/data/monitoring1/python/pipelineStatusInfo

PIPELINE_STATUS=''
PIPELINE_NAME=''
IP=`hostname -I | awk '{print $1}'`
echo "----------------------------------------------------------------" >> $MONITORING_LOG_FILE
echo "[$TIME_DATE][INFO] Script Start" >> $MONITORING_LOG_FILE
echo "[$TIME_DATE][INFO] Log File - $SCRIPT_NAME_WITHOUT_EXTENSTION.log" >> $MONITORING_LOG_FILE
####Check Existance Instance#######
function existance_instance {

    process_id=`ps -ef | grep -w $SCRIPT_NAME_WITHOUT_EXTENSTION | awk '{print $2}'`
    #echo $process_id
    if [[  -z $process_id ]]

    then
            echo "[$TIME_DATE][WARNING] Privious instance running : Y" >> $MONITORING_LOG_FILE
            echo "[$TIME_DATE][WARNING] Exit from process" >> $MONITORING_LOG_FILE
            echo "[$TIME_DATE][INFO] Script Finish" >> $MONITORING_LOG_FILE
            echo "[$TIME_DATE][INFO] Please check  $MONITORING_LOG_FILE"
            exit 1
    else
            check_file_exists

            echo "[$TIME_DATE][INFO] Script Finish" >> $MONITORING_LOG_FILE
            echo "[$TIME_DATE][INFO] Please check  $MONITORING_LOG_FILE"
    fi
}

###Check file exists####
function check_file_exists {

    if [ -f $RUNNING_PIPELINE_INFO_FILE ]

    then
            echo "[$TIME_DATE][INFO] File $RUNNING_PIPELINE_INFO_FILE is exists : Y" >> $MONITORING_LOG_FILE
            >  $PIPELINE_STATUS_INFO_FILE_LATEST
            read_file_content

    else
            echo "[$TIME_DATE][WARNING] $RUNNING_PIPELINE_INFO_FILE is exists : N" >> $MONITORING_LOG_FILE
            echo "[$TIME_DATE][INFO] Exit from process" >> $MONITORING_LOG_FILE
            echo "[$TIME_DATE][INFO] Script Finish" >> $MONITORING_LOG_FILE
            exit 1
    fi
}

####Read File###
function read_file_content {

    while IFS= read -r line

        do
            [[ $line =~ 'enabled='([^|]*) ]] && enabled=${BASH_REMATCH[1]}
            [[ $line =~ '|exec_cmd='([^|]*) ]] && exec_cmd=${BASH_REMATCH[1]}
            [[ $line =~ '|pipeline_name='([^|]*) ]] && PIPELINE_NAME=${BASH_REMATCH[1]}
            if [[ $enabled == 'yes' ]];

            then
                process_id=`pgrep -f "$exec_cmd"`
                echo $process_id
                if [[ ! -z $process_id ]];

                then
                    echo "[$TIME_DATE][INFO] Pipeline [$PIPELINE_NAME] is running : Y" >> $MONITORING_LOG_FILE
                    echo "[$TIME_DATE][INFO] Need to start pipeline [$PIPELINE_NAME] : N" >> $MONITORING_LOG_FILE
                    PIPELINE_STATUS='RUNNING'
                    prepare_entry_for_pipeline_status_info

                else
                    echo "[$TIME_DATE][WARNING] Pipeline [$PIPELINE_NAME] is running on $IP: N" >> $MONITORING_LOG_FILE
                    echo "[$TIME_DATE][INFO] Starting the pipeline [$PIPELINE_NAME]" >> $MONITORING_LOG_FILE
                    start_pipeline

                fi
            fi
        done < $RUNNING_PIPELINE_INFO_FILE
}

function start_pipeline {

    #Running commond to start pipeline
    $exec_cmd >/dev/null 2>&1 &
    sleep 5
    process_id=`pgrep -f "$exec_cmd"`
    if [[ ! -z $process_id ]];

    then
        if [ -d "/proc/${process_id}" ];

        then
            echo "[$TIME_DATE][INFO] ProcessID $process_id is running : Y" >> $MONITORING_LOG_FILE
            PIPELINE_STATUS='RESTARTED'
        else
            echo "[$TIME_DATE][WARNING] ProcessID $process_id is running : N" >> $MONITORING_LOG_FILE
            PIPELINE_STATUS='STOPPED'
        fi
    else
        echo "[$TIME_DATE][ERROR] Facing issue with starting Pipeline" >> $MONITORING_LOG_FILE
        echo "[$TIME_DATE][ERROR] Pipeline [$PIPELINE_NAME] is running : N" >> $MONITORING_LOG_FILE
        PIPELINE_STATUS='STOPPED'
    fi
    prepare_entry_for_pipeline_status_info

}

function prepare_entry_for_pipeline_status_info {

    PIPELINE_STATUS_INFO="ts=${CURR_TS}""|""pipeline_status=$PIPELINE_STATUS""|""pipeline_name=$PIPELINE_NAME"
    echo "$PIPELINE_STATUS_INFO" >> $PIPELINE_STATUS_INFO_FILE
    echo "$PIPELINE_STATUS_INFO" >> $PIPELINE_STATUS_INFO_FILE_LATEST
}

existance_instance
