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

# Exécution sécurisée d'une commande avec gestion des erreurs
run() {
    "$@"
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'exécution : $*" >&2
        exit 1
    fi
}

# Détecter le système d'exploitation
os=$(detect_os)
echo "Système d'exploitation détecté : $os"

# Vérification si le système d'exploitation est pris en charge
if [[ ! "$os" =~ ^(ubuntu|debian|rhel|centos)$ ]]; then
    echo "Système d'exploitation non pris en charge pour l'installation de Graylog." >&2
    exit 1
fi

# Installation de Java pour CentOS (alternative pour Java 17)

# Installation de Graylog en fonction du système d'exploitation

install_graylog() {
    echo "Début de l'installation de Graylog sur $os..."

    case "$os" in
        ubuntu)
            run timedatectl set-timezone UTC

            echo "Mise à jour des paquets et installation des dépendances..."
            run apt update -y && run apt dist-upgrade -y
            run apt install -y apt-transport-https openjdk-17-jre-headless wget gnupg curl pwgen
            echo "Ajout des clés GPG et des dépôts MongoDB..."
            run curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg
            echo "deb [signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-6.0.list

            echo "Ajout du dépôt Graylog..."
            run wget https://packages.graylog2.org/repo/packages/graylog-6.1-repository_latest.deb
            run dpkg -i graylog-6.1-repository_latest.deb

            echo "Installation de MongoDB et Graylog..."
            run apt update -y
            run apt install -y mongodb-org graylog-server

            echo "Graylog installé avec succès sur Ubuntu."
            ;;

        debian)
            run timedatectl set-timezone UTC

            echo "Mise à jour des paquets et installation des dépendances..."
            run apt update -y && run apt dist-upgrade -y
            run apt install -y apt-transport-https openjdk-17-jre-headless wget gnupg curl pwgen sudo

            echo "Ajout des clés GPG et des dépôts MongoDB..."
            run curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
                sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
                --dearmor
            echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

            echo "Ajout du dépôt Graylog..."
            run sudo wget https://packages.graylog2.org/repo/packages/graylog-6.1-repository_latest.deb
            run sudo dpkg -i graylog-6.1-repository_latest.deb

            echo "Installation de MongoDB et Graylog..."
            run apt update -y
            run apt install -y mongodb-org graylog-server

            echo "Graylog installé avec succès sur Debian."
            ;;

        rhel|centos)
            run timedatectl set-timezone UTC

            echo "Mise à jour des paquets et installation des dépendances..."
            run yum update -y
            run yum install -y  wget curl pwgen
            install_java
            echo "Ajout des dépôts MongoDB et Graylog..."
            cat <<EOF > /etc/yum.repos.d/mongodb-org.repo
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
            run rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-6.1-repository_latest.rpm

            echo "Installation de MongoDB et Graylog..."
            run yum update -y
            run yum install -y mongodb-org graylog-server

            echo "Graylog installé avec succès sur $os."
            ;;
    esac
}

# Lancer l'installation de Graylog
install_graylog
