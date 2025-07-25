#!/bin/bash

set -e 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_cmd() {
    if [ "$USE_SUDO" = true ]; then
        sudo "$@" >/dev/null 2>&1;
    else
        "$@" >/dev/null 2>&1;
    fi
}

check_permissions() {
    log_info "Vérification des permissions..."
    if command -v sudo >/dev/null 2>&1; then
        log_info "sudo est disponible"
        if sudo -n true 2>/dev/null; then
            log_info "Permissions sudo confirmées"
            USE_SUDO=true
            return 0
        else
            log_warning "sudo est installé mais vous n'avez pas les permissions"
            log_info "Veuillez exécuter: sudo $0"
            exit 1
        fi
    else
        log_warning "sudo n'est pas installé sur ce système"
        
        #si root OK
        if [ "$EUID" -eq 0 ]; then
            log_info "Exécution en tant que root - permissions OK"
            USE_SUDO=false
            return 0
        else
            log_error "sudo n'est pas disponible et vous n'êtes pas root"
            log_error "Veuillez exécuter ce script en tant que root:"
            log_error "su -c '$0'"
            exit 1
        fi
    fi
}

#installation
install_docker() {
    log_info "Début de l'installation de Docker..."
    log_info "Suppression des anciens paquets Docker..."
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            log_info "Suppression de $pkg..."
            run_cmd apt-get remove -y $pkg
        else
            log_info "$pkg n'est pas installé, ignoré"
        fi
    done
    log_info "Mise à jour de la liste des paquets..."
    run_cmd apt-get update
    log_info "Installation des prérequis..."
    run_cmd apt-get install -y ca-certificates curl
    log_info "Configuration du répertoire des clés GPG..."
    run_cmd install -m 0755 -d /etc/apt/keyrings
    log_info "Téléchargement de la clé GPG Docker..."
    run_cmd curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    run_cmd chmod a+r /etc/apt/keyrings/docker.asc
    log_info "Ajout du dépôt Docker..."
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    run_cmd tee /etc/apt/sources.list.d/docker.list > /dev/null
    log_info "Mise à jour avec le nouveau dépôt..."
    run_cmd apt-get update
    log_info "Installation de Docker et ses composants..."
    run_cmd apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log_info "Vérification de l'installation..."
    if run_cmd docker --version; then
        log_info "Docker installé avec succès!"
        log_info "Version: $(run_cmd docker --version)"
    else
        log_error "Échec de l'installation de Docker"
        exit 1
    fi
    if [ "$USE_SUDO" = true ]; then
        log_info "Pour utiliser Docker sans sudo, ajoutez votre utilisateur au groupe docker:"
        log_info "sudo usermod -aG docker \$USER"
        log_info "Puis déconnectez-vous et reconnectez-vous."
    fi
}


main() {
    log_info "=== Script d'installation Docker ==="
    #OS Debian is OK
    if ! [ -f /etc/debian_version ]; then
        log_error "Ce script est conçu pour les systèmes Debian/Ubuntu"
        exit 1
    fi
    check_permissions
    install_docker    
    log_info "Installation terminée avec succès!"
}


main "$@"