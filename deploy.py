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
}

# Liste ordonnée des scripts à exécuter
ORDERED_SCRIPTS = [
    "utils/docker-install.sh",  # Docker doit être installé en premier
    "wazuh/install.sh",         # Ensuite, installer Wazuh
    "wazuh/config.sh"  # Configuration de Wazuh
]

def detect_language():
    """
    Détecte la langue du système pour adapter la réponse automatique aux prompts.
    """
    # Détecter la locale courante sans utiliser getdefaultlocale()
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

    # Détecter la langue et définir la réponse appropriée pour les prompts
    auto_response = detect_language()

    try:
        # Exécution du script avec suppression des sorties inutiles et désactivation des interactions
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

def deploy_scripts():
    """
    Exécute les scripts Bash dans l'ordre défini par ORDERED_SCRIPTS,
    en utilisant uniquement les messages définis dans SCRIPT_MESSAGES.
    """
    current_dir = os.getcwd()  # Répertoire contenant deploi.py

    for script in ORDERED_SCRIPTS:
        script_path = os.path.join(current_dir, script)
        if script in SCRIPT_MESSAGES:
            if os.path.exists(script_path):
                execute_script(script_path, SCRIPT_MESSAGES[script])
            else:
                print(f"⚠️ Script introuvable : {script_path}")
        else:
            print(f"⚠️ Aucun message défini pour {script}. Script ignoré.")

if __name__ == "__main__":
    deploy_scripts()
