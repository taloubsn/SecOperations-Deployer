#!/bin/bash

# Vérification si l'utilisateur est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# Fonction pour cloner le dépôt Git et préparer l'environnement
prepare_shuffle() {
    echo "Clonage du dépôt Git Shuffle..."
    git clone https://github.com/Shuffle/Shuffle.git &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Échec du clonage du dépôt." >&2
        exit 1
    fi
    echo "Clonage terminé."

    echo "Configuration du dossier shuffle-database..."
    cd Shuffle || exit 1
    mkdir -p shuffle-database
    sudo chown -R 1000:1000 shuffle-database
    echo "Dossier shuffle-database configuré."

    echo "Désactivation de l'échange mémoire (swap)..."
    sudo swapoff -a
    echo "Swap désactivé."

    sudo sysctl -w vm.max_map_count=262144
}

# Fonction pour modifier le fichier docker-compose.yml
update_docker_compose() {
    echo "Modification du fichier docker-compose.yml..."
    local file="docker-compose.yml"

    if [ -f "$file" ]; then
        sed -i 's/- 9200:9200/- 9205:9205/' "$file"
        echo "Modification des ports OpenSearch effectuée."
    else
        echo "Fichier docker-compose.yml introuvable." >&2
        exit 1
    fi
}

# Appel des fonctions
prepare_shuffle
update_docker_compose

echo "Installation de Shuffle Automation terminée avec succès !"

