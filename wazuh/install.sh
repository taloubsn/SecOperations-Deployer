#!/bin/bash

# Vérification si l'utilisateur est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# Fonction de détection du système d'exploitation
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release >/dev/null 2>&1; then
        lsb_release -is | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# Fonction pour importer la clé GPG
import_gpg_key() {
    local key_url=$1

    if [ "$OS_INFO" == "centos" ] || [ "$OS_INFO" == "rhel" ] || [ "$OS_INFO" == "fedora" ]; then
        echo "Importation de la clé GPG avec rpm..."
        rpm --import "$key_url" || {
            echo "Erreur lors de l'importation de la clé GPG avec rpm." >&2
            exit 1
        }
    else
        echo "Importation de la clé GPG avec gpg..."
        local keyring="/usr/share/keyrings/wazuh.gpg"
        if [ ! -f "$keyring" ]; then
            curl -s "$key_url" | gpg --dearmor -o "$keyring" && chmod 644 "$keyring" || {
                echo "Erreur lors de l'importation de la clé GPG." >&2
                exit 1
            }
        else
            echo "Clé GPG déjà importée."
        fi
    fi
}

# Fonction pour ajouter un dépôt si non existant
add_repo() {
    local repo_file=$1
    local repo_content=$2

    if [ ! -f "$repo_file" ]; then
        echo "Ajout du dépôt..."
        echo -e "$repo_content" > "$repo_file" || {
            echo "Erreur lors de l'ajout du dépôt." >&2
            exit 1
        }
    else
        echo "Dépôt déjà présent."
    fi
}

# Fonction pour installer les paquets
install_packages() {
    local package_manager=$1
    shift
    local packages=($@)

    echo "Installation des paquets : ${packages[*]}..."
    $package_manager install -y "${packages[@]}" || {
        echo "Erreur lors de l'installation des paquets." >&2
        exit 1
    }
}

# Fonction d'installation pour Debian/Ubuntu
install_debian() {
    echo "Installation sur Debian/Ubuntu..."

    echo "Mise à jour des paquets..."
    apt update && apt upgrade -y || {
        echo "Erreur lors de la mise à jour des paquets." >&2
        exit 1
    }

    echo "Installation des dépendances..."
    install_packages "apt" curl git unzip dos2unix wget vim nano debconf adduser procps gnupg apt-transport-https

    import_gpg_key "https://packages.wazuh.com/key/GPG-KEY-WAZUH"

    add_repo "/etc/apt/sources.list.d/wazuh.list" "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main"

    echo "Mise à jour des dépôts..."
    apt update || {
        echo "Erreur lors de la mise à jour des dépôts." >&2
        exit 1
    }

    install_packages "apt" wazuh-indexer wazuh-manager filebeat wazuh-dashboard debhelper tar libcap2-bin

    echo "Installation terminée sur Debian/Ubuntu."
}

# Fonction d'installation pour CentOS/RHEL
install_centos() {
    echo "Installation sur CentOS/RHEL..."

    echo "Mise à jour des paquets..."
    yum update -y || {
        echo "Erreur lors de la mise à jour des paquets." >&2
        exit 1
    }

    echo "Installation des dépendances..."
    install_packages "yum" curl git unzip dos2unix wget vim nano coreutils

    import_gpg_key "https://packages.wazuh.com/key/GPG-KEY-WAZUH"

    add_repo "/etc/yum.repos.d/wazuh.repo" "[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1"

    install_packages "yum" wazuh-indexer wazuh-manager filebeat wazuh-dashboard libcap
    echo "Installation terminée sur CentOS/RHEL."
}

# Fonction de gestion des erreurs
error_exit() {
    echo "$1" >&2
    exit 1
}

# Détection et installation
OS_INFO=$(detect_os)
echo "Système détecté : $OS_INFO"

case "$OS_INFO" in
    debian|ubuntu)
        install_debian
        ;;
    centos|rhel|fedora)
        install_centos
        ;;
    *)
        error_exit "Distribution non supportée. Ce script ne prend en charge que Debian/Ubuntu ou CentOS/RHEL."
        ;;
esac

