# Custom PostgreSQL Installation Guide

This guide will walk you through the process of installing and configuring a custom PostgreSQL setup using Docker.

## Prerequisites

- Docker
- Docker Compose

## Installation Steps

1. Clone the repository:
   ```
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Review the `docker-compose.yml` file:
   ```yaml:docker-compose.yml
   startLine: 1
   endLine: 25
   ```

3. Make sure the `pgscript.sh` is in the `scripts/` directory:
   ```shell:scripts/pgscript.sh
   startLine: 1
   endLine: 223
   ```

4. Start the Docker container:
   ```
   docker compose -f docker-compose.yml up -d
   ```

5. Wait for the installation to complete. This may take several minutes.

6. Once the installation is complete, you can connect to the PostgreSQL server:
   ```
   docker exec -it custom-postgresql psql -U postgres
   ```

## Configuration Details

- PostgreSQL Version: 16.3
- Custom block size: 32KB
- Custom segment size: 4GB
- Additional features: OpenSSL, LZ4 compression, Python support

## Connecting to the Database

- Host: localhost
- Port: 5433
- Username: postgres
- Password: PswdPost123
- Default database: mydb

## Maintenance

To stop the PostgreSQL server:
```
docker compose stop custom-postgresql
```

To start it again:
```
docker compose up -d custom-postgresql
```

## Uninstallation

To completely remove the PostgreSQL installation and associated resources, follow these steps in order:

1. Stop and remove the PostgreSQL container and associated volume:
   ```
   docker compose -f docker-compose.yml down -v
   ```

2. Remove the custom PostgreSQL image:
   ```
   docker rmi ubuntu:24.04
   ```

3. Remove the specific volume used by the custom PostgreSQL container:
   ```
   docker volume rm $(docker volume ls -q -f name=custom-postgresql_postgres-data)
   ```

4. Remove the specific network used by the custom PostgreSQL container (if any):
   ```
   docker network rm $(docker network ls -q -f name=custom-postgresql_default)
   ```

Note: These commands specifically target the custom PostgreSQL container and its associated resources. They will not affect other Docker resources on your system.

This will stop the container, remove the associated volume, image, and network specifically related to the custom PostgreSQL setup.

## Troubleshooting

If you encounter any issues, check the PostgreSQL log file inside the container:
```
docker exec custom-postgresql cat /home/postgres/pgsql/logfile
```

For more detailed information about the installation process, refer to the `pgscript.sh` file in the `scripts/` directory.
