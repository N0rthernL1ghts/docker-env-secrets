# docker-env-secrets
Make secrets available as environment variables for seamless integration in Docker containers. Optimized for S6 supervised environment.

This is designed and optimized for use with [S6 Overlay](https://github.com/just-containers/s6-overlay) (See: https://github.com/N0rthernL1ghts/s6-rootfs).
To use with other init systems, check the [To utilize secrets with other init systems](#to-utilize-secrets-with-other-init-systems) section.

### Behavior
By default, secret names are normalized to uppercase to comply with environment variable naming conventions.
You can disable this behavior by setting environment variable `NORMALIZE_SECRET_NAMES` to `0`.

Secrets are stored in `/var/run/s6/container_environment` directory, where each secret is stored in a separate file. This can be adjusted with `SECRETS_EXPORT_PATH` environment variable.
`/var/run/s6/container_environment` is a default location and applies only to S6 Overlay. For other init systems, you can adjust this path to your needs.


### Usage
```Dockerfile
COPY --from=ghcr.io/n0rthernl1ghts/docker-env-secrets:latest ["/", "/"]
```

###### Recommended way to integrate with your image (example)
```Dockerfile
# ---------------------
# Build root filesystem
# ---------------------
FROM scratch AS rootfs

# Copy over base files
COPY ["./rootfs", "/"]

# Install S6 Overlay
COPY --from=ghcr.io/n0rthernl1ghts/s6-rootfs:3.2.0.2 ["/", "/"]

# Install init-docker-secrets service
COPY --from=ghcr.io/n0rthernl1ghts/docker-env-secrets:latest ["/", "/"]



# ---------------------
# Build image
# ---------------------
FROM alpine:latest

COPY --from=rootfs ["/", "/"]

...
...
```

### To utilize secrets with S6 Overlay
If you use S6 Overlay, then you're ready to go. You just need to use this shebang in your script.
```bash
#!/command/with-contenv bash

your-service --your-flags
```

Alternatively, you can use `s6-envdir` or similar tool.
```bash
s6-envdir /run/secrets_normalized your-service --your-flags
```

**Note:** Due to behaviour of `with-contenv`, environment variable `S6_KEEP_ENV` must be set to `0`.  
Otherwise, secrets will not be loaded in the environment. If this is not desirable, see [To utilize secrets with other init systems](#to-utilize-secrets-with-other-init-systems) section for alternative loading methods. In short, using `source /usr/local/lib/load-env /run/s6/container_environment` should be sufficient.

#### Important
For this to work, you need to make all your core services dependent of init-docker-secrets service.


### To utilize secrets with other init systems
If you want to use it with other init systems, use this version of docker file:
```Dockerfile
# ---------------------
# Build root filesystem
# Note that we use busybox as base image and use /rootfs as rootfs build directory
# Busybox is used only for building rootfs, and is not used in the final image
# ---------------------
FROM busybox AS rootfs

# Copy over base files
COPY ["./rootfs", "/rootfs/"]

# Install init-docker-secrets service
COPY --from=ghcr.io/n0rthernl1ghts/docker-env-secrets:latest ["/", "/rootfs/"]

# Remove S6 Overlay specific files
RUN set -eux \
    && rm -rfv "/rootfs/etc/s6-overlay/"

# Or this to remove only init-docker-secrets files
# RUN set -eux \
#    && rm -rfv "/rootfs/etc/s6-overlay/s6-rc.d/init-docker-secrets"
#    && rm -rfv "/rootfs/etc/s6-overlay/s6-rc.d/user/contents.d/init-docker-secrets"
    

# ---------------------
# Build image
# ---------------------
FROM alpine:latest

COPY --from=rootfs ["/rootfs/", "/"]

ENV SECRETS_EXPORT_PATH=/run/secrets_normalized
ENV NORMALIZE_SECRET_NAMES=1
...
...
```

Also, check [init-docker-secrets-run.sh](src/init-docker-secrets-run.sh) and [load-env.sh](src/load-env.sh) scripts to understand how things are working.
It should be as easy to adapt it by setting `SECRETS_EXPORT_PATH` environment variable to the directory where normalized secrets are to be stored.

example:
```bash
# If not set in Dockerfile use: export SECRETS_EXPORT_PATH=/run/secrets_normalized 
/usr/local/bin/init-docker-secrets
```

Then, before starting the service, you just need to load each secret file into the environment.
To do this, you can use bundled 'load-env' script.
```bash
source /usr/local/lib/load-env /run/secrets_normalized
your-service --your-flags
```

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.