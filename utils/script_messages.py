# Table de correspondance pour les messages personnalisés
SCRIPT_MESSAGES = {
    "utils/docker-install.sh": {
        "start": "� Installation de Docker en cours...",
        "success": "✅ Installation de Docker terminée avec succès.",
        "failure": "❌ Échec de l'installation de Docker."
    },
    "wazuh/install.sh": {
        "start": "� Installation de Wazuh en cours...",
        "success": "✅ Installation de Wazuh terminée avec succès.",
        "failure": "❌ Échec de l'installation de Wazuh."
    },
    "wazuh/config.sh": {
        "start": "� Configuration de Wazuh en cours...",
        "success": "✅ Configuration de Wazuh terminée avec succès.",
        "failure": "❌ Échec du déploiement de Wazuh."
    },
    "graylog/install.sh": {
        "start": "� Installation de Graylog en cours...",
        "success": "✅ Installation de Graylog terminée avec succès.",
        "failure": "❌ Échec de l'installation de Graylog."
    },
    "graylog/config.sh": {
        "start": "� Configuration de Graylog en cours...",
        "success": "✅ Configuration de Graylog terminée avec succès.",
        "failure": "❌ Échec du déploiement de Graylog."
    },
    "misp/config.sh": {
        "start": "� Clonage et configuration de Misp en cours...",
        "success": "✅ Clonage et configuration de Misp terminée avec succès.",
        "failure": "❌ Échec du Clonage et de la configuration de Misp."
    },
    "Shuffle-docker/config.sh": {
        "start": "� Clonage et configuration de Shuffle en cours...",
        "success": "✅ Clonage et configuration de Shuffle terminée avec succès.",
        "failure": "❌ Échec du Clonage et de la configuration de Suffle."
    },

    "misp build": {
        "start": "� Construction des images Docker pour MISP en cours...",
        "success": "✅ Construction des images Docker pour MISP terminée avec succès.",
        "failure": "❌ Échec de la construction des images Docker pour MISP."
    },
    "misp up": {
        "start": "� Démarrage des conteneurs Docker pour MISP en cours...",
        "success": "✅ Conteneurs Docker pour MISP démarrés avec succès.",
        "failure": "❌ Échec du démarrage des conteneurs Docker pour MISP."
    },
    "shuffle up": {
        "start": "� Démarrage des conteneurs Docker pour Shuffle en cours...",
        "success": "✅ Conteneurs Docker pour Shuffle démarrés avec succès.",
        "failure": "❌ Échec du démarrage des conteneurs Docker pour Shuffle."
    },
    "dfir-iris up": {
        "start": "� Démarrage des conteneurs Docker pour DFIR-IRIS en cours...",
        "success": "✅ Conteneurs Docker pour DFIR-IRIS démarrés avec succès.",
        "failure": "❌ Échec du démarrage des conteneurs Docker pour DFIR-IRIS."
    },
}
