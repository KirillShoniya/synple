#!/usr/bin/env bash
while getopts u:h:r:l:c:a:x:o: flag
do
    case "${flag}" in
        u) username=${OPTARG};;
        h) host=${OPTARG};;
        r) remote_path=${OPTARG};;
        l) local_path=${OPTARG};;
        c) compression_level=${OPTARG};;
        a) archive_path=${OPTARG};;
        x) telegram_chat_id=${OPTARG};;
        o) log_file_path=${OPTARG};;
    esac
done

DATE_TIME_NOW=$(date -u +'%Y-%m-%d %H:%M:%S %Z')
DEFAULT_COMPRESSION_LEVEL=9

# Notification show delay in milliseconds
NOTIFICATION_DELAY_INFO=5000
NOTIFICATION_DELAY_WARNING=10000
NOTIFICATION_DELAY_CRITICAL=50000

telegram_token=$SYNC_TELEGRAM_TOKEN
is_telegram_available=0
is_log_enabled=0
is_log_file_created=0

function datetime_now () {
  local res=$(date -u +'%Y-%m-%d %H:%M:%S.%3N %Z')
  echo $res
}

function create_log_file () {
  if [ $is_log_enabled -eq 1 ]; then

    if [ ! -f "$log_file_path" ]; then
      touch $log_file_path

      if [ "$?" == 1 ]; then
        log_dir=$(dirname "$log_file_path")

        if [ ! -d "$log_dir" ]; then
          mkdir -p "$log_dir"

          if [ "$?" == 1 ]; then
            return 1
          fi

        else
          touch $log_file_path

          if [ "$?" == 1 ]; then
            return 1
          fi
        fi
      fi
    fi
  fi

  return 0
}

function logger() {
  # Prints specified message into stdout
  # Params:
  #    first argument is logging level
  #    second argument is logging message
  log_timestamp=$(datetime_now)

  if [ $is_log_file_created -eq 1 ]; then
    printf "[$log_timestamp] - $level - $2\n" >> "$log_file_path"
  fi

  # Logging colours
  green="\033[0;36m"
  red="\033[0;31m"
  gray="\033[1;37m"
  nc="\033[0m" # no color

  if [ "$1" == "WARNING" ]; then
    level=${gray}$1${nc}
  elif [ "$1" == "CRITICAL" ]; then
    level=${red}$1${nc}
  else
    level=${green}$1${nc}
  fi

  log_message_info=$2
  log_message_template="[$log_timestamp] - $level -"

  printf "$log_message_template $2\n"
}

function notify_telegram() {
  # Send notification using Telegram API
  # Params:
  #    first argument is Telegram bot token
  #    second argument is Telegram chat id
  #    third argument is notification message

  status_code=$(
    curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-Type: application/json' \
    -d "{\"chat_id\": \"$2\", \"text\": \"$3\", \"disable_notification\": true}" \
    https://api.telegram.org/bot$1/sendMessage
  )

  if [ "$status_code" != 200 ] ; then
    logger "WARNING" "Telegram response is not OK: $status_code"
    return 1
  fi
  return 0
}

function notify_system() {
  # Send system notification using notify-send
  # Params:
  #    first argument is notification level
  #    second argument is notification message

  SUMMARY="Directory sync"
  notification_delay=$NOTIFICATION_DELAY_INFO
  log_level=low
  # replace new line char to support notify-send format
  translated_message=$(echo "$2" | sed '{s/\\n/\r/g}')

  if [ "$1" == "WARNING" ]; then
    log_level=normal
    notification_delay=$NOTIFICATION_DELAY_WARNING
  elif [ "$1" == "CRITICAL" ]; then
    log_level=critical
    notification_delay=$NOTIFICATION_DELAY_CRITICAL
  fi

  notify-send "$SUMMARY" -t $notification_delay "$translated_message" --urgency="$log_level"

  if [ $? -ne 0 ]; then
    return 1
  fi
  return 0
}

