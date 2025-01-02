import os
import subprocess
import locale
from utils.script_messages import SCRIPT_MESSAGES  # Import des messages
from utils.display_banner import display_banner  # Import de la bannière
from utils.display_urls import display_urls  # Import des URLs
from utils.script_folders import SUBFOLDERS
from utils.script_folders import ORDERED_SCRIPTS
import platform
import json
import time


def save_deploy_status(status_file, status):
    """
    Sauvegarde l'état actuel du déploiement dans un fichier JSON.
    """
    with open(status_file, "w") as f:
        json.dump(status, f, indent=4)

def load_deploy_status(status_file):
    """
    Charge l'état actuel du déploiement depuis un fichier JSON.
    """
    if os.path.exists(status_file):
        with open(status_file, "r") as f:
            return json.load(f)
    return {}


def clear_terminal():
    """
    Efface le terminal pour un affichage propre.
    Fonctionne sur Linux, macOS et Windows.
    """
    try:
        system_name = platform.system()
        if system_name == "Windows":
            os.system("cls")  # Commande pour effacer le terminal sous Windows
        else:
            os.system("clear")  # Commande pour effacer le terminal sous Linux/macOS
    except Exception as e:
        print(f"Erreur lors de l'effacement du terminal : {e}")


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


def execute_docker_compose_command(folder_path, command, messages, retries=3):
    """
    Exécute une commande Docker Compose dans un dossier spécifique.
    Gère les tentatives en cas d'échec.
    """
    print(messages["start"])
    attempt = 0

    while attempt < retries:
        try:
            result = subprocess.run(
                ["docker", "compose"] + command.split(),
                cwd=folder_path,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                text=True
            )
            print(messages["success"])
            print(result.stdout.strip())
            return True
        except subprocess.CalledProcessError as e:
            attempt += 1
            print(messages["failure"])
            print(f"Détails de l'erreur : {e.stderr.strip()}")
            if attempt < retries:
                print(f"Nouvelle tentative ({attempt}/{retries}) dans 5 secondes...")
                time.sleep(5)
    print(f"Échec après {retries} tentatives.")
    print(f"S'il vous plaît, vérifiez la vitesse de votre connexion.")
    return False


def deploy_scripts(status, status_file):
    """
    Exécute les scripts Bash dans l'ordre défini par ORDERED_SCRIPTS,
    en utilisant uniquement les messages définis dans SCRIPT_MESSAGES.
    """
    current_dir = os.getcwd()

    for script in ORDERED_SCRIPTS:
        if status.get(script) == "completed":
            print(f"⏩ Script déjà exécuté : {script}")
            continue

        script_path = os.path.join(current_dir, script)
        if script in SCRIPT_MESSAGES:
            if os.path.exists(script_path):
                success = execute_script(script_path, SCRIPT_MESSAGES[script])
                if success:
                    status[script] = "completed"
                    save_deploy_status(status_file, status)
            else:
                print(f"⚠️ Script introuvable : {script_path}")
        else:
            print(f"⚠️ Aucun message défini pour {script}. Script ignoré.")



def deploy_docker_compose_projects(status, status_file):
    """
    Déploie les projets Docker Compose dans chaque sous-dossier défini dans SUBFOLDERS.
    """
    current_dir = os.getcwd()

    for folder in SUBFOLDERS:
        if status.get(folder) == "completed":
            print(f"⏩ Projet Docker Compose déjà déployé : {folder}")
            continue

        folder_path = os.path.join(current_dir, folder)
        docker_compose_file = os.path.join(folder_path, "docker-compose.yml")

        if os.path.exists(docker_compose_file):
            if folder == "misp-docker":
                if execute_docker_compose_command(folder_path, "build", SCRIPT_MESSAGES["misp build"]):
                    if execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["misp up"]):
                        status[folder] = "completed"
                        save_deploy_status(status_file, status)

            elif folder == "Shuffle":
                if execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["shuffle up"]):
                    status[folder] = "completed"
                    save_deploy_status(status_file, status)

            elif folder == "iris-web":
                if execute_docker_compose_command(folder_path, "pull", SCRIPT_MESSAGES["dfir-iris pull"]):
                    if execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["dfir-iris up"]):
                        status[folder] = "completed"
                        save_deploy_status(status_file, status)
        else:
            print(f"⚠️ Aucun fichier docker-compose.yml trouvé dans {folder_path}.")


if __name__ == "__main__":
    STATUS_FILE = "deploy_status.json"
    status = load_deploy_status(STATUS_FILE)
    display_banner()  # Affiche la bannière
    input("\nAppuyez sur Entrée pour continuer...")  # Pause avant de continuer
    clear_terminal
    deploy_scripts()
    deploy_docker_compose_projects()
    display_urls()
    print("\n✅ Déploiement terminé avec succès !")
