# Custom PostgreSQL Installation and Docker Setup

This project provides a custom PostgreSQL installation script and a Docker setup for running a customized PostgreSQL instance.

## Features

- Custom PostgreSQL installation with specific configuration options
- Docker-based deployment for easy setup and portability
- Automated installation and configuration process
- Custom block size and segment size settings
- Python support
- OpenSSL integration
- LZ4 compression

## Prerequisites

- Docker and Docker Compose
- Bash shell

## Quick Start

1. Clone this repository:
   ```
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Start the Docker container:
   ```
   docker-compose up -d
   ```

3. The PostgreSQL server will be available on `localhost:5433`

## Custom PostgreSQL Installation

The `pgscript.sh` file contains a comprehensive script for installing and configuring PostgreSQL with custom options. Key features include:

- PostgreSQL version: 16.3
- Custom block size: 32KB
- Custom segment size: 4GB
- Python, OpenSSL, and LZ4 support

To run the installation script manually:

```
./scripts/pgscript.sh install
```

## Docker Setup

The `docker-compose.yml` file defines a service that:

1. Uses Ubuntu 24.04 as the base image
2. Installs necessary dependencies
3. Runs the custom PostgreSQL installation script
4. Starts the PostgreSQL server

## Configuration

You can modify the PostgreSQL configuration by editing the `pgscript.sh` file. Key variables include:

```shell:scripts/pgscript.sh
startLine: 3
endLine: 8
```

## Maintenance

The `pgscript.sh` script includes functions for stopping and uninstalling PostgreSQL:

- To stop PostgreSQL: `./scripts/pgscript.sh stop`
- To uninstall PostgreSQL: `./scripts/pgscript.sh uninstall`

## Data Persistence

PostgreSQL data is persisted using a Docker volume named `postgres-data`. This ensures that your data remains intact even if the container is stopped or removed.

## Security Note

The default password for the `postgres` user is set to `PswdPost123`. It's highly recommended to change this password in a production environment.