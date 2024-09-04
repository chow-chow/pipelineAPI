# PipelineAPI

This application exemplifies how to automate the building of an infrastructure for the development and monitoring of metrics for a REST API in a microservices environment using Kubernetes (k8s-kind) and Helm Charts.

## Startup

To start the application, run the following command:

```bash
make start
```

This will install all the necessary dependencies (Prometheus, Grafana, Loki-Promtail, Postgres) alongside the API deployment within the cluster. 

If you want to take down the cluster, run:

```bash
make stop
```

If you encounter the error `too many open files` inside Promtail pods, try the following commands to increase the limits:

```bash
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=1024
sudo sysctl -w fs.file-max=1000000
ulimit -n 1000000
```
