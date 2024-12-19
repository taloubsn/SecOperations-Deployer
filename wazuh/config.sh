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
    echo "Configuration de Wazuh Single Node complétée avec succès."
}

# Exécution de la fonction principale
configure_wazuh
