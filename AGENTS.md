# AGENTS.md - Agent Operating Guidelines

This file provides project-specific context, conventions, and operational guidelines for AI coding agents working in the `docker-env-secrets` repository.

## 1. Project Overview

`docker-env-secrets` is a lightweight container initialization utility that reads secrets mounted as files (such as Docker secrets in `/run/secrets/`) and exposes them as container environment variables.
- Optimized for **S6 Overlay** (`/var/run/s6/container_environment`) via `s6-rc` service definitions.
- Fully compatible with generic init systems via configurable `SECRETS_EXPORT_PATH` and the standalone `load-env` helper.
- Packaged as a minimal `scratch` image containing only the root filesystem assets with zero external runtime dependencies.

## 2. Essential Commands

### Running Unit & Functional Tests
Execute the local test suite (unit and functional tests):
```bash
./tests/run-tests.sh
```
All unit and functional tests are self-contained and run against temporary directories created via `mktemp`.

### Running Integration Tests
Execute the containerized integration tests across S6 Overlay, generic Linux containers, and no-secrets scenarios:
```bash
./tests/run-integration-tests.sh
```

### Linting & Formatting
When modifying shell scripts in `src/` or `tests/`:
```bash
# Check syntax and style with ShellCheck
shellcheck src/*.sh tests/*.sh

# Verify formatting with shfmt (4 spaces indent)
shfmt -i 4 -d src/*.sh tests/*.sh

# Format files in place
shfmt -i 4 -w src/*.sh tests/*.sh
```

### Docker Build
Verify the container build locally:
```bash
docker build -t docker-env-secrets:local .
```

## 3. Project Structure

```
.
├── Dockerfile                  # Multi-stage build (busybox builder -> scratch final)
├── rootfs/                     # S6 Overlay filesystem files
│   ├── etc/s6-overlay/s6-rc.d/ # s6-rc service definitions (init-docker-secrets)
│   └── usr/local/bin/          # Destination mount targets
├── src/
│   ├── init-docker-secrets-run.sh # Main secret ingestion and export logic
│   └── load-env.sh             # Helper to source variables into calling shell
└── tests/
    ├── integration/            # Multi-scenario integration tests (s6, generic, no-secrets)
    ├── run-integration-tests.sh # End-to-end container integration test suite
    └── run-tests.sh            # Unit and functional regression test suite
```

## 4. Coding Standards & Conventions

All contributions and agent modifications must strictly adhere to the project standards defined below.

### Bash Scripts

#### Upstream Foundation & Codestyle
This set of rules builds on top of [google/styleguide -> shellguide](https://google.github.io/styleguide/shellguide.html) with some opinionated additions:

- Indent by 4 spaces (no tabs).
- Always use `main()` wrapper (functional programming); call `main "$@"` at script bottom.
- Use `local` variables when appropriate.
- Use `readonly` variables when appropriate.
- Use `lower_snake_case` for variables.
- Use `UPPER_SNAKE_CASE` for constants and exports.
- Use variables within strings with `${}` (e.g., `${var_name}`).
- Avoid `else` whenever possible (return early, guard clauses).
- Use `[[ ]]` for if conditions instead of `[ ]`.
- Use `printf` over `echo`.
- Output warnings and errors to `STDERR` (e.g., `>&2`).
- Keep runtime footprint minimal. The final container image is `FROM scratch` and must not require third-party packages.

#### Available Tools in `$PATH`
- **shellcheck**: Shell script linter.
- **shfmt**: Shell script formatter (`shfmt -i 4`).
- **jq**: Command-line JSON processor (required for Bitwarden scripts).

### Dockerfile

#### Style Alignment
- Retain pinned `alpine:3.24` (or current project base) builder.
- Multi-line `RUN set -eux && ...` block structure.
- 3-line separation between distinct build stages.
- Multi-stage copying through rootfs with `--chmod=0755`.
- Consistent line breaks around `ENV` and `ENTRYPOINT`.

## 5. Agent Instructions & Guardrails

1. **Verify Before and After**: Always run `./tests/run-tests.sh` before proposing changes and immediately after modifying any script in `src/` or `tests/`.
2. **Minimalism**: Do not introduce external dependencies or bloat the root filesystem.
3. **Compatibility**: Maintain dual compatibility:
   - S6 Overlay environments (shebang rewritten to `#!/command/with-contenv bash` during Docker build for S6 compatibility).
   - Standard POSIX/Linux containers with `/usr/bin/env bash`.
4. **Collision Handling**: Maintain the duplicate export detection and safety warnings in `init-docker-secrets-run.sh` to prevent unexpected overwrites.
