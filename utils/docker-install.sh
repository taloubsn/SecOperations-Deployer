#!/bin/bash

set -e

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Vérifier si Docker est déjà installé
check_docker_installed() {
    if command_exists docker; then
        echo "[INFO] Docker est déjà installé. Version : $(docker --version)"
        exit 0
    fi
}

# Mettre à jour le système et installer les prérequis
install_prerequisites() {
    echo "[INFO] Installation des paquets nécessaires..."
    case "$1" in
        ubuntu|debian)
            sudo apt-get update && sudo apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            ;;
        centos|fedora|rhel|rocky|almalinux)
            sudo yum install -y \
                yum-utils \
                device-mapper-persistent-data \
                lvm2 \
                ca-certificates \
                curl
            ;;
        *)
            echo "[ERROR] Distribution non prise en charge." >&2
            exit 1
            ;;
    esac
}

# Ajouter le dépôt officiel Docker
add_docker_repo() {
    echo "[INFO] Ajout du dépôt Docker..."
    case "$1" in
        ubuntu|debian)
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$1/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo \  
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/$1 \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            ;;
        centos|rhel|rocky|almalinux)
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            ;;
        fedora)
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            ;;
        *)
            echo "[ERROR] Distribution non prise en charge pour le dépôt." >&2
            exit 1
            ;;
    esac
}

# Installer Docker
install_docker() {
    echo "[INFO] Installation de Docker..."
    case "$1" in
        ubuntu|debian)
            sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|rocky|almalinux)
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        fedora)
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        *)
            echo "[ERROR] Distribution non prise en charge pour l'installation." >&2
            exit 1
            ;;
    esac
}

# Activer et démarrer Docker
enable_and_start_docker() {
    echo "[INFO] Activation et démarrage de Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Vérifier et tester Docker
test_docker() {
    echo "[INFO] Vérification de l'installation de Docker..."
    if command_exists docker; then
        echo "[INFO] Docker est installé avec succès. Version : $(docker --version)"
    else
        echo "[ERROR] Échec de l'installation de Docker." >&2
        exit 1
    fi
}

# Détection de la distribution Linux
OS="$(. /etc/os-release && echo $ID)"
echo "[INFO] Distribution détectée : $OS"

check_docker_installed
install_prerequisites "$OS"
add_docker_repo "$OS"
install_docker "$OS"
enable_and_start_docker
test_docker

echo "[INFO] Installation de Docker terminée avec succès."

