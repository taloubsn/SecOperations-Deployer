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

# Fonction pour cloner et configurer DFIR-IRIS
configure_dfir_iris() {
    # Définir le chemin vers le fichier .env principal
    local MAIN_ENV_PATH="../.env"

    echo "Clonage du dépôt iris-web..."
    git clone https://github.com/dfir-iris/iris-web.git || { echo "Erreur lors du clonage du dépôt."; return 1; }

    echo "Accès au répertoire iris-web..."
    cd iris-web || { echo "Le répertoire iris-web n'existe pas."; return 1; }

    echo "Passage à la version v2.4.19..."
    git checkout v2.4.19 || { echo "Erreur lors du checkout à la version v2.4.19."; return 1; }

    echo "Configuration du fichier .env..."
    cp .env.model .env || { echo "Erreur lors de la copie du fichier .env.model."; return 1; }

    echo "Copie du fichier .env vers $MAIN_ENV_PATH..."
    cp .env "$MAIN_ENV_PATH" || { echo "Erreur lors de la copie du fichier .env."; return 1; }

    echo "Configuration terminée avec succès."
}

# Appeler la fonction
load_env_variables
check_env_file
configure_dfir_iris

