#!/bin/bash

# Vérification si l'utilisateur est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# Fonction pour afficher des points dynamiques
show_dynamic_dots() {
    local message="$1"
    echo -n "$message" # Affiche le message une seule fois
    while true; do
        for dots in "" "." ".." "..."; do
            echo -ne "\r$message$dots" # Met à jour les points dynamiquement
            sleep 0.5
        done
    done
}

# Fonction pour arrêter l'animation
stop_dynamic_dots() {
    kill "$SPINNER_PID" >/dev/null 2>&1
    wait "$SPINNER_PID" 2>/dev/null
    echo -e "\r$1" # Affiche le message final après l'animation
}

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
        rpm --import "$key_url" >/dev/null 2>&1 || return 1
    else
        local keyring="/usr/share/keyrings/wazuh.gpg"
        if [ ! -f "$keyring" ]; then
            curl -s "$key_url" | gpg --dearmor -o "$keyring" >/dev/null 2>&1 && chmod 644 "$keyring" || return 1
        fi
    fi
}

# Fonction pour ajouter un dépôt si non existant
add_repo() {
    local repo_file=$1
    local repo_content=$2
    if [ ! -f "$repo_file" ]; then
        echo -e "$repo_content" > "$repo_file" || return 1
    fi
}

# Fonction pour installer les paquets
install_packages() {
    local package_manager=$1
    shift
    local packages=($@)
    $package_manager install -y "${packages[@]}" >/dev/null 2>&1 || return 1
}

# Installation pour Debian/Ubuntu
install_debian() {
    apt update -y >/dev/null 2>&1 && apt upgrade -y >/dev/null 2>&1 || return 1
    install_packages "apt" curl sudo git unzip dos2unix wget vim nano debconf adduser procps gnupg apt-transport-https net-tools|| return 1
    import_gpg_key "https://packages.wazuh.com/key/GPG-KEY-WAZUH" || return 1
    add_repo "/etc/apt/sources.list.d/wazuh.list" "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" || return 1
    apt update -y >/dev/null 2>&1 || return 1
    install_packages "apt" wazuh-indexer wazuh-manager filebeat wazuh-dashboard debhelper tar libcap2-bin || return 1
}

# Installation pour CentOS/RHEL
install_centos() {
    yum update -y >/dev/null 2>&1 || return 1
    install_packages "yum" curl git unzip dos2unix wget vim nano coreutils || return 1
    import_gpg_key "https://packages.wazuh.com/key/GPG-KEY-WAZUH" || return 1
    add_repo "/etc/yum.repos.d/wazuh.repo" "[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1" || return 1
    install_packages "yum" wazuh-indexer wazuh-manager filebeat wazuh-dashboard libcap || return 1
}

# Détection et installation
show_dynamic_dots "Démarrage de l'installation de Wazuh" &
SPINNER_PID=$!

OS_INFO=$(detect_os)
case "$OS_INFO" in
    debian|ubuntu)
        install_debian
        ;;
    centos|rhel|fedora)
        install_centos
        ;;
    *)
        stop_dynamic_dots "Distribution non supportée."
        exit 1
        ;;
esac

# Fin de l'installation
stop_dynamic_dots "Installation de Wazuh terminée avec succès !"

