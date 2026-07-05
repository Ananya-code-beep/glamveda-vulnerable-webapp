#!/bin/bash
# ============================================================
# GlamVeda Cosmetics — Vulnerable Lab Setup Script
# Run on Kali Linux (or any Debian-based box) inside an
# ISOLATED VM/network only. Do not expose to the internet.
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBROOT="/var/www/html/glamveda"

echo "[*] GlamVeda lab setup starting..."

echo "[*] Installing dependencies (php, mysql, mongodb, nodejs, imagemagick, apache2)..."
sudo apt update
sudo apt install -y apache2 php php-mysqli libapache2-mod-php mariadb-server \
    imagemagick nodejs npm curl gnupg

# --- MongoDB (Kali doesn't ship it in default repos on every release, so try apt first, fall back to manual notes) ---
if ! command -v mongod &> /dev/null; then
    echo "[*] mongod not found via apt. Attempting MongoDB community repo install..."
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor || true
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/7.0 main" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null || true
    sudo apt update || true
    sudo apt install -y mongodb-org || echo "[!] MongoDB install via apt failed — install manually if NoSQLi module is needed."
fi

echo "[*] Starting services..."
sudo service apache2 start
sudo service mariadb start
sudo service mongod start 2>/dev/null || echo "[!] mongod service not started — check manual install."

echo "[*] Setting up MySQL database..."
sudo mysql -u root <<'EOSQL'
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';
FLUSH PRIVILEGES;
EOSQL

mysql -u root -proot < "$PROJECT_DIR/sql/schema.sql"
echo "[*] Database 'glamveda' created and seeded."

echo "[*] Deploying PHP site to $WEBROOT ..."
sudo rm -rf "$WEBROOT"
sudo mkdir -p "$WEBROOT"
sudo cp -r "$PROJECT_DIR/php/." "$WEBROOT/"
sudo chown -R www-data:www-data "$WEBROOT"
sudo chmod -R 755 "$WEBROOT"
sudo chmod 777 "$WEBROOT/uploads"

echo "[*] Enabling .htaccess overrides (AllowOverride All) for the uploads PHP-exec demo..."
sudo a2enmod rewrite
sudo bash -c "cat > /etc/apache2/sites-available/glamveda.conf" <<EOF
<VirtualHost *:80>
    DocumentRoot $WEBROOT
    <Directory $WEBROOT>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
sudo a2ensite glamveda.conf
sudo a2dissite 000-default.conf || true
sudo service apache2 reload

echo "[*] Installing Node.js dependencies for the NoSQL ticket API..."
cd "$PROJECT_DIR/nosql-api"
npm install

echo ""
echo "============================================================"
echo " Setup complete!"
echo " Web app:        http://localhost/  (or http://<vm-ip>/)"
echo " Start NoSQL API with:"
echo "   cd $PROJECT_DIR/nosql-api && node server.js"
echo ""
echo " Default lab logins:"
echo "   admin / AdminP@ss123   (role: admin)"
echo "   priya / priya123       (role: customer)"
echo "============================================================"
