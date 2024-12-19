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
}

# Fonction pour configurer le Wazuh Indexer

# Fonction pour configurer le Wazuh Indexer
configure_wazuh_indexer() {
    local file="config.yml"
    echo "Configuration de Wazuh Indexer..."

    # Configurer les nœuds indexer
    sed -i "s|ip: <indexer-node-ip>|ip: $IP|" "$file"
    sed -i "s|name: node-1|name: $WAZUH_INDEXER_NAME|" "$file"

    # Configurer les nœuds server
    sed -i "s|name: wazuh-1|name: $WAZUH_MANAGER_NAME|" "$file"
    sed -i "s|ip: <wazuh-manager-ip>|ip: $IP|" "$file"

    # Configurer les nœuds dashboard
    sed -i "s|name: dashboard|name: $WAZUH_DASHBOARD_NAME|" "$file"
    sed -i "s|ip: <dashboard-node-ip>|ip: $IP|" "$file"

    # Vérifier si toutes les remplacements ont été effectués
    if grep -q "<indexer-node-ip>" "$file" || grep -q "<wazuh-manager-ip>" "$file" || grep -q "<dashboard-node-ip>" "$file"; then
        echo "Erreur : La configuration n'a pas été correctement appliquée dans $file." >&2
        exit 1
    fi

    echo "Configuration de config.yml terminé avec succès"

    echo ".....................................................................\n"

    echo "Configuration de Wazuh Indexer..."


    # Mise à jour de /etc/wazuh-indexer/opensearch.yml
    local opensearch_file="/etc/wazuh-indexer/opensearch.yml"

    if [ ! -f "$opensearch_file" ]; then
        echo "Erreur : Le fichier $opensearch_file est introuvable." >&2
        exit 1
    fi

    # Faire une copie de sauvegarde
    cp "$opensearch_file" "${opensearch_file}.bak"
    echo "Une copie de sauvegarde du fichier $opensearch_file a été créée."

    # Modifier le fichier
    sed -i "s|^network\.host:.*|network.host: $IP|" "$opensearch_file"
    sed -i "s|^node\.name:.*|node.name: $WAZUH_INDEXER_NAME|" "$opensearch_file"
    sed -i "s|^cluster\.initial_master_nodes:.*|cluster.initial_master_nodes:\n- \"$WAZUH_INDEXER_NAME\"|" "$opensearch_file"

    echo "Mise à jour de $opensearch_file terminée avec succès."

}


# Fonction pour générer et copier les certificats
generate_and_copy_certs() {
    echo "Génération des certificats avec wazuh-certs-tool..."
    bash wazuh-certs-tool.sh -A

    echo "Copie des certificats générés pour $WAZUH_INDEXER_NAME..."

    cd wazuh-certificates
    # Créer le répertoire des certificats
    mkdir -p /etc/wazuh-indexer/certs

    # Copier les certificats dans le répertoire
    cp admin.pem admin-key.pem root-ca.pem /etc/wazuh-indexer/certs
    cp $WAZUH_INDEXER_NAME.pem /etc/wazuh-indexer/certs/indexer.pem
    cp  $WAZUH_INDEXER_NAME.pem /etc/wazuh-indexer/certs/indexer-key.pem

    # Appliquer les permissions
    chmod 500 /etc/wazuh-indexer/certs
    chmod 400 /etc/wazuh-indexer/certs/*

    # Modifier le propriétaire
    chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs

    mkdir /etc/filebeat/certs
    cp root-ca.pem /etc/filebeat/certs
    cp $WAZUH_MANAGER_NAME.pem /etc/filebeat/certs/filebeat.pem
    cp $WAZUH_MANAGER_NAME.pem /etc/filebeat/certs/filebeat-key.pem
    chmod 500 /etc/filebeat/certs
    chmod 400 /etc/filebeat/certs/*
    chown -R root:root /etc/filebeat/certs


    cp root-ca.pem  /etc/wazuh-dashboard/certs
    cp $WAZUH_DASHBOARD_NAME.pem /etc/wazuh-dashboard/certs/dashboard.pem
    cp $WAZUH_DASHBOARD_NAME.pem /etc/wazuh-dashboard/certs/dashboard-key.pem
    chmod 500 /etc/wazuh-dashboard/certs
    chmod 400 /etc/wazuh-dashboard/certs/*
    chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs


    echo "Certificats générés et copiés avec succès."
}

# Fonction pour configurer le Wazuh Manager
configure_wazuh_manager() {
    echo "Configuration du Wazuh Manager..."
    # Ajouter ici les commandes spécifiques pour configurer le Wazuh Manager
}

# Fonction pour configurer Filebeat
configure_filebeat() {
    echo "Configuration de Filebeat..."
    # Ajouter ici les commandes spécifiques pour configurer Filebeat
}

# Fonction pour configurer le Wazuh Dashboard
configure_wazuh_dashboard() {
    echo "Configuration du Wazuh Dashboard..."
    # Ajouter ici les commandes spécifiques pour configurer le Dashboard
}

# Fonction pour démarrer les services requis
enable_and_start_wazuh_indexer() {
    echo "Activation et démarrage des services..."

    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer
    if systemctl is-active --quiet wazuh-indexer; then
        echo "Wazuh Indexer est actif."
    else
        echo "Erreur : Wazuh Indexer n'a pas pu être activé." >&2
        exit 1
    fi

    echo "Chargement des nouvelles informations de certificats et démarrage du cluster à nœud unique."
    /usr/share/wazuh-indexer/bin/indexer-security-init.sh

    echo ".....................................................................\n"
    echo "Le chargement et le démarrage a été terminée avec succès."

}


enable_and_start_wazuh_manager() {
    echo "Activation et démarrage des services..."

    systemctl enable wazuh-manager
    systemctl start wazuh-manager
    if systemctl is-active --quiet wazuh-manager; then
        echo "Wazuh Manager est actif."
    else
        echo "Erreur : Wazuh manager n'a pas pu être activé." >&2
        exit 1
    fi
}


enable_and_start_filebeat() {
    echo "Activation et démarrage des services..."

    systemctl enable filebeat
    systemctl start filebeat
    if systemctl is-active --quiet filebeat; then
        echo "Filebeat est actif."
    else
        echo "Erreur : Filebeat n'a pas pu être activé." >&2
        exit 1
    fi
}


enable_and_start_wazuh_dashboard() {
    echo "Activation et démarrage des services..."

    systemctl enable wazuh-dashboard
    systemctl start wazuh-dashboard
    if systemctl is-active --quiet wazuh-dashboard; then
        echo "Wazuh Dashboard est actif."
    else
        echo "Erreur : Wazuh Dashboard n'a pas pu être activé." >&2
        exit 1
    fi
}

# Fonction principale qui orchestre tout
configure_wazuh() {
    check_env_file  # Vérifier l'existence et la lisibilité du fichier .env
    load_env_variables  # Charger les variables d'environnement
    download_files  # Télécharger les fichiers nécessaires

    configure_wazuh_indexer  # Configurer le Wazuh Indexer, Server et Dashboard
    generate_and_copy_certs  # Générer et copier les certificats
    configure_wazuh_manager  # Configurer le Wazuh Manager
    configure_filebeat  # Configurer Filebeat
    configure_wazuh_dashboard  # Configurer le Wazuh Dashboard

    enable_and_start_services  # Activer et démarrer les services requis

    echo "La configuration de Wazuh Single Node a été complétée avec succès."
}

# Exécution de la fonction principale
configure_wazuh


