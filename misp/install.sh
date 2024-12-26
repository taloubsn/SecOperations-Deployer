#!/bin/bash

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
    if [ -z "$IP" ]; then
        echo "Erreur : La variable d'environnement IP est manquante dans le fichier .env." >&2
        exit 1
    fi
}

# Fonction pour configurer MISP Docker
setup_misp_docker() {
    # Cloner le dépôt MISP Docker
    git clone https://github.com/MISP/misp-docker.git || {
        echo "Erreur : Échec du clonage du dépôt." >&2
        exit 1
    }

    # Accéder au répertoire cloné
    cd misp-docker || {
        echo "Erreur : Impossible d'accéder au répertoire misp-docker." >&2
        exit 1
    }

    # Copier le fichier template.env en .env
    cp template.env .env || {
        echo "Erreur : Échec de la copie du fichier template.env." >&2
        exit 1
    }

    # Vérifier et charger les variables d'environnement

    # Modifier la ligne BASE_URL dans le fichier .env
    sed -i "s|^BASE_URL=.*|BASE_URL=https://$IP:4433|" .env || {
        echo "Erreur : Échec de la modification de BASE_URL dans .env." >&2
        exit 1
    }

    # Modifier les ports dans le fichier docker-compose.yml
    sed -i '/^\s*- \"80:80\"/c\      - "8088:80"' docker-compose.yml || {
        echo "Erreur : Échec de la modification du port 80 dans docker-compose.yml." >&2
        exit 1
    }
    sed -i '/^\s*- \"443:443\"/c\      - "4433:443"' docker-compose.yml || {
        echo "Erreur : Échec de la modification du port 443 dans docker-compose.yml." >&2
        exit 1
    }

    echo "Configuration terminée avec succès."

    # Ajouter les variables du .env local dans le .env principal
    merge_env_files
}

# Fonction pour ajouter les nouvelles variables dans le .env principal
merge_env_files() {
    PARENT_ENV_FILE="../.env"

    if [ ! -f "$PARENT_ENV_FILE" ]; then
        echo "Erreur : Le fichier .env principal n'existe pas à l'emplacement $PARENT_ENV_FILE. Création d'un nouveau fichier..."
        cp .env "$PARENT_ENV_FILE" || {
            echo "Erreur : Échec de la création du fichier .env principal." >&2
            exit 1
        }
        echo "Fichier .env principal créé avec succès."
    else
        echo "Ajout des nouvelles variables au fichier .env principal..."
        while IFS= read -r line; do
            if ! grep -q "^${line%%=*}=" "$PARENT_ENV_FILE"; then
                echo "$line" >> "$PARENT_ENV_FILE"
            fi
        done < .env
        echo "Variables ajoutées au fichier .env principal avec succès."
    fi
}

# Appeler la fonction de configuration
load_env_variables
check_env_file
setup_misp_docker
merge_env_files