function notify() {
  # Switch notification way between OS and TelegramAPI
  # Params:
  #    first argument is notification level
  #    second argument is notification text

  logger "$1" "$2"
  if [ $is_telegram_available -eq 1 ]; then
    notify_telegram $telegram_token $telegram_chat_id "$1\n$(datetime_now)\n$2"
    if [ $? != 0 ]; then
      notify_system $1 "$(datetime_now)\n$2"
    fi
  else
    notify_system $1 "$(datetime_now)\n$2"
  fi
}

function backup() {
  # Create backup of specified directory into specified path
  # Params:
  #    first argument is local path
  #    second argument is archive path

  tar --exclude "node_modules" -I pigz -cf $2/$(date -u +'%Y_%m_%d_%H_%M').tar.gz $1 &>/dev/null
  if [ $? -ne 0 ]; then
    return 1
  fi
  return 0
}

function sync() {
  # Processing synchronisation between remote and local directory
  # New files will be created, deleted file from remote directory will be deleted locally
  # Params:
  #    first argument is remote username
  #    second argument is remote host
  #    third argument is remote path
  #    fourth argument is local path

  rsync -az --delete --update --exclude='node_modules' $1@$2:$3 $4 &>/dev/null
  if [ $? -ne 0 ]; then
    return 1
  fi
  return 0
}

if [ -z "$username" ]; then
  logger "CRITICAL" "Remote username must be specified"
  exit 1
else
  logger "INFO" "Remote username is: '$username'"
fi

if [ -z "$host" ]; then
  logger "CRITICAL" "Remote host must be specified"
  exit 1
else
  logger "INFO" "Remote host is: '$host'"
fi

if [ -z "$remote_path" ]; then
  logger "CRITICAL" "Remote path must be specified"
  exit 1
else
  logger "INFO" "Remote path is: '$remote_path'"
fi

if [ -z "$local_path" ]; then
  logger "CRITICAL" "Local path must be specified"
  exit 1
else
  logger "INFO" "Local path is: '$local_path'"
fi

if [ -z "$archive_path" ]; then
  logger "CRITICAL" "Archive path must be specified"
  exit 1
else
  archive_path=$archive_path/$(date +'%Y/%d/%m')
  logger "INFO" "Archive path is: '$archive_path'"
  mkdir -p $archive_path
fi

if [ -z "$compression_level" ]; then
  logger "WARNING" "Compression level is not specified. Default is: $DEFAULT_COMPRESSION_LEVEL"
  compression_level=$DEFAULT_COMPRESSION_LEVEL
else
  logger "INFO" "Compression level is: '$compression_level'"
fi

if [ ! -z "$SYNC_TELEGRAM_TOKEN" ] && [ ! -z "$telegram_chat_id" ]; then
  logger "INFO" "Using Telegram notifications"
  is_telegram_available=1
else
  logger "WARNING" "Telegram credentials is not specified. Switched to OS notifications"
  is_telegram_available=0
fi

if [ -z "$log_file_path" ]; then
  logger "WARNING" "Log file path is not specified. Logging to file disabled."
else
  is_log_enabled=1

  create_log_file

  if [ "$?" -eq 0 ]; then
    is_log_file_created=1
    logger "INFO" "Log file path is: '$log_file_path'"
  else
    logger "WARNING" "Unable to create log file: '$log_file_path'"
  fi
fi

notify "INFO" 'Backuping sync folder'
backup $local_path $archive_path
if [ $? != 0 ]; then
  notify "CRITICAL" "Something went wrong while backup process"
  exit 1
else
  notify "INFO" "Backup created successfully"

  notify "INFO" "Start folders sync"
  sync $username $host $remote_path $local_path
  if [ $? != 0 ]; then
    notify "CRITICAL" "Directory sync FAILED"
    exit 1
  else
    notify "INFO" "Directory sync completed successfully"
  fi
fi