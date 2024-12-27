import os
import subprocess
import locale

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

# Liste ordonnée des scripts à exécuter
ORDERED_SCRIPTS = [
    "wazuh/install.sh",         # Ensuite, installer Wazuh
    "wazuh/config.sh",          # Configuration de Wazuh
    "utils/docker-install.sh",  # Docker doit être installé en premier
    "graylog/install.sh",       # Installation de graylog
    "graylog/config.sh",        # Configuration de graylog
    "misp/install.sh",          # Clonage et configuration de Misp
    "Shuffle-docker/install.sh",          # Clonage et configuration de Shuffle

]

# Liste des sous-dossiers contenant des fichiers docker-compose.yml
SUBFOLDERS = [
    "Shuffle",
    "misp-docker",
    "dfir-iris",
]

def detect_language():
    """
    Détecte la langue du système pour adapter la réponse automatique aux prompts.
    """
    lang = locale.getlocale()[0]
    if lang and lang.startswith('fr'):  # Si la langue est française
        return "o/n"
    else:  # Par défaut, on suppose que la langue est l'anglais
        return "y/n"

def execute_script(script_path, messages):
    """
    Exécute un script Bash en affichant uniquement les messages définis dans SCRIPT_MESSAGES.
    Redirige les sorties indésirables.
    """
    print(messages["start"])

    auto_response = detect_language()

    try:
        result = subprocess.run(
            ["bash", script_path],
            check=True,
            stdout=subprocess.DEVNULL,  # Supprime la sortie standard
            stderr=subprocess.DEVNULL,  # Supprime la sortie d'erreur
            text=True,
            input=f"{auto_response[0]}\n"  # Répond automatiquement "o" ou "y" selon la langue
        )
        print(messages["success"])
    except subprocess.CalledProcessError as e:
        print(messages["failure"])
        print(f"� Détails de l'erreur : {e.stderr.strip()}")

def execute_docker_compose_command(folder_path, command, messages):
    """
    Exécute une commande Docker Compose dans un dossier spécifique.
    """
    print(messages["start"])
    try:
        result = subprocess.run(
            ["docker", "compose"] + command.split(),
            cwd=folder_path,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print(messages["success"])
        print(result.stdout.strip())
    except subprocess.CalledProcessError as e:
        print(messages["failure"])
        print(f"� Détails de l'erreur : {e.stderr.strip()}")

def deploy_scripts():
    """
    Exécute les scripts Bash dans l'ordre défini par ORDERED_SCRIPTS,
    en utilisant uniquement les messages définis dans SCRIPT_MESSAGES.
    """
    current_dir = os.getcwd()

    for script in ORDERED_SCRIPTS:
        script_path = os.path.join(current_dir, script)
        if script in SCRIPT_MESSAGES:
            if os.path.exists(script_path):
                execute_script(script_path, SCRIPT_MESSAGES[script])
            else:
                print(f"⚠️ Script introuvable : {script_path}")
        else:
            print(f"⚠️ Aucun message défini pour {script}. Script ignoré.")

def deploy_docker_compose_projects():
    """
    Déploie les projets Docker Compose dans chaque sous-dossier défini dans SUBFOLDERS.
    """
    current_dir = os.getcwd()

    for folder in SUBFOLDERS:
        folder_path = os.path.join(current_dir, folder)
        docker_compose_file = os.path.join(folder_path, "docker-compose.yml")

        if os.path.exists(docker_compose_file):
            #print(f"� Traitement du dossier : {folder}")

            if folder == "misp-docker":
                # Étape 1 : Construire les images Docker pour MISP
                execute_docker_compose_command(folder_path, "build", SCRIPT_MESSAGES["misp build"])
                # Étape 2 : Lancer les conteneurs Docker pour MISP
                execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["misp up"])
            elif folder == "Shuffle":
                # Lancer les conteneurs Docker pour Shuffle
                execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["shuffle up"])
            elif folder == "dfir-iris":
                # Lancer les conteneurs Docker pour DFIR-IRIS
                execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["dfir-iris up"])
        else:
            print(f"⚠️ Aucun fichier docker-compose.yml trouvé dans {folder_path}.")

if __name__ == "__main__":
    deploy_scripts()
    deploy_docker_compose_projects()
