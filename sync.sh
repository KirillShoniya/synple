while getopts u:h:r:l:c:a: flag
do
    case "${flag}" in
        u) username=${OPTARG};;
        h) host=${OPTARG};;
        r) remote_path=${OPTARG};;
        l) local_path=${OPTARG};;
        c) compression_level=${OPTARG};;
        a) archive_path=${OPTARG};;
    esac
done

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
  echo "Compression level is not specified. Default is: 9";
  compression_level=9;
else
  echo "Compression level is: '$local_path'";
fi

notify-send -t 3000 "Backuping sync folder" \
  && tar cf - $local_path | pigz -$compression_level -p 12 > $archive_path/$(date +'%m-%d-%Y').tar.gz \
  && notify-send -t 5000 "Start folders sync" \
  && rsync -az --update --progress $username@$host:$remote_path $local_path \
  && notify-send -t 60000 "Sync done successfully"
