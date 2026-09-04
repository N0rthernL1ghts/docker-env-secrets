# docker-env-secrets

A lightweight container initialization utility that reads secrets mounted as files (such as Docker secrets in `/run/secrets/`) and exposes them as container environment variables.

The image is packaged as a minimal `scratch` container containing root filesystem assets with zero external runtime dependencies. It provides first-class support for [S6 Overlay](https://github.com/just-containers/s6-overlay) (see [s6-rootfs](https://github.com/N0rthernL1ghts/s6-rootfs)) via `s6-rc` service definitions, while maintaining full compatibility with generic container runtimes and init systems through a configurable export path and a standalone environment loader.

## Features

- **Automatic Name Normalization**: Converts secret file basenames to uppercase identifiers by default to align with POSIX environment variable conventions.
- **S6 Overlay Integration**: Includes ready-to-use `s6-rc` service definitions (`init-docker-secrets`) targeting `/var/run/s6/container_environment`.
- **Generic Init Compatibility**: Can export secrets to any directory via `SECRETS_EXPORT_PATH` and load them into a subshell or service using the bundled `/usr/local/lib/load-env` helper.
- **Collision Protection**: Detects and skips secrets that would overwrite existing export targets or collision candidates, logging warnings to `stderr`.
- **Symlink & Hidden File Handling**: Dereferences symbolic links (`find -L`) and automatically ignores hidden files (`.*`).
- **Minimal Footprint**: Packaged from `scratch` with zero third-party dependencies.

## Architecture & How It Works

1. **Ingestion**: The script scans `SECRETS_PATH` (default: `/run/secrets/`) for regular files and symlinks, ignoring hidden dotfiles.
2. **Name Resolution**: Each secret filename is either converted to uppercase (default) or preserved as-is, depending on the `NORMALIZE_SECRET_NAMES` configuration.
3. **Collision Check & Export**: The file is copied to `${SECRETS_EXPORT_PATH}/${EXPORT_NAME}`. If a file with the target name already exists or was already processed during the run, the duplicate is skipped and a warning is logged to `stderr`.
4. **Environment Exposure**:
   - In S6 Overlay environments, services running under `with-contenv` automatically inherit the exported variables from `/var/run/s6/container_environment/`.
   - In standard Linux containers, `/usr/local/lib/load-env` validates each secret name as a legal shell identifier (`^[a-zA-Z_][a-zA-Z0-9_]*$`) and exports it into the calling shell.

### Design Rationale: File Copying vs. Symlinking

Secrets are copied to `${SECRETS_EXPORT_PATH}` rather than symlinked for several operational reasons:

- **Mount Decoupling & Resilience**: Copying creates an independent, immutable snapshot in the target directory (typically `tmpfs`). If the source secrets volume is unmounted, cleared, or modified after container initialization, exported environment variables remain intact without producing broken (dangling) symlinks.
- **Permission & Least-Privilege Isolation**: Mounted secret files (e.g., in Docker Swarm or Kubernetes) often carry restrictive permissions such as `0400 root:root`, or reside in a restricted `0700` directory. Symlinks enforce the target file's access permissions and directory traversal rules. If a container service drops privileges to run as a non-root user, resolving a symlink to a root-only target results in `Permission denied` errors. Copying during root initialization creates standard, readable target files for supervised services.
- **Container Environment Immutability**: Process environments in Docker containers are fixed at the time processes are spawned. Dynamic secret rotation cannot update the environment of active running processes without a container restart or deliberate application reload mechanism, making symlink-based live file updates unnecessary for static container environments.

## Configuration

The utility is configured via container environment variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `SECRETS_PATH` | `/run/secrets/` | Source directory containing secret files or symbolic links. |
| `SECRETS_EXPORT_PATH` | `/var/run/s6/container_environment/` | Destination directory where processed secrets are written as individual files. **Do not override when using S6 Overlay.** |
| `NORMALIZE_SECRET_NAMES` | `1` | Set to `1` to convert secret names to uppercase (e.g., `db_password` -> `DB_PASSWORD`). Set to `0` to retain original file casing. |

## Integration & Usage

### 1. Integration with S6 Overlay

When using S6 Overlay, copy the root filesystem layers into your container build.

> [!WARNING]
> **Do not override `SECRETS_EXPORT_PATH` when using S6 Overlay.**
> S6 Overlay and `with-contenv` strictly rely on `/var/run/s6/container_environment/` to propagate environment variables to supervised services. Overriding this path will break the S6 supervisor configuration and prevent services from inheriting the exported secrets.

#### Dockerfile Example

```dockerfile
# ---------------------
# Build root filesystem
# ---------------------
FROM scratch AS rootfs

# Copy base filesystem files
COPY ["./rootfs", "/"]

# Install S6 Overlay
COPY --from=ghcr.io/n0rthernl1ghts/s6-rootfs:3.2.0.2 ["/", "/"]

# Install init-docker-secrets service
COPY --from=ghcr.io/n0rthernl1ghts/docker-env-secrets:latest ["/", "/"]

# ---------------------
# Build final image
# ---------------------
FROM alpine:latest

COPY --from=rootfs ["/", "/"]

# Service configuration...
```

#### Service Dependencies & Execution

The image registers `init-docker-secrets` as a `oneshot` service inside the default `user` bundle (`/etc/s6-overlay/s6-rc.d/user/contents.d/init-docker-secrets`). Any custom S6 services that require secrets at initialization should declare a dependency on `init-docker-secrets`.

To access the environment variables in a service run script, execute using `with-contenv`:

```bash
#!/command/with-contenv bash

exec your-service --your-flags
```

Alternatively, load variables using `s6-envdir`:

```bash
s6-envdir /var/run/s6/container_environment your-service --your-flags
```

> [!NOTE]
> When executing under `with-contenv`, the environment variable `S6_KEEP_ENV` must be set to `0`. If `S6_KEEP_ENV=1`, the existing container environment is preserved without reloading updated files from `/var/run/s6/container_environment`. If `S6_KEEP_ENV=0` cannot be set, use the generic loader method described below:
> ```bash
> source /usr/local/lib/load-env /var/run/s6/container_environment
> ```

---

### 2. Integration with Generic Init Systems & Standalone Containers

For containers not utilizing S6 Overlay, install the binaries and adjust the export directory.

#### Dockerfile Example

```dockerfile
# ---------------------
# Build root filesystem
# Note: busybox is used only as a build stage and is not included in the final image
# ---------------------
FROM busybox AS rootfs

# Copy base filesystem files
COPY ["./rootfs", "/rootfs/"]

# Install init-docker-secrets service
COPY --from=ghcr.io/n0rthernl1ghts/docker-env-secrets:latest ["/", "/rootfs/"]

# Remove S6 Overlay specific service files
RUN set -eux \
    && rm -rfv "/rootfs/etc/s6-overlay/"

# Or this to remove only init-docker-secrets files
# RUN set -eux \
#    && rm -rfv "/rootfs/etc/s6-overlay/s6-rc.d/init-docker-secrets" \
#    && rm -rfv "/rootfs/etc/s6-overlay/s6-rc.d/user/contents.d/init-docker-secrets"

# ---------------------
# Build final image
# ---------------------
FROM alpine:latest

COPY --from=rootfs ["/rootfs/", "/"]

ENV SECRETS_EXPORT_PATH=/run/secrets_normalized
ENV NORMALIZE_SECRET_NAMES=1
```

#### Ingestion and Environment Loading

1. Execute the initialization script in your entrypoint or startup routine to ingest secrets:
   ```bash
   # Optional: specify SECRETS_EXPORT_PATH if not defined in Dockerfile
   # export SECRETS_EXPORT_PATH=/run/secrets_normalized
   /usr/local/bin/init-docker-secrets
   ```

2. Source the secrets into the current shell process using `/usr/local/lib/load-env`:
   ```bash
   source /usr/local/lib/load-env /run/secrets_normalized
   exec your-service --your-flags
   ```

The `load-env` helper validates each filename to ensure it conforms to standard shell variable naming conventions (`^[a-zA-Z_][a-zA-Z0-9_]*$`) before exporting.

## Development & Testing

Automated tests and validation checks are included in the repository.

### Run Automated Tests

```bash
./tests/run-tests.sh
```

### Linting & Formatting

```bash
# Check syntax with ShellCheck
shellcheck src/*.sh tests/*.sh

# Verify formatting with shfmt (4-space indentation)
shfmt -i 4 -d src/*.sh tests/*.sh
```

### Build Docker Image

```bash
docker build -t docker-env-secrets:local .
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.