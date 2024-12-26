#!/bin/bash

# Définition des chemins et fichiers
GRAYLOG_CERTS_DIR="/etc/graylog/server/certs"
WAZUH_CA_SOURCE="/etc/wazuh-indexer/certs/root-ca.pem"
JAVA_SECURITY_PATH="/usr/lib/jvm/java-17-openjdk-amd64/lib/security/cacerts"
GRAYLOG_CACERTS="$GRAYLOG_CERTS_DIR/cacerts"
GRAYLOG_ROOT_CA="$GRAYLOG_CERTS_DIR/root-ca.pem"
GRAYLOG_SERVER_CONFIG="/etc/default/graylog-server"
GRAYLOG_CONF="/etc/graylog/server/server.conf"
WAZUH_PASSWORD_FILE="/var/ossec/etc/wazuh_passwords.log"
# Fonction pour vérifier l'existence et la lisibilité du fichier .env
check_env_file() {
    ENV_FILE=".env"
    if [ ! -f "$ENV_FILE" ]; then
        echo "Erreur : le fichier .env est manquant à l'emplacement $ENV_FILE." >&2
        exit 1
    fi
    if [ ! -r "$ENV_FILE" ]; then
        echo "Erreur : le fichier .env n'est pas lisible. Vérifiez les permissions du fichier." >&2
        exit 1
    fi
}

# Fonction pour charger les variables d'environnement depuis le fichier .env
load_env_variables() {
    echo "Chargement des variables d'environnement depuis .env..."
    source "$ENV_FILE"
    if [ -z "$GRAYLOG_PASSWORD" ] || [ -z "$IP" ]; then
        echo "Erreur : Certaines variables d'environnement sont manquantes dans le fichier .env." >&2
        exit 1
    fi
}

# Fonction pour ajouter le certificat et configurer Java
add_certificate() {
    echo "Création du dossier des certificats Graylog..."
    if [ ! -d "$GRAYLOG_CERTS_DIR" ]; then
        mkdir -p "$GRAYLOG_CERTS_DIR" || { echo "Erreur lors de la création du dossier $GRAYLOG_CERTS_DIR." >&2; exit 1; }
    fi

    if [ -f "$WAZUH_CA_SOURCE" ]; then
        echo "Copie de root-ca.pem dans $GRAYLOG_CERTS_DIR..."
        cp "$WAZUH_CA_SOURCE" "$GRAYLOG_ROOT_CA" || { echo "Erreur lors de la copie de root-ca.pem." >&2; exit 1; }
    else
        echo "Erreur : Le fichier $WAZUH_CA_SOURCE est introuvable." >&2
        exit 1
    fi

    if [ -f "$JAVA_SECURITY_PATH" ]; then
        echo "Copie de cacerts vers $GRAYLOG_CERTS_DIR..."
        cp -a "$JAVA_SECURITY_PATH" "$GRAYLOG_CACERTS" || { echo "Erreur lors de la copie de cacerts." >&2; exit 1; }
    else
        echo "Erreur : Le fichier cacerts est introuvable à l'emplacement $JAVA_SECURITY_PATH." >&2
        exit 1
    fi

    echo "Importation du certificat root-ca.pem dans le keystore cacerts..."
    keytool -importcert -keystore "$GRAYLOG_CACERTS" \
        -storepass changeit \
        -alias root_ca \
        -file "$GRAYLOG_ROOT_CA" -noprompt || { echo "Erreur lors de l'importation du certificat." >&2; exit 1; }

    echo "Ajout de la ligne Java au fichier de configuration Graylog..."
    JAVA_OPTS_LINE='GRAYLOG_SERVER_JAVA_OPTS="$GRAYLOG_SERVER_JAVA_OPTS -Dlog4j2.formatMsgNoLookups=true -Djavax.net.ssl.trustStore=/etc/graylog/server/certs/cacerts -Djavax.net.ssl.trustStorePassword=changeit"'
    if [ -f "$GRAYLOG_SERVER_CONFIG" ]; then
        if ! grep -q "Djavax.net.ssl.trustStore=" "$GRAYLOG_SERVER_CONFIG"; then
            echo "$JAVA_OPTS_LINE" >> "$GRAYLOG_SERVER_CONFIG" || { echo "Erreur lors de l'ajout de la ligne Java." >&2; exit 1; }
        else
            echo "La ligne Java est déjà présente dans $GRAYLOG_SERVER_CONFIG."
        fi
    else
        echo "Erreur : Le fichier $GRAYLOG_SERVER_CONFIG est introuvable." >&2
        exit 1
    fi

    echo "Certificat et configuration Java ajoutés avec succès."
}

