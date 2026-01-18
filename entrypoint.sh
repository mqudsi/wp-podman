#!/bin/sh

# Fail on error
set -e

UNIT_PID=""
MARIADB_PID=""

# Run on SIGTERM or similar to ensure timely and clean shutdown
cleanup() {
    echo ">> Received shutdown signal. Cleaning up..."

    # Stop NGINX Unit
    if [ -n "$UNIT_PID" ]; then
        echo ">> Stopping NGINX Unit (PID $UNIT_PID)..."
        kill -TERM "$UNIT_PID"
        # Wait for Unit to exit nicely
        wait "$UNIT_PID"
    fi

    # Stop MariaDB gracefully to flush buffers to disk
    # (Only important if we are mapping the database to the host for persistance)
    echo ">> Stopping MariaDB..."
    if mariadb-admin ping --silent; then
        mariadb-admin shutdown
    fi

    echo ">> Shutdown complete. Exiting."
    exit 0
}

# Catch SIGTERM (container stop) and SIGINT (Ctrl+C)
trap cleanup TERM INT

# Init MariaDB
echo ">> Initializing MariaDB..."
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mkdir -p /run/mysqld
    chown mysql:mysql /run/mysqld

    # Initialize DB data directory
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # Start MariaDB temporarily to create user/db
    /usr/bin/mariadbd-safe --datadir='/var/lib/mysql' --nowatch

    # Wait for MariaDB to wake up
    echo ">> Waiting for MariaDB to start..."
    for i in $(seq 1 20); do
        if mariadb-admin ping --silent; then
            break
        fi
        sleep 0.5
    done

    echo ">> Creating Database and User..."
    mariadb -e "CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mariadb -e "CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'wp_secure_pass';"
    mariadb -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wp_user'@'localhost';"
    mariadb -e "FLUSH PRIVILEGES;"

    # Kill the temp instance
    mariadb-admin shutdown
fi

# Configure WordPress
WP_PATH="/var/www/wordpress"
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo ">> Configuring wp-config.php..."
    if [ -f "$WP_PATH/wp-config-sample.php" ]; then
        cp "$WP_PATH/wp-config-sample.php" "$WP_PATH/wp-config.php"

        # Update db configuration (keeping default host "localhost")
        sed -i "s/database_name_here/wordpress/" "$WP_PATH/wp-config.php"
        sed -i "s/username_here/wp_user/" "$WP_PATH/wp-config.php"
        sed -i "s/password_here/wp_secure_pass/" "$WP_PATH/wp-config.php"

        # Set some default configuration options
        echo "define( 'DISALLOW_FILE_EDIT', true );" >> "$WP_PATH/wp-config.php"

        # Dynamically set WP_HOME and WP_SITEURL for debugging
        sed -i "2i \\
if (isset(\$_SERVER['HTTP_HOST'])) { \\
\$proto = (isset(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] === 'on') ? 'https' : 'http'; \\
define('WP_HOME', \$proto . '://' . \$_SERVER['HTTP_HOST']); \\
define('WP_SITEURL', \$proto . '://' . \$_SERVER['HTTP_HOST']); \\
}" "$WP_PATH/wp-config.php"
    fi
fi

# Ensure needed permissions
chown -R unit:unit /var/www/wordpress

# Start MariaDB in the background
echo ">> Starting MariaDB..."
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
/usr/bin/mariadbd-safe --datadir='/var/lib/mysql' &
MARIADB_PID=$!

# Start nginx Unit in the background
echo ">> Starting NGINX Unit..."
mkdir -p /var/lib/unit
unitd --no-daemon --control unix:/var/run/control.unit.sock &
UNIT_PID=$!

echo ">> Applying NGINX Unit configuration..."
count=0
while [ ! -S /var/run/control.unit.sock ]; do
    sleep 0.1
    count=$((count+1))
    if [ $count -gt 100 ]; then echo "Timeout waiting for Unit socket"; exit 1; fi
done

# PUT Unit config
curl -X PUT --data-binary @/config.json --unix-socket /var/run/control.unit.sock http://localhost/config > /dev/null

echo ">> Container Ready. WordPress is running (PID: $UNIT_PID)."

# Block here to prevent container exit.
# If a signal is trapped, `wait` returns immediately and the trap handler
# is executed.
wait "$UNIT_PID" "$MARIADB_PID"
