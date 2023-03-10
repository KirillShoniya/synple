### Simple folder sync

This script do synchronization from remote to local directory.

![Main diagram](diagrams/main.png)

### Requirements

This script use only SSH keys.

Tested on Ubuntu 22.04

1. curl
2. rsync
3. pigz
4. notify-osd

To resolve those dependencies run this command:

```sudo apt install curl rsync pigz notify-osd```

### How to use?

Firstly you have to make script executable file

```chmod +x /path/to/sync.sh```

Done. Now you can run the script:

```
/path/to/sync.sh \
  -u <REMOTE_USER> 
  -h <REMOTE_HOST> 
  -r <REMOTE_PATH>
  -l <LOCAL_PATH> 
  -c <COMPRESSION_LEVEL> (optional)
  -a <BACKUP_PATH>
  -x <TELEGRAM_CHAT_ID> (optional)  
``` 

### How to use Telegram notifications?

Add this line into ```~/.bashrc```

```export SYNC_TELEGRAM_TOKEN='<BOT_TOKEN>'```

1. Create bot
2. Get bot token
3. Start to communicate with bot to create chat_id
4. Get chat_id using this command:
   1. ```shell
      curl https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
      ```
5. Set bot_token and chat_id as script command line arguments

**Note: Feel free to not use Telegram notifications. By default, OS notifications will be used.**