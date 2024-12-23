import os
import subprocess

# Table de correspondance pour les messages personnalisés
SCRIPT_MESSAGES = {
    "wazuh/install.sh": {
        "start": "🔄 Installation de Wazuh en cours...",
        "success": "✅ Installation de Wazuh terminée avec succès.",
        "failure": "❌ Échec de l'installation de Wazuh."
    },
    "wazuh/config.sh": {
        "start": "🔄 Configuration de Wazuh en cours...",
        "success": "✅ Configuration de Wazuh terminé avec succès.",
        "failure": "❌ Échec du déploiement de Wazuh."
    },
}

def find_bash_scripts(current_dir, ignore_scripts=None):
    """
    Trouve tous les fichiers .sh dans les sous-dossiers directement liés au répertoire courant.
    Permet d'ignorer certains fichiers spécifiques.
    """
    if ignore_scripts is None:
        ignore_scripts = []

    scripts = []
    for folder in os.listdir(current_dir):
        folder_path = os.path.join(current_dir, folder)
        if os.path.isdir(folder_path):  # Vérifie si c'est un dossier
            for file in os.listdir(folder_path):
                if file.endswith(".sh") and file not in ignore_scripts:
                    relative_path = os.path.join(folder, file)  # Chemin relatif pour correspondre à la table
                    scripts.append(relative_path)
    return scripts

def execute_script(script_path):
    """
    Exécute un script Bash avec des messages personnalisés gérés depuis le dictionnaire SCRIPT_MESSAGES.
    """
    messages = SCRIPT_MESSAGES.get(script_path, {
        "start": f"🔄 Exécution du script : {script_path}",
        "success": f"✅ Succès : {script_path}",
        "failure": f"❌ Échec : {script_path}"
    })

    print(messages["start"])
    try:
        # Exécuter le script avec suppression des sorties dans le terminal
        result = subprocess.run(
            ["bash", script_path],
            check=True,
            stdout=subprocess.PIPE,  # Capture la sortie standard
            stderr=subprocess.PIPE,  # Capture la sortie d'erreur
            text=True
        )
        print(messages["success"])
        # Si besoin, afficher la sortie capturée
        if result.stdout.strip():
            print(f"📄 Sortie :\n{result.stdout.strip()}")
    except subprocess.CalledProcessError as e:
        print(messages["failure"])
        print(f"💡 Erreur :\n{e.stderr.strip()}")

def deploy_scripts():
    """
    Détecte et exécute tous les scripts Bash dans les sous-dossiers du répertoire courant,
    en ignorant ceux spécifiés.
    """
    current_dir = os.getcwd()  # Répertoire contenant deploi.py
    
    # Liste des scripts à ignorer (par leur nom)
    ignore_scripts = ["ignore_this.sh", "skip_me.sh"]

    scripts = find_bash_scripts(current_dir, ignore_scripts)
    
    if not scripts:
        print("📂 Aucun script trouvé.")
        return
    
    for script in scripts:
        execute_script(script)

if __name__ == "__main__":
    deploy_scripts()

