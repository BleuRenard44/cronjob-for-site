#!/bin/bash

# Vérification des privilèges admin
if [ "$(id -u)" != "0" ]; then
    echo "Demande de privilèges administrateur..."
    sudo "$0"
    exit 1
fi

# Chemins d'installation
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="url_monitor"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME.sh"
PLIST_PATH="/Library/LaunchDaemons/com.urlmonitor.plist"

# Création du script de surveillance
cat > "$SCRIPT_PATH" << 'EOL'
#!/bin/bash

# Lecture de l'URL depuis config.yml
URL=$(grep "url=" config.yml | cut -d'=' -f2)
LOG_FILE="/var/log/url_monitor.log"

show_notification() {
    /usr/bin/osascript -e "display notification \"Code HTTP: $1\" with title \"Erreur détectée!\" subtitle \"$URL\" sound name \"Basso\""
}

exec 1>> "$LOG_FILE" 2>&1

while true; do
    # Relecture de l'URL à chaque itération pour prendre en compte les changements
    URL=$(grep "url=" config.yml | cut -d'=' -f2)
    if [ -n "$URL" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
        if [[ $HTTP_CODE =~ ^[45] ]]; then
            show_notification "$HTTP_CODE"
            echo "$(date): Erreur $HTTP_CODE détectée sur $URL" >> "$LOG_FILE"
        fi
    else
        echo "$(date): URL non définie dans config.yml" >> "$LOG_FILE"
    fi
    sleep 600
done
EOL

# Configuration des permissions
chmod +x "$SCRIPT_PATH"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Copie de config.yml vers le répertoire d'installation
cp config.yml "$INSTALL_DIR/"
chmod 644 "$INSTALL_DIR/config.yml"

# Création du service LaunchDaemon
cat > "$PLIST_PATH" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.urlmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
</dict>
</plist>
EOL

# Chargement du service
launchctl load -w "$PLIST_PATH"

echo "Installation terminée. Le service est démarré."
echo "Les logs sont disponibles dans $LOG_FILE"