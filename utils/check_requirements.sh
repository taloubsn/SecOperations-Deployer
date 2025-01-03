#!/bin/bash

# Fonction pour vérifier les ressources système
check_system_requirements() {
    # Nombre de cœurs CPU
    cores=$(nproc)
    # Mémoire totale en Go
    memory=$(free -g | awk '/^Mem:/ {print $2}')
    
    # Initialisation des erreurs
    errors=()

    # Vérification du nombre de cœurs CPU
    if [ "$cores" -lt 4 ]; then
        errors+=("[ERROR]: 4 core CPUs required, but found $cores.")
    fi

    # Vérification de la mémoire
    if [ "$memory" -lt 16 ]; then
        errors+=("[ERROR]: 16 GB of memory required, but found ${memory} GB.")
    fi

    # Affichage des erreurs ou confirmation
    if [ "${#errors[@]}" -eq 0 ]; then
        echo "System meets the minimum requirements."
    else
        for error in "${errors[@]}"; do
            echo "$error"
        done
    fi
}

# Exécution de la fonction
check_system_requirements

