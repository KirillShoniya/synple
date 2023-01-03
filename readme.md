### Simple folder sync

This script do synchronisation of local and remote directory.

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
  -a <BACKUP_PATH>
```