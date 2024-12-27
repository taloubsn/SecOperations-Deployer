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

    echo "Clonage du dépôt iris-web..."
    git clone https://github.com/dfir-iris/iris-web.git || { echo "Erreur lors du clonage du dépôt."; return 1; }

    echo "Accès au répertoire iris-web..."
    cd iris-web || { echo "Le répertoire iris-web n'existe pas."; return 1; }

    echo "Passage à la version v2.4.19..."
    git checkout v2.4.19 || { echo "Erreur lors du checkout à la version v2.4.19."; return 1; }

    echo "Configuration du fichier .env..."
    cp .env.model .env || { echo "Erreur lors de la copie du fichier .env.model."; return 1; }

    echo "Configuration terminée avec succès."
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

# Appeler la fonction
check_env_file
load_env_variables
configure_dfir_iris
merge_env_files
