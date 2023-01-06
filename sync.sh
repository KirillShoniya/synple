#!/usr/bin/env bash
while getopts u:h:r:l:c:a:t:x: flag
do
    case "${flag}" in
        u) username=${OPTARG};;
        h) host=${OPTARG};;
        r) remote_path=${OPTARG};;
        l) local_path=${OPTARG};;
        c) compression_level=${OPTARG};;
        a) archive_path=${OPTARG};;
        t) telegram_token=${OPTARG};;
        x) telegram_chat_id=${OPTARG};;
    esac
done

DATE_TIME_NOW=$(date +'%Y-%m-%d %H:%M:%S')
DEFAULT_COMPRESSION_LEVEL=9

# Notification show delay in milliseconds
NOTIFICATION_DELAY_INFO=5000
NOTIFICATION_DELAY_WARNING=10000
NOTIFICATION_DELAY_CRITICAL=50000

is_telegram_available=0

function logger() {
  # Prints specified message into stdout
  # Params:
  #    first argument is logging level
  #    second argument is logging message

  printf "[$(date +'%Y-%m-%d %H:%M:%S:%3N')] - $1 - $2\n"
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
  );

  if [[ "$status_code" != 200 ]] ; then
    logger "WARNING" "Telegram response is not OK: $status_code"
    return 1
  else
    return 0
  fi
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
  else
    return 0
  fi
}

function notify() {
  # Switch notification way between OS and TelegramAPI
  # Params:
  #    first argument is notification level
  #    second argument is notification text

  logger "$1" "$2"
  if [ $is_telegram_available -eq 1 ]; then
    notify_telegram $telegram_token $telegram_chat_id "$1\n$DATE_TIME_NOW\n$2"
    if [ "$?" != 0 ]; then
      notify_system $1 "$DATE_TIME_NOW\n$2"
    fi
  else
    notify_system $1 "$DATE_TIME_NOW\n$2"
  fi
}

function backup() {
  # Create backup of specified directory into specified path
  # Params:
  #    first argument is local path
  #    second argument is archive path

  tar --exclude "node_modules" -I pigz -cf $2/$(date +'%Y_%m_%d_%H_%M').tar.gz $1 &>/dev/null
  if [ $? -ne 0 ]; then
    return 1
  else
    return 0
  fi
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
  else
    return 0
  fi
}

if [ -z "$username" ]; then
  logger "CRITICAL" "Remote username must be specified"
  exit 1
else
  logger "INFO" "Remote username is: '$username'"
fi

if [ -z "$host" ]; then
  logger "CRITICAL" "Remote host must be specified"
  exit 1;
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
  echo "Local path must be specified"
  exit 1
else
  logger "INFO" "Local path is: '$local_path'"
fi

if [ -z "$archive_path" ]; then
  echo "Archive path must be specified"
  exit 1
else
  archive_path=$archive_path/$(date +'%Y/%d/%m');
  logger "INFO" "Archive path is: '$archive_path'"
  mkdir -p $archive_path
fi

if [ -z "$compression_level" ]; then
  logger "WARNING" "Compression level is not specified. Default is: $DEFAULT_COMPRESSION_LEVEL"
  compression_level=$DEFAULT_COMPRESSION_LEVEL
else
  logger "INFO" "Compression level is: '$compression_level'"
fi

if [ ! -z "$telegram_token" ] && [ ! -z "$telegram_chat_id" ]; then
  logger "INFO" "Using Telegram notifications"
  is_telegram_available=1
else
  logger "WARNING" "Telegram credentials is not specified. Switched to OS notifications"
  is_telegram_available=0
fi

notify "INFO" 'Backuping sync folder'
backup $local_path $archive_path
if [ "$?" != 0 ]; then
  notify "INFO" "Something went wrong while backup process"
  exit 1
else
  notify "INFO" "Backup created successfully"

  notify "INFO" "Start folders sync"
  sync $username $host $remote_path $local_path
  if [ "$?" != 0 ]; then
    notify "CRITICAL" "Directory sync FAILED"
    exit 1;
  else
    notify "INFO" "Directory sync completed successfully"
  fi
fi