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

function notify_telegram {
  curl -s -X POST \
   -H 'Content-Type: application/json' \
   -d "{\"chat_id\": \"$2\", \"text\": \"$3\", \"disable_notification\": true}" \
   https://api.telegram.org/bot$1/sendMessage \
   > /dev/null
}

function notify_system {
  notify-send -t $1 $2
}

function notify() {
  # first argument is time delay in milliseconds to
  #   display notification in system. Not used when
  #   Telegram notification is available
  # second argument is notification text
  #   Time delay is not used in Telegram notification process
  if [ $is_telegram_available -eq 1 ]; then
    notify_telegram $telegram_token $telegram_chat_id "$DATE_TIME_NOW\n$2";
  else
    notify_system $1 "$DATE_TIME_NOW\n$2";
  fi
}

function backup() {
  notify 3000 'Backuping sync folder';
  tar --exclude "node_modules" -I pigz -cf $2/$(date +'%m-%d-%Y').tar.gz $1 &>/dev/null;
  result=$?;
  if [ $result -ne 0 ]; then
    echo 1;
  else
    echo 0;
  fi
}

function sync() {
  notify 5000 "Start folders sync";
  rsync -az --update --progress --exclude='node_modules' $1@$2:$3 $4 &>/dev/null;
  result=$?;
  if [ $result -ne 0 ]; then
    echo 1;
  else
    echo 0;
  fi
}

if [ -z "$username" ]; then
  echo "Remote username must be specified";
  exit 1;
else
  echo "Remote username is: '$username'";
fi

if [ -z "$host" ]; then
  echo "Remote host must be specified";
  exit 1;
else
  echo "Remote host is: '$host'";
fi

if [ -z "$remote_path" ]; then
  echo "Remote path must be specified";
  exit 1;
else
  echo "Remote path is: '$remote_path'";
fi

if [ -z "$local_path" ]; then
  echo "Local path must be specified";
  exit 1;
else
  echo "Local path is: '$local_path'";
fi

if [ -z "$archive_path" ]; then
  echo "Archive path must be specified";
  exit 1;
else
  archive_path=$archive_path/$(date +'%m/%d/%Y')
  echo "Archive path is: '$archive_path'";
  mkdir -p $archive_path;
fi

if [ -z "$compression_level" ]; then
  echo "Compression level is not specified. Default is: $DEFAULT_COMPRESSION_LEVEL";
  compression_level=$DEFAULT_COMPRESSION_LEVEL;
else
  echo "Compression level is: '$compression_level'";
fi

if [ ! -z "$telegram_token" ] || [ ! -z "$telegram_chat_id" ]; then
  echo "Using Telegram notifications";
  is_telegram_available=1;
else
  echo "Telegram token is not configured. Using system notifications";
  is_telegram_available=0;
fi

backup_result=$(backup $local_path $archive_path);
if [ $backup_result -ne 0 ]; then
  notify 10000 "Something went wrong while backup process";
  exit 1
else
  notify 5000 "Backup created successfully";

  sync_result=$(sync $username $host $remote_path $local_path);
  if [ $sync_result -ne 0 ]; then
    notify 10000 "Directory sync FAILED";
    exit 1
  else
    notify 5000 "Directory sync completed successfully";
  fi
fi
