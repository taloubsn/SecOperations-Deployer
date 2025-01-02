# Liste ordonnée des scripts à exécuter
ORDERED_SCRIPTS = [
    "wazuh/install.sh",         # Ensuite, installer Wazuh
    "wazuh/config.sh",          # Configuration de Wazuh
    "utils/docker-install.sh",  # Docker doit être installé en premier
    "graylog/install.sh",       # Installation de graylog
    "graylog/config.sh",        # Configuration de graylog
    "misp/install.sh",          # Clonage et configuration de Misp
    "Shuffle-docker/install.sh",          # Clonage et configuration de Shuffle
    "dfir-iris/install.sh",          # Clonage et configuration de iris-web

]

# Liste des sous-dossiers contenant des fichiers docker-compose.yml
SUBFOLDERS = [
    "misp-docker",
    "Shuffle",
    "iris-web",
]

