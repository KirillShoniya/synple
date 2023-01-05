#!/bin/bash
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

DATE_TIME_NOW=$(date +'%Y-%m-%d %H:%M:%S');
DEFAULT_COMPRESSION_LEVEL=9;
is_telegram_available=0;

function logger() {
  # Prints specified message into stdout
  # first argument is logging level
  # second argument is logging message
  printf "[$(date +'%Y-%m-%d %H:%M:%S:%3N')] - $1 - $2\n";
}

function notify_telegram {
  # Send notification using Telegram API
  # first argument is Telegram bot token
  # second argument is Telegram chat id
  # third argument is notification message
  logger "INFO" "Sending request to Telegram API";
  curl -s -X POST \
   -H 'Content-Type: application/json' \
   -d "{\"chat_id\": \"$2\", \"text\": \"$3\", \"disable_notification\": true}" \
   https://api.telegram.org/bot$1/sendMessage \
   > /dev/null

   status_code=$(
    curl --write-out %{http_code} -s -X POST -H 'Content-Type: application/json' \
       -d "{\"chat_id\": \"$2\", \"text\": \"$3\", \"disable_notification\": true}" \
       https://api.telegram.org/bot$1/sendMessage \
       > /dev/null
    );

   if [[ "$status_code" != 200 ]] ; then
     logger "CRITICAL" "Telegram API status code is not 200";
     return 1;
   else
     return 0;
   fi
}

function notify_system {
  # Send system notification using notify-send
  # first argument is notification show delay in milliseconds
  # second argument is notification message
  html_translated=$(echo "$2" | sed '{s/\\n/\r/g}');
  notify-send -t $1 "$html_translated";
  if [ $? -ne 0 ]; then
    return 1;
  else
    return 0;
  fi
}

function notify() {
  # first argument is time delay in milliseconds to
  #   display notification in system. Not used when
  #   Telegram notification is available
  # second argument is notification text
  #   Time delay is not used in Telegram notification process
  logger "INFO" "$2"
  if [ $is_telegram_available -eq 1 ]; then
    result=$(notify_telegram $telegram_token $telegram_chat_id "$DATE_TIME_NOW\n$2");
    if [ "$result" != 0 ]; then
      notify_system $1 "$DATE_TIME_NOW\n$2";
    fi
  else
    notify_system $1 "$DATE_TIME_NOW\n$2";
  fi
}

function backup() {
  # Create backup of specified directory into specified path
  # first argument is local path
  # second argument is archive path
  tar --exclude "node_modules" -I pigz -cf $2/$(date +'%m-%d-%Y').tar.gz $1 &>/dev/null;
  if [ $? -ne 0 ]; then
    echo 1;
  else
    echo 0;
  fi
}

function sync() {
  # Processing synchronisation between remote and local directory
  # New files will be created, deleted file from remote directory will be deleted locally
  # first argument is remote username
  # second argument is remote host
  # third argument is remote path
  # fourth argument is local path
  rsync -az --delete --update --progress --exclude='node_modules' $1@$2:$3 $4 &>/dev/null;
  if [ $? -ne 0 ]; then
    echo 1;
  else
    echo 0;
  fi
}

if [ -z "$username" ]; then
  logger "CRITICAL" "Remote username must be specified";
  exit 1;
else
  logger "INFO" "Remote username is: '$username'";
fi

if [ -z "$host" ]; then
  logger "CRITICAL" "Remote host must be specified";
  exit 1;
else
  logger "INFO" "Remote host is: '$host'";
fi

if [ -z "$remote_path" ]; then
  logger "CRITICAL" "Remote path must be specified";
  exit 1;
else
  logger "INFO" "Remote path is: '$remote_path'";
fi

if [ -z "$local_path" ]; then
  echo "Local path must be specified";
  exit 1;
else
  logger "INFO" "Local path is: '$local_path'";
fi

if [ -z "$archive_path" ]; then
  echo "Archive path must be specified";
  exit 1;
else
  archive_path=$archive_path/$(date +'%m/%d/%Y')
  logger "INFO" "Archive path is: '$archive_path'";
  mkdir -p $archive_path;
fi

if [ -z "$compression_level" ]; then
  logger "INFO" "Compression level is not specified. Default is: $DEFAULT_COMPRESSION_LEVEL";
  compression_level=$DEFAULT_COMPRESSION_LEVEL;
else
  logger "INFO" "Compression level is: '$compression_level'";
fi

if [ ! -z "$telegram_token" ] || [ ! -z "$telegram_chat_id" ]; then
  logger "INFO" "Using Telegram notifications";
  is_telegram_available=1;
else
  logger "WARNING" "Telegram token is not configured. Using system notifications";
  is_telegram_available=0;
fi

notify 3000 'Backuping sync folder';
backup_result=$(backup $local_path $archive_path);
if [ "$backup_result" != 0 ]; then
  notify 10000 "Something went wrong while backup process";
  exit 1;
else
  notify 5000 "Backup created successfully";

  notify 5000 "Start folders sync";
  sync_result=$(sync $username $host $remote_path $local_path);
  if [ "$sync_result" != 0 ]; then
    notify 10000 "Directory sync FAILED";
    exit 1;
  else
    notify 5000 "Directory sync completed successfully";
  fi
fi