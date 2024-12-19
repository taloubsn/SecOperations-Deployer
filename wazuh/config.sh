#!/bin/bash

# Fonction pour vérifier l'existence et la lisibilité du fichier .env
check_env_file() {
    ENV_FILE="../.env"
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
    if [ -z "$WAZUH_INDEXER_NAME" ] || [ -z "$WAZUH_MANAGER_NAME" ] || [ -z "$WAZUH_DASHBOARD_NAME" ] || [ -z "$IP" ]; then
        echo "Erreur : Certaines variables d'environnement sont manquantes dans le fichier .env." >&2
        exit 1
    fi
}

# Fonction pour télécharger les fichiers nécessaires
download_files() {
    echo "Téléchargement des fichiers nécessaires..."
    curl -sO https://packages.wazuh.com/4.9/wazuh-certs-tool.sh
    curl -sO https://packages.wazuh.com/4.9/config.yml

    if [ ! -f "wazuh-certs-tool.sh" ] || [ ! -f "config.yml" ]; then
        echo "Erreur : Les fichiers nécessaires n'ont pas pu être téléchargés." >&2
        exit 1
    fi
    chmod +x wazuh-certs-tool.sh
}

# Fonction pour configurer Wazuh Indexer
configure_wazuh_indexer() {
    local file="config.yml"
    echo "Configuration de Wazuh Indexer..."

    # Configurer les nœuds indexer
    sed -i "s|name: node-1|name: $WAZUH_INDEXER_NAME|" "$file"
    sed -i "/^ *ip: \"<indexer-node-ip>\"/s|ip: \"<indexer-node-ip>\"|ip: \"$IP\"|" "$file"
    # Configurer les nœuds server
    sed -i "s|name: wazuh-1|name: $WAZUH_MANAGER_NAME|" "$file"
    sed -i "/^ *ip: \"<wazuh-manager-ip>\"/s|ip: \"<wazuh-manager-ip>\"|ip: \"$IP\"|" "$file"

    # Configurer les nœuds dashboard
    sed -i "s|name: dashboard|name: $WAZUH_DASHBOARD_NAME|" "$file"
    sed -i "/^ *ip: \"<dashboard-node-ip>\"/s|ip: \"<dashboard-node-ip>\"|ip: \"$IP\"|" "$file"

    # Vérifier si toutes les remplacements ont été effectués

    echo "Configuration de config.yml terminée avec succès."

    echo "Mise à jour de /etc/wazuh-indexer/opensearch.yml..."
    local opensearch_file="/etc/wazuh-indexer/opensearch.yml"

    if [ ! -f "$opensearch_file" ]; then
        echo "Erreur : Le fichier $opensearch_file est introuvable." >&2
        exit 1
    fi

    # Faire une copie de sauvegarde
    cp "$opensearch_file" "${opensearch_file}.copy"

    # Modifier le fichier
    sed -i "s|^network\.host:.*|network.host: \"$IP\"|" "$opensearch_file"
    sed -i "s|^node\.name:.*|node.name: \"$WAZUH_INDEXER_NAME\"|" "$opensearch_file"
    sed -i "/^cluster\.initial_master_nodes:/,/^#/{s|\"node-1\"|\"$WAZUH_INDEXER_NAME\"|}" "$opensearch_file"

    echo "Mise à jour de $opensearch_file terminée avec succès."
}

