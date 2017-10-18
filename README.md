# Mycroft Upgrade Testing

```Bash
Usage: ./test-upgrade.sh [-s] [LOG_DIR]

    -s Skips installation tests
    LOG_DIR Directory to read Mycroft logs from. defaults to /var/log
```

**Current tests:**

 - apt-get remove, update and install, and upgrade returns 0
 - Processes shutdown and only one instance starts after install
 - `what's the weather` -> `* a high of *`
 - `what time is it` -> `*[AP]M*`
 
 ## Notes
 
 - Writes all command output logs to `logs/`
   - These are replaced every time so they won't build up
 - Will reset all logs in `LOG_DIR`