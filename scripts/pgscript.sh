#!/bin/bash

# Configuration variables
POSTGRES_VERSION="16.3"
POSTGRES_PREFIX="/var/lib/postgresql/pgsql"
DATA_DIR="/var/lib/postgresql/data"
LOGFILE="$POSTGRES_PREFIX/logfile"
BUILD_DIR="/var/lib/postgresql/postgresql-build"
PYTHON3_PATH=$(which python3)

# Helper functions
error_exit() {
    echo "Error: $1" >&2
    cleanup
    exit 1
}

warning_message() {
    echo "Warning: $1" >&2
}

cleanup() {
    echo "Cleaning up..."
    [ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR" || warning_message "Failed to remove build directory."
}

# This function checks for the presence of required tools and libraries:
check_prerequisites() {
    # 1. curl: Used for downloading PostgreSQL source
    command -v curl >/dev/null 2>&1 || error_exit "curl is required but not installed. Please install it using 'sudo apt install curl'."
    
    # 2. gcc: Required for compiling PostgreSQL
    command -v gcc >/dev/null 2>&1 || error_exit "gcc is required but not installed. Please install it using 'sudo apt install build-essential'."
    
    # 3. python3: Needed for PostgreSQL's PL/Python support
    command -v python3 >/dev/null 2>&1 || error_exit "Python3 is required but not installed. Please install it using 'sudo apt install python3'."
    
    # 4. lz4: Used for data compression in PostgreSQL
    if ! pkg-config --exists liblz4; then
        error_exit "LZ4 development library is required but not installed. Please install it using 'sudo apt install liblz4-dev'."
    fi
    
    # 5. openssl: Required for SSL support in PostgreSQL
    command -v openssl >/dev/null 2>&1 || error_exit "OpenSSL is required but not installed. Please install it using 'sudo apt install libssl-dev'."
}

ensure_install_directory() {
    if [ ! -d "$POSTGRES_PREFIX" ]; then
        mkdir -p "$POSTGRES_PREFIX" || error_exit "Failed to create installation directory."
    elif [ ! -w "$POSTGRES_PREFIX" ]; then
        chmod u+w "$POSTGRES_PREFIX" || error_exit "Failed to set permissions on installation directory."
    fi
}

create_postgres_user() {
    if ! id -u postgres >/dev/null 2>&1; then
        echo "Creating 'postgres' user..."
        useradd -m -s /bin/bash postgres || error_exit "Failed to create 'postgres' user."
    else
        echo "'postgres' user already exists."
    fi
}

# Installation functions
download_postgresql() {
    echo "Downloading PostgreSQL $POSTGRES_VERSION..."
    mkdir -p "$BUILD_DIR" || error_exit "Failed to create build directory."
    cd "$BUILD_DIR" || error_exit "Failed to enter build directory."

    if [ ! -f "postgresql-$POSTGRES_VERSION.tar.bz2" ]; then
        curl -O "https://ftp.postgresql.org/pub/source/v$POSTGRES_VERSION/postgresql-$POSTGRES_VERSION.tar.bz2" || error_exit "Failed to download PostgreSQL source."
    else
        echo "Source tarball already exists, skipping download."
    fi

    if [ ! -d "postgresql-$POSTGRES_VERSION" ]; then
        tar -xvf "postgresql-$POSTGRES_VERSION.tar.bz2" || error_exit "Failed to extract PostgreSQL source."
    else
        echo "Source directory already exists, skipping extraction."
    fi

    cd "postgresql-$POSTGRES_VERSION" || error_exit "Failed to enter PostgreSQL source directory."
}


configure_postgresql() {
    echo "Configuring PostgreSQL with custom options..."
    PYTHON_INCLUDE_DIR=$(python3-config --includes 2>/dev/null | sed 's/-I//g' | awk '{print $1}')
    PYTHON_LIB_DIR=$(python3-config --ldflags 2>/dev/null | sed 's/-L//g' | awk '{print $1}')

    if [ -z "$PYTHON_INCLUDE_DIR" ]; then
        PYTHON_INCLUDE_DIR="/usr/include/python3.10"
    fi
    if [ -z "$PYTHON_LIB_DIR" ]; then
        PYTHON_LIB_DIR="/usr/lib"
    fi

    export LDFLAGS="-L/usr/lib/x86_64-linux-gnu -L$PYTHON_LIB_DIR"
    export CPPFLAGS="-I/usr/include -I$PYTHON_INCLUDE_DIR"
    config_command="./configure \
        --prefix=\"$POSTGRES_PREFIX\" \
        --with-blocksize=32 \
        --with-segsize=4 \
        --with-openssl \
        --with-ssl=openssl \
        --with-lz4 \
        --with-python \
        --without-icu \
        --without-readline \
        --with-includes=\"/usr/include $PYTHON_INCLUDE_DIR\" \
        --with-libraries=\"/usr/lib/x86_64-linux-gnu $PYTHON_LIB_DIR\""
    echo "Configuration command: $config_command"
    eval $config_command || error_exit "Configuration failed."
}

verify_compilation_options() {
    echo "Verifying compilation options..."
    grep -E "BLCKSZ|RELSEG_SIZE" src/include/pg_config.h
}

compile_postgresql() {
    echo "Compiling PostgreSQL..."
    make || error_exit "Compilation failed."
    verify_compilation_options
}

install_postgresql() {
    echo "Installing PostgreSQL..."
    make install || error_exit "Installation failed."
}

setup_environment() {
    echo "Setting up environment variables..."
    if ! grep -q "$POSTGRES_PREFIX/bin" ~/.bashrc; then
        echo "export PATH=\"$POSTGRES_PREFIX/bin:\$PATH\"" >> ~/.bashrc || warning_message "Failed to update ~/.bashrc."
        source ~/.bashrc || warning_message "Failed to source ~/.bashrc."
    else
        echo "PATH already includes $POSTGRES_PREFIX/bin."
    fi
}

initialize_database() {
    echo "Initializing the PostgreSQL database..."
    mkdir -p "$DATA_DIR" || error_exit "Failed to create data directory."
    "$POSTGRES_PREFIX/bin/initdb" -D "$DATA_DIR" --username=postgres || error_exit "Database initialization failed."
    
    # Start PostgreSQL temporarily to make changes
    "$POSTGRES_PREFIX/bin/pg_ctl" -D "$DATA_DIR" -l "$LOGFILE" -w start

    # Create a new database
    "$POSTGRES_PREFIX/bin/createdb" mydb

    # Set password for postgres user
    "$POSTGRES_PREFIX/bin/psql" -c "ALTER USER postgres WITH PASSWORD 'PswdPost123';"

    # Configure PostgreSQL to allow external connections
    echo "host all all 0.0.0.0/0 md5" | tee -a "$DATA_DIR/pg_hba.conf"
    "$POSTGRES_PREFIX/bin/psql" -c "ALTER SYSTEM SET listen_addresses TO '*';"

    # Restart PostgreSQL to apply changes
    "$POSTGRES_PREFIX/bin/pg_ctl" -D "$DATA_DIR" -l "$LOGFILE" restart
}

start_postgresql() {
    echo "Starting PostgreSQL..."
    "$POSTGRES_PREFIX/bin/pg_ctl" -D "$DATA_DIR" -l "$LOGFILE" stop -m fast || true
    sleep 2
    "$POSTGRES_PREFIX/bin/pg_ctl" -D "$DATA_DIR" -l "$LOGFILE" -w start
    sleep 5  # Give the server a moment to start up
    if ! "$POSTGRES_PREFIX/bin/pg_isready" -q; then
        check_log_file
        error_exit "Failed to start PostgreSQL."
    fi
    echo "PostgreSQL started successfully."
}

check_log_file() {
    echo "Checking PostgreSQL log file for errors..."
    if [ -f "$LOGFILE" ]; then
        tail -n 50 "$LOGFILE"
    else
        echo "Log file not found at $LOGFILE"
    fi
}

verify_custom_options() {
    echo "Verifying custom build options..."
    "$POSTGRES_PREFIX/bin/psql" -d postgres -c "SHOW block_size;" || warning_message "Failed to verify block size."
    "$POSTGRES_PREFIX/bin/psql" -d postgres -c "SHOW segment_size;" || warning_message "Failed to verify segment size."
    echo "Checking PostgreSQL version and compile-time options:"
    "$POSTGRES_PREFIX/bin/postgres" -V
    "$POSTGRES_PREFIX/bin/pg_config" --configure
}

# Maintenance functions
stop_postgresql() {
    echo "Stopping PostgreSQL..."
    if command -v "$POSTGRES_PREFIX/bin/pg_ctl" &> /dev/null; then
        "$POSTGRES_PREFIX/bin/pg_ctl" -D "$DATA_DIR" stop -m fast || warning_message "Failed to stop PostgreSQL."
    else
        echo "pg_ctl command not found; assuming PostgreSQL is not running."
    fi
}

uninstall_postgresql() {
    echo "Uninstalling PostgreSQL..."
    stop_postgresql
    if [ -d "$POSTGRES_PREFIX" ]; then
        rm -rf "$POSTGRES_PREFIX" || warning_message "Failed to remove PostgreSQL directories."
        echo "PostgreSQL uninstalled successfully."
    else
        echo "No PostgreSQL installation detected."
    fi
}

# Main execution flow
perform_installation() {
    check_prerequisites
    create_postgres_user
    ensure_install_directory
    download_postgresql
    configure_postgresql
    compile_postgresql
    install_postgresql
    setup_environment
    initialize_database
    start_postgresql
    check_log_file
    verify_custom_options
    echo "PostgreSQL installed and configured successfully!"
}

# Ensure cleanup happens on script exit
trap cleanup EXIT

# Main function
case "$1" in
    stop)
        stop_postgresql
        ;;
    uninstall)
        uninstall_postgresql
        ;;
    install)
        perform_installation
        ;;
    *)
        echo "Usage: $0 {install|stop|uninstall}"
        exit 1
        ;;
esac