# Fonction pour configurer le fichier server.conf
configure_server_conf() {
    if [ ! -f "$GRAYLOG_CONF" ]; then
        echo "Erreur : Le fichier $GRAYLOG_CONF est introuvable." >&2
        exit 1
    fi

    echo "Configuration de $GRAYLOG_CONF..."

    if [ -z "$GRAYLOG_PASSWORD" ]; then
        echo "Erreur : La variable 'graylog_password' est introuvable dans $ENV_FILE." >&2
        exit 1
    fi

    # Génération de password_secret
    password_secret=$(pwgen -N 1 -s 96)
    echo "password_secret généré : $password_secret"

    # Génération de root_password_sha2
    root_password_sha2=$(echo -n "$GRAYLOG_PASSWORD" | sha256sum | cut -d" " -f1)
    echo "root_password_sha2 généré : $root_password_sha2"

    # Modification de server.conf
    sed -i "/^password_secret =/c\password_secret = $password_secret" "$GRAYLOG_CONF" || { echo "Erreur lors de la mise à jour de password_secret." >&2; exit 1; }
    sed -i "/^root_password_sha2 =/c\root_password_sha2 = $root_password_sha2" "$GRAYLOG_CONF" || { echo "Erreur lors de la mise à jour de root_password_sha2." >&2; exit 1; }

        # Récupération du mot de passe admin depuis le fichier Wazuh
    if [ ! -f "$WAZUH_PASSWORD_FILE" ]; then
        echo "Erreur : Le fichier $WAZUH_PASSWORD_FILE est introuvable." >&2
        exit 1
    fi

    admin_password=$(grep "The password for user admin is" "$WAZUH_PASSWORD_FILE" | awk '{print $NF}')
    if [ -z "$admin_password" ]; then
        echo "Erreur : Impossible de récupérer le mot de passe admin dans $WAZUH_PASSWORD_FILE." >&2
        exit 1
    fi

    # Encodage du mot de passe pour les URI
    encoded_password=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$admin_password'))")

    echo "Mot de passe admin récupéré et encodé : $encoded_password"

    # Mise à jour de elasticsearch_hosts
    if [ -z "$IP" ]; then
        echo "Erreur : L'adresse IP n'est pas définie dans $ENV_FILE." >&2
        exit 1
    fi

    elasticsearch_host="https://admin:$encoded_password@$IP:9200"
    if grep -q "^#\?elasticsearch_hosts =" "$GRAYLOG_CONF"; then
        sed -i "/^#\?elasticsearch_hosts =/c\elasticsearch_hosts = $elasticsearch_host" "$GRAYLOG_CONF" || { echo "Erreur lors de la mise à jour de elasticsearch_hosts." >&2; exit 1; }
    else
        echo "elasticsearch_hosts = $elasticsearch_host" >>"$GRAYLOG_CONF" || { echo "Erreur lors de l'ajout de elasticsearch_hosts." >&2; exit 1; }
    fi

    echo "Configuration de $GRAYLOG_CONF terminée avec succès."

}

set_ip(){

    # Extraction de l'adresse IP
    IP=$(grep -E "^IP=" "$ENV_FILE" | cut -d '=' -f2 | tr -d '"')
    if [[ -z $IP ]]; then
        echo "L'adresse IP n'a pas été trouvée dans le fichier $ENV_FILE."
        exit 1
    fi

    # Modification de la première occurrence uniquement
    if [[ -f $GRAYLOG_CONF ]]; then
        sed -i "0,/^#\?http_bind_address =/s|^#\?http_bind_address =.*|http_bind_address = $IP:9000|" "$GRAYLOG_CONF"
        echo "La configuration a été mise à jour correctement : http_bind_address = http://$IP:9000"
    else
        echo "Le fichier $GRAYLOG_CONF est introuvable."
    exit 1
    fi
}

# Fonction pour démarrer et vérifier Graylog
start_and_verify_graylog() {
    echo "Démarrage du service Graylog..."
    systemctl daemon-reload
    systemctl enable graylog-server.service
    systemctl start graylog-server.service

    if systemctl is-active --quiet graylog-server.service; then
        echo "Graylog est actif."
    else
        echo "Erreur : Graylog n'a pas pu être démarré." >&2
        journalctl -u graylog-server --no-pager | tail -n 20
        exit 1
    fi
}

start_and_verify_mongodb() {
    echo "Démarrage du service Graylog..."
    systemctl daemon-reload
    systemctl enable mongod.service
    systemctl start mongod.service

    if systemctl is-active --quiet mongod.service; then
        echo "Mongodb est actif."
    else
        echo "Erreur : Mongodb n'a pas pu être démarré." >&2
        journalctl -u mongod.service --no-pager | tail -n 20
        exit 1
    fi
}
# Appel des fonctions
check_env_file
load_env_variables
add_certificate
configure_server_conf
set_ip
start_and_verify_mongodb
start_and_verify_graylog
