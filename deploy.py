import os
import subprocess
import locale
from utils.script_messages import SCRIPT_MESSAGES  # Import des messages
from utils.display_urls import display_urls  # Import des URLs
from utils.script_folders import SUBFOLDERS
from utils.script_folders import ORDERED_SCRIPTS
import sys

import subprocess
import sys

def check_and_install_pip():
    """Checks if 'pip' is installed and installs it if necessary."""
    try:
        # Silent check for pip presence
        subprocess.run([sys.executable, "-m", "pip", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError:
        print("Downloading and installing pip...")
        try:
            # Silent installation of python3-pip via apt
            subprocess.run(["apt", "update"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["apt", "install", "-y", "python3-pip"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("pip successfully installed.")
        except subprocess.CalledProcessError as e:
            print(f"Error during pip installation: {e}")
            sys.exit(1)
    try:
        # Silent pip upgrade
        subprocess.run([sys.executable, "-m", "pip", "install", "--upgrade", "pip"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as e:
        print(f"Error during pip upgrade: {e}")
        sys.exit(1)

def check_and_install_psutil():
    """Checks if 'psutil' is installed and installs it if necessary."""
    try:
        import psutil  # Check if psutil is installed
    except ImportError:
        print("Downloading and installing psutil...")
        try:
            # Silent installation of psutil via pip
            subprocess.run([sys.executable, "-m", "pip", "install", "psutil"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("psutil successfully installed.")
        except subprocess.CalledProcessError as e:
            print(f"Error during psutil installation: {e}")
            sys.exit(1)
    finally:
        # Import psutil after installation
        global psutil
        import psutil


# Fonction pour vérifier les ressources système
def check_system_requirements():
    cores = os.cpu_count()
    memory = psutil.virtual_memory().total / (1024 ** 3)  # Convertir en Go
    errors = []

    if cores < 4:
        errors.append(f"[ERROR]: 4 core CPUs required, but found {cores}.")
    if memory < 16:
        errors.append(f"[ERROR]: 16 GB of memory required, but found {memory:.2f} GB.")

    return errors


# Fonction pour afficher le menu principal
def display_menu():
    os.system('clear')  # Effacer le terminal
    print("""
The SecOperations tools  installation script, for Linux operating systems with DEB or RPM packages.
This script supports the installation of all tools on x86_64  only.

Following install options are available:
  - Install wazuh, docker, graylog, shuffle et dfir-iris

This script has successfully been tested on freshly installed Operating Systems:
  - Ubuntu 20.04 LTS & 22.04 LTS
  - Debian 11 & 12

Requirements:
  - 4vCPU
  - 16 GB of RAM

Usage:
   $ python3 deploy.py

Maintained by: Abibou DIALLO - https://www.linkedin.com/in/abibou-diallo-085869273/

---

1) Install wazuh, docker, graylog, shuffle et dfir-iris
2) Quit
""")



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
            elif folder == "iris-web":
                # Lancer les conteneurs Docker pour DFIR-IRIS
                execute_docker_compose_command(folder_path, "pull", SCRIPT_MESSAGES["dfir-iris pull"])
                execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["dfir-iris up"])
        else:
            print(f"⚠️ Aucun fichier docker-compose.yml trouvé dans {folder_path}.")


# Définir le nom du conteneur DFIR-IRIS
iriswebapp_app = "iriswebapp_app"  # Remplacez par le nom correct de votre conteneur

def get_dfir_iris_admin_password(container_name):
    try:
        # Construire la commande avec le pipe et grep
        command = f"docker logs {container_name} 2>&1 | grep 'WARNING :: post_init :: create_safe_admin'"

        # Exécuter la commande dans le shell
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=True  # Permet l'utilisation des pipes et des redirections
        )
        logs = result.stdout.strip()

        # Vérifier et extraire le mot de passe
        if "Administrator password:" in logs:
            password = logs.split("Administrator password:")[-1].strip()
            return password

        return "Mot de passe non trouvé dans les logs."
    except Exception as e:
        return f"Erreur lors de la récupération du mot de passe : {e}"

def show_dfir_iris_info():
    password = get_dfir_iris_admin_password(iriswebapp_app)
    print(f"IRIS user : administrator et le Mot de passe initial : {password}")

if __name__ == "__main__":
    show_dfir_iris_info()



# Fonction pour installer les outils
def install_tools():
    print("Checking system requirements...")
    errors = check_system_requirements()

    if errors:
        for error in errors:
            print(error)
        print("\n[ERROR]: Installation aborted. Please upgrade your system resources.")
        return
    deploy_scripts()
    deploy_docker_compose_projects()
    display_urls()

if __name__ == "__main__":
    while True:
        display_menu()
        choice = input("Select an option: ").strip()
        if choice == "1":
            check_and_install_pip()
            check_and_install_psutil()
            install_tools()
            show_dfir_iris_info
            input("\nPress Enter to return to the menu...")
        elif choice == "2":
            print("Exiting...")
            break
        else:
            print("Invalid option. Please try again.")