# Fonction principale pour configurer Wazuh Manager et Filebeat
configure_wazuh_manager_filebeat() {
    echo "Configuration de Wazuh Manager et Filebeat..."

    # Téléchargements et configuration
    declare -A files=(
        ["https://packages.wazuh.com/4.9/tpl/wazuh/filebeat/filebeat.yml"]="/etc/filebeat/filebeat.yml"
        ["https://raw.githubusercontent.com/wazuh/wazuh/v4.9.2/extensions/elasticsearch/7.x/wazuh-template.json"]="/etc/filebeat/wazuh-template.json"
    )

    for url in "${!files[@]}"; do
        destination="${files[$url]}"
        if curl -so "$destination" "$url"; then
            echo "Fichier téléchargé avec succès : $destination"
            [[ "$destination" == *wazuh-template.json ]] && chmod go+r "$destination" && echo "Permissions configurées : go+r"
        else
            echo "Erreur lors du téléchargement depuis $url." >&2
            exit 1
        fi
    done

    # Extraction du module wazuh-filebeat
    if curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz | tar -xvz -C /usr/share/filebeat/module; then
        echo "Module wazuh-filebeat extrait avec succès."
    else
        echo "Erreur lors de l'extraction du module wazuh-filebeat." >&2
        exit 1
    fi

    # Mise à jour des fichiers de configuration
    if sed -i "s|hosts: \[.*\]|hosts: [\"$IP:9200\"]|" /etc/filebeat/filebeat.yml; then
        echo "Fichier filebeat.yml à été mis jour"
    else
        echo "Erreur lors de la modification du fichier filebeat.yml." >&2
        exit 1
    fi

    if sed -i "s|<host>https://.*:9200</host>|<host>https://$IP:9200</host>|" /var/ossec/etc/ossec.conf; then
        echo "Fichier ossec.conf a été mis jour"
    else
        echo "Erreur lors de la modification du fichier ossec.conf." >&2
        exit 1
    fi
}

# Fonction pour configurer Wazuh Dashboard
configure_wazuh_dashboard() {
    echo "Configuration du Wazuh Dashboard..."

    # Vérifier si le fichier de configuration OpenSearch existe
    OPENSEARCH_CONFIG="/etc/wazuh-dashboard/opensearch_dashboards.yml"
    if [ ! -f "$OPENSEARCH_CONFIG" ]; then
        echo "Le fichier de configuration OpenSearch Dashboards $OPENSEARCH_CONFIG est introuvable." >&2
        exit 1
    fi
    # Modifier le fichier de configuration d'OpenSearch Dashboards
    if sed -i "s|opensearch.hosts:.*|opensearch.hosts: [\"https://$IP:9200\"]|" "$OPENSEARCH_CONFIG"; then
        echo "Fichier opensearch_dashboards.yml mis à jour avec l'IP : $IP et le port 9200."
    else
        echo "Erreur lors de la modification du fichier opensearch_dashboards.yml." >&2
        exit 1
    fi

    systemctl daemon-reload
    systemctl enable wazuh-dashboard
    systemctl start wazuh-dashboard

    # Attendre que le fichier de configuration Wazuh Dashboard soit généré
    WAZUH_DASHBOARD_CONFIG="/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"
    echo "Attente de la création du fichier de configuration Wazuh Dashboard : $WAZUH_DASHBOARD_CONFIG..."
    for i in {1..30}; do
        if [ -f "$WAZUH_DASHBOARD_CONFIG" ]; then
            echo "Le fichier de configuration Wazuh Dashboard est disponible."
            break
        fi
        echo "Le fichier n'est pas encore disponible, nouvelle vérification dans 2 secondes..."
        sleep 2
    done

    # Si le fichier n'existe toujours pas, arrêter le script avec une erreur
    if [ ! -f "$WAZUH_DASHBOARD_CONFIG" ]; then
        echo "Erreur : Le fichier de configuration Wazuh Dashboard $WAZUH_DASHBOARD_CONFIG est toujours introuvable après 30 vérifications." >&2
        exit 1
    fi

    # Modifier le fichier de configuration de Wazuh Dashboard
    if sed -i -E "s|url: https://.*|url: https://$IP|" "$WAZUH_DASHBOARD_CONFIG"; then
        echo "Fichier wazuh.yml mis à jour avec les paramètres Wazuh Dashboard."
    else
        echo "Erreur lors de la modification du fichier wazuh.yml." >&2
        exit 1
    fi
}

# Fonction pour configurer le mot de passe de l'utilisateur admin dans les keystores Filebeat et Wazuh
configure_admin_password() {
    LOG_FILE="/var/ossec/etc/wazuh_passwords.log"
    echo "Configuration du mot de passe de l'utilisateur admin dans les keystores Filebeat et Wazuh..."

    # Exécuter la commande pour récupérer les mots de passe
    PASSWORDS_OUTPUT=$(/usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh --api --change-all --admin-user wazuh --admin-password wazuh 2>&1 | tee -a "$LOG_FILE")
    if [[ $? -ne 0 ]]; then
        echo "Erreur lors de l'exécution de la commande wazuh-passwords-tool.sh." >&2
        echo "$PASSWORDS_OUTPUT" >&2
        exit 1
    fi

    # Extraire le mot de passe de l'utilisateur admin
    ADMIN_PASSWORD=$(echo "$PASSWORDS_OUTPUT" | grep -oP 'The password for user admin is \K[^\s]+')
    if [ -z "$ADMIN_PASSWORD" ]; then
        echo "Erreur : Mot de passe pour l'utilisateur admin introuvable." >&2
        exit 1
    fi

    # Créer le keystore de Filebeat s'il n'existe pas déjà
    if [ ! -f /etc/filebeat/filebeat.keystore ]; then
        echo "Création du keystore Filebeat..."
        filebeat keystore create
        if [ $? -ne 0 ]; then
            echo "Erreur lors de la création du keystore Filebeat." >&2
            exit 1
        fi
    fi

    # Ajouter le nom d'utilisateur 'admin' dans le keystore de Filebeat
    echo "admin" | filebeat keystore add username --stdin --force
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'ajout du nom d'utilisateur dans le keystore Filebeat." >&2
        exit 1
    fi

    # Ajouter le mot de passe de l'utilisateur admin dans le keystore de Filebeat
    echo "$ADMIN_PASSWORD" | filebeat keystore add password --stdin --force
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'ajout du mot de passe dans le keystore Filebeat." >&2
        exit 1
    fi

    # Ajouter le nom d'utilisateur 'admin' dans le keystore de Wazuh
    echo "admin" | /var/ossec/bin/wazuh-keystore -f indexer -k username
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'ajout du nom d'utilisateur dans le keystore Wazuh." >&2
        exit 1
    fi

    # Ajouter le mot de passe de l'utilisateur admin dans le keystore de Wazuh
    echo "$ADMIN_PASSWORD" | /var/ossec/bin/wazuh-keystore -f indexer -k password
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'ajout du mot de passe dans le keystore Wazuh." >&2
        exit 1
    fi

    echo "Mot de passe de l'utilisateur admin ajouté avec succès dans les keystores Filebeat et Wazuh."
}


# Fonction pour générer et copier les certificats
generate_and_copy_certs() {
    echo "Début de la génération des certificats avec wazuh-certs-tool..."

    # Vérifier si l'outil existe
    CERTS_TOOL="./wazuh-certs-tool.sh"
    if [[ ! -f "$CERTS_TOOL" ]]; then
        echo "Erreur : L'outil wazuh-certs-tool.sh est introuvable." >&2
        exit 1
    fi

    # Exécuter l'outil pour générer les certificats
    echo "Exécution de la commande : $CERTS_TOOL -A"
    if ! bash "$CERTS_TOOL" -A; then
        echo "Erreur : Échec de la génération des certificats." >&2
        exit 1
    fi
    echo "Certificats générés avec succès."

    # Vérification de la présence du répertoire de certificats générés
    OUTPUT_CERTIFICATES_DIR="wazuh-certificates"
    if [[ ! -d "$OUTPUT_CERTIFICATES_DIR" ]]; then
        echo "Erreur : Le répertoire $OUTPUT_CERTIFICATES_DIR est introuvable après la génération." >&2
        exit 1
    fi
    cd "$OUTPUT_CERTIFICATES_DIR" || exit 1

    # Créer les répertoires de destination si nécessaire
    echo "Création des répertoires de certificats..."
    mkdir -p /etc/wazuh-indexer/certs /etc/filebeat/certs /etc/wazuh-dashboard/certs

    # Copier les certificats vers leurs destinations respectives
    echo "Copie des certificats vers les répertoires de destination..."
    cp admin.pem admin-key.pem root-ca.pem /etc/wazuh-indexer/certs
    cp "$WAZUH_INDEXER_NAME.pem" /etc/wazuh-indexer/certs/indexer.pem
    cp "$WAZUH_INDEXER_NAME-key.pem" /etc/wazuh-indexer/certs/indexer-key.pem

    cp root-ca.pem /etc/filebeat/certs
    cp "$WAZUH_MANAGER_NAME.pem" /etc/filebeat/certs/filebeat.pem
    cp "$WAZUH_MANAGER_NAME-key.pem" /etc/filebeat/certs/filebeat-key.pem

    cp root-ca.pem /etc/wazuh-dashboard/certs
    cp "$WAZUH_DASHBOARD_NAME.pem" /etc/wazuh-dashboard/certs/dashboard.pem
    cp "$WAZUH_DASHBOARD_NAME-key.pem" /etc/wazuh-dashboard/certs/dashboard-key.pem

    # Appliquer les permissions et changer les propriétaires
    echo "Application des permissions et configuration des propriétaires..."
    chmod -R 500 /etc/wazuh-indexer/certs /etc/filebeat/certs /etc/wazuh-dashboard/certs
    chmod -R 400 /etc/wazuh-indexer/certs/* /etc/filebeat/certs/* /etc/wazuh-dashboard/certs/*
    chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs
    chown -R root:root /etc/filebeat/certs
    chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs

    echo "Certificats générés, copiés et configurés avec succès."
}

# Fonction pour démarrer et vérifier Wazuh Indexer
start_and_verify_wazuh_indexer() {
    echo "Démarrage du service Wazuh Indexer..."
    systemctl daemon-reload
    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer

    if systemctl is-active --quiet wazuh-indexer; then
        echo "Wazuh Indexer est actif."
    else
        echo "Erreur : Wazuh Indexer n'a pas pu être démarré." >&2
        journalctl -u wazuh-indexer --no-pager | tail -n 20
        exit 1
    fi
}
start_and_verify_wazuh_filebeat() {
    echo "Démarrage du service Wazuh Manager..."
    systemctl daemon-reload
    systemctl enable wazuh-manager
    systemctl start wazuh-manager

    if systemctl is-active --quiet wazuh-manager; then
        echo "Wazuh Manager est actif."
    else
        echo "Erreur : Wazuh Manager n'a pas pu être démarré." >&2
        journalctl -u wazuh-manager --no-pager | tail -n 20
        exit 1
    fi

    echo "Démarrage du service Wazuh Dashboard..."
    systemctl daemon-reload
    systemctl enable wazuh-dashboard
    systemctl restart wazuh-dashboard

    if systemctl is-active --quiet wazuh-dashboard; then
        echo "Wazuh Dashboard est actif."
    else
        echo "Erreur : Wazuh Dasboard n'a pas pu être démarré." >&2
        journalctl -u wazuh-dashboard --no-pager | tail -n 20
        exit 1
    fi


    echo "Démarrage du service Filebeat..."
    systemctl daemon-reload
    systemctl enable filebeat
    systemctl start filebeat

    if systemctl is-active --quiet filebeat; then
        echo "filebeat est actif."
    else
        echo "Erreur : filebeat n'a pas pu être démarré." >&2
        journalctl -u filebeat --no-pager | tail -n 20
        exit 1
    fi
}



# Fonction pour initialiser le cluster Wazuh Indexer
initialize_wazuh_indexer_cluster() {
    echo "Initialisation de la sécurité et du cluster Wazuh Indexer..."
    # Exécution du script d'initialisation de la sécurité
    if /usr/share/wazuh-indexer/bin/indexer-security-init.sh; then
        echo "Initialisation du cluster Wazuh Indexer réussie."
    else
        echo "Erreur lors de l'initialisation du cluster Wazuh Indexer." >&2
        exit 1
    fi
}


# Fonction principale qui orchestre tout
configure_wazuh() {
    check_env_file
    load_env_variables
    download_files
    configure_wazuh_indexer
    generate_and_copy_certs
    start_and_verify_wazuh_indexer
    initialize_wazuh_indexer_cluster
    configure_wazuh_manager_filebeat
    configure_wazuh_dashboard
    configure_admin_password
    start_and_verify_wazuh_filebeat

    echo "Configuration de Wazuh Single Node complétée avec succès."
}

# Exécution de la fonction principale
configure_wazuh

