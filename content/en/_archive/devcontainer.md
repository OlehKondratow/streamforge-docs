+++
title = "Devcontainer"
type = "chapter"
weight = 1
+++

gitlab-runner register  --url https://gitlab.dmz.home  --token glrt-**

          args:
            - |
              echo "Starting GitLab Runner sidecar...";
              gitlab-runner run --working-directory /home/kinga --config /home/gitlab-runner/config.toml

cat /etc/gitlab-runner/config.toml
```
concurrent = 1
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "mworker1"
  url = "https://gitlab.dmz.home"
  id = 47
  token = "glrt-**"
  token_obtained_at = 2024-11-11T17:15:50Z
  token_expires_at = 0001-01-01T00:00:00Z
  tls-ca-file = "/etc/gitlab-runner/certs/ca.crt"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "registry.dmz.home/fin_bot/mbase/mongo_loader/docker:27.3.1-dind"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/etc/docker/certs.d:/etc/docker/certs.d:ro", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    network_mtu = 0

[[runners]]
  name = "mworker1-0"
  url = "https://gitlab.dmz.home"
  id = 55
  token = "glrt-**"
  token_obtained_at = 2025-05-11T03:32:21Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
```
================================
