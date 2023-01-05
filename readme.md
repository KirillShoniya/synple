### Simple folder sync

This script do synchronisation from remote to local directory.

![Main diagram](diagrams/main.png)

### Requirements

Tested on Ubuntu 22.04

1. curl
1. rsync
1. pigz

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
  -t <BOT_TOKEN> (optional)  
  -x <TELEGRAM_CHAT_ID> (optional)  
``` 

### How to use Telegram notifications

1. Create bot
2. Get bot token
3. Start communicate with bot to create chat_id
4. Get chat_id using this command:
   1. ```shell
      curl https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
      ```
5. Set bot_token and chat_id as script command line arguments