# PipelineAPI

## Startup

To start the application, run the following command:

```bash
make start
```

If you encounter the error `too many open files` inside Promtail pods, try the following commands to increase the limits:

```bash
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=512
sudo sysctl -w fs.file-max=1000000
ulimit -n 1000000
```