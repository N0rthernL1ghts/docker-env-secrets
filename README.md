# docker-env-secrets
Make secrets available as uppercase environment variables for seamless integration in Docker containers. Optimized for S6 supervised environment.

This is designed and optimized for use with [S6 Overlay](https://github.com/just-containers/s6-overlay) (See: https://github.com/N0rthernL1ghts/s6-rootfs).

If you want to use it with other init systems, check [init-docker-secrets-run.sh](src/init-docker-secrets-run.sh) script.
It should be as easy to adapt it by setting `NORMALIZED_SECRETS_PATH` environment variable to the directory where normalized secrets are to be stored.

example:
```bash
export NORMALIZED_SECRETS_PATH=/run/secrets_normalized 
src/init-docker-secrets-run.sh
```

Then you just need to load each secret file into the environment.
```bash
    source /run/secrets_normalized/SECRET_NAME
```

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

### To utilize secrets in your application
If you use S6 Overlay, then you're ready to go. You just need to use this shebang in your script.
```bash
#!/command/with-contenv bash
```

Alternatively, you can use `s6-envdir` or similar tool.
```bash
s6-envdir /run/secrets_normalized your-service --your-flags
```

### Important
For this to work, you need to make all your core services dependent of init-docker-secrets service.

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
```