import os
import subprocess
import locale
from utils.script_messages import SCRIPT_MESSAGES  # Import des messages
from utils.display_urls import display_urls  # Import des URLs
from utils.script_folders import SUBFOLDERS
from utils.script_folders import ORDERED_SCRIPTS
import sys
import json
import time

STATUS_FILE = "status.json"
MAX_RETRIES = 3  # Maximum number of retries
RETRY_DELAY = 2  # Delay between retries, in seconds

def load_status():
    """Load the status file or initialize a new empty state."""
    if os.path.exists(STATUS_FILE):
        with open(STATUS_FILE, "r") as file:
            return json.load(file)
    return {}

def save_status(status):
    """Save the current status to the status file."""
    with open(STATUS_FILE, "w") as file:
        json.dump(status, file, indent=4)

def mark_as_completed(status, task):
    """Mark a task as completed in the status."""
    status[task] = "completed"
    save_status(status)

def mark_as_failed(status, task):
    """Mark a task as failed in the status."""
    status[task] = "failed"
    save_status(status)

def retry_operation(operation, max_retries, delay, *args, **kwargs):
    """
    Attempt to execute an operation with a maximum number of retries.
    """
    for attempt in range(1, max_retries + 1):
        try:
            operation(*args, **kwargs)
            return True  # Success
        except Exception as e:
            print(f"❌ Attempt {attempt}/{max_retries} failed: {e}")
            if attempt < max_retries:
                print(f"⏳ Retrying in {delay} seconds...")
                time.sleep(delay)
            else:
                print("🚫 All attempts failed.")
                return False
    return False


def main_menu():
    while True:
        display_menu()
        choice = input("Select an option: ").strip()
        if choice == "1":
            errors = run_check_requirements()
            print("\nSystem requirements not met. Fix the following issues before proceeding:")
            if errors:
                for error in errors:
                    break
                    #print(f" - {error}")
                input("\nPress Enter to return to the menu...")
                continue  # Retourne au menu sans exécuter les étapes suivantes
            # Si les exigences sont respectées, procéder à l'installation
            install_tools()
            show_dfir_iris_info()
            input("\nPress Enter to return to the menu...")
        elif choice == "2":
            print("Exiting...")
            break
        else:
            print("Invalid option. Please try again.")


def make_script_executable(script_path):
    try:
        # Rendre le script exécutable
        os.chmod(script_path, 0o755)  # 0o755 donne les permissions d'exécution
    except Exception as e:
        print(f"Error while changing permissions: {e}")


def run_check_requirements():
    script_path = os.path.join("utils", "check_requirements.sh")
    make_script_executable(script_path)  # Assurez-vous que le script est exécutable

    try:
        # Exécution du script Bash
        result = subprocess.run(
            [script_path],          # Commande à exécuter
            check=False,            # Ne pas lever une exception automatique
            stdout=subprocess.PIPE, # Capture la sortie standard
            stderr=subprocess.PIPE, # Capture la sortie d'erreur
            text=True               # Retourne des chaînes de caractères
        )

        # Vérification du code de retour
        if result.returncode != 0:
            print("Script exited with a non-zero status.")
            return ["[ERROR]: Unknown error during system check."]

        # Analyse de la sortie
        errors = []
        for line in result.stdout.splitlines():
            if "[ERROR]" in line:
                errors.append(line)

        # Affichage des résultats
        if errors:
            print("\nSystem requirements check failed:")
            for error in errors:
                print(f" - {error}")
        else:
            print("\nSystem meets the minimum requirements.")

        return errors

    except Exception as e:
        print(f"Failed to execute the script: {e}")
        return ["[ERROR]: Failed to execute system check script."]


# Fonction pour afficher le menu principal
def display_menu():
    os.system('clear')  # Effacer le terminal
    print("""
The SecOperations tools installation script, for Linux operating systems with DEB packages.

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
    """Execute Bash scripts while tracking state and handling retries."""
    current_dir = os.getcwd()
    status = load_status()

    for script in ORDERED_SCRIPTS:
        script_path = os.path.join(current_dir, script)
        if status.get(script) == "completed":
            print(f"✅ {script} already executed, skipping.")
            continue

        if script in SCRIPT_MESSAGES:
            if os.path.exists(script_path):
                success = retry_operation(
                    execute_script,
                    MAX_RETRIES,
                    RETRY_DELAY,
                    script_path,
                    SCRIPT_MESSAGES[script]
                )
                if success:
                    mark_as_completed(status, script)
                else:
                    mark_as_failed(status, script)
                    break  # Stop if all retries fail
            else:
                print(f"⚠️ Script not found: {script_path}")
                mark_as_failed(status, script)
        else:
            print(f"⚠️ No message defined for {script}. Script skipped.")


def deploy_docker_compose_projects():
    """Deploy Docker Compose projects while tracking state and handling retries."""
    current_dir = os.getcwd()
    status = load_status()

    for folder in SUBFOLDERS:
        folder_path = os.path.join(current_dir, folder)
        task_name = f"docker_{folder}"

        if status.get(task_name) == "completed":
            print(f"✅ Project {folder} already deployed, skipping.")
            continue

        docker_compose_file = os.path.join(folder_path, "docker-compose.yml")
        if os.path.exists(docker_compose_file):
            def deploy_folder():
                if folder == "misp-docker":
                    execute_docker_compose_command(folder_path, "build", SCRIPT_MESSAGES["misp build"])
                    execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["misp up"])
                elif folder == "Shuffle":
                    execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["shuffle up"])
                elif folder == "iris-web":
                    execute_docker_compose_command(folder_path, "pull", SCRIPT_MESSAGES["dfir-iris pull"])
                    execute_docker_compose_command(folder_path, "up -d", SCRIPT_MESSAGES["dfir-iris up"])

            success = retry_operation(deploy_folder, MAX_RETRIES, RETRY_DELAY)
            if success:
                mark_as_completed(status, task_name)
            else:
                mark_as_failed(status, task_name)
                break  # Stop if all retries fail
        else:
            print(f"⚠️ No docker-compose.yml file found in {folder_path}.")
            mark_as_failed(status, task_name)


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


# Fonction pour installer les outils
def install_tools():
    deploy_scripts()
    deploy_docker_compose_projects()
    display_urls()

if __name__ == "__main__":
     main_menu()
