#!/bin/bash

# Constantes globales
readonly DEFAULT_SYSTEM_VOLUME="Macintosh HD"
readonly DEFAULT_DATA_VOLUME="Macintosh HD - Data"
readonly DSCL_PATH="/private/var/db/dslocal/nodes/Default"
readonly LOCAL_USERS_PATH="/Local/Default/Users"
readonly DEFAULT_UID="501"
readonly HOSTS_FILE="/etc/hosts"
readonly CONFIG_PROFILES_PATH="/var/db/ConfigurationProfiles/Settings"

# Colores para formato de texto
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly NC='\033[0m'

# Función para imprimir mensajes con color
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Función para verificar la existencia de un volumen
check_volume_existence() {
    local volume_label="$1"
    diskutil info "$volume_label" &>/dev/null
}

# Función para obtener el nombre de un volumen por tipo
get_volume_name() {
    local volume_type="$1"
    local apfs_container
    local volume_info
    local volume_name

    apfs_container=$(diskutil list internal physical | grep 'Container' | awk -F'Container ' '{print $2}' | awk '{print $1}')
    volume_info=$(diskutil ap list "$apfs_container" | grep -A 5 "($volume_type)")
    volume_name=$(echo "$volume_info" | grep 'Name:' | cut -d':' -f2 | cut -d'(' -f1 | xargs)

    echo "$volume_name"
}

# Función para definir la ruta a un volumen
define_volume_path() {
    local default_volume="$1"
    local volume_type="$2"

    if check_volume_existence "$default_volume"; then
        echo "/Volumes/$default_volume"
    else
        local volume_name
        volume_name="$(get_volume_name "$volume_type")"
        echo "/Volumes/$volume_name"
    fi
}

# Función para montar un volumen
mount_volume() {
    local volume_path="$1"

    if [ ! -d "$volume_path" ]; then
        diskutil mount "$volume_path" || {
            print_colored "$RED" "Error: No se pudo montar $volume_path"
            exit 1
        }
    fi
}

# Función para crear un nuevo usuario
create_user() {
    local dscl_path="$1"
    local username="$2"
    local full_name="$3"
    local password="$4"

    dscl -f "$dscl_path" localhost -create "$LOCAL_USERS_PATH/$username" || return 1
    dscl -f "$dscl_path" localhost -create "$LOCAL_USERS_PATH/$username" UserShell "/bin/zsh" || return 1
    dscl -f "$dscl_path" localhost -create "$LOCAL_USERS_PATH/$username" RealName "$full_name" || return 1
    dscl -f "$dscl_path" localhost -create "$LOCAL_USERS_PATH/$username" UniqueID "$DEFAULT_UID" || return 1
    dscl -f "$dscl_path" localhost -create "$LOCAL_USERS_PATH/$username" PrimaryGroupID "20" || return 1
    mkdir -p "$data_volume_path/Users/$username" || return 1
    dscl -f "$dscl_path" localhost -create "$LOCAL_USERS_PATH/$username" NFSHomeDirectory "/Users/$username" || return 1
    dscl -f "$dscl_path" localhost -passwd "$LOCAL_USERS_PATH/$username" "$password" || return 1
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" || return 1
    return 0
}

# Función para bloquear hosts MDM
block_mdm_hosts() {
    local hosts_file="$1"
    local blocked_domains=(
        "deviceenrollment.apple.com"
        "mdmenrollment.apple.com"
        "iprofiles.apple.com"
        "gdmf.apple.com"
        "acmdm.apple.com"
        "albert.apple.com"
    )

    for domain in "${blocked_domains[@]}"; do
        echo "0.0.0.0 $domain" >> "$hosts_file" || {
            print_colored "$RED" "Error: No se pudo agregar $domain a $hosts_file"
            return 1
        }
    done
    return 0
}

# Función para remover perfiles de configuración
remove_config_profiles() {
    local config_profiles_path="$1"
    local data_volume_path="$2"

    touch "$data_volume_path/private/var/db/.AppleSetupDone" || return 1
    rm -rf "$config_profiles_path/.cloudConfigHasActivationRecord" || return 1
    rm -rf "$config_profiles_path/.cloudConfigRecordFound" || return 1
    touch "$config_profiles_path/.cloudConfigProfileInstalled" || return 1
    touch "$config_profiles_path/.cloudConfigRecordNotFound" || return 1
    return 0
}

# Función principal de bypass MDM
bypass_mdm() {
    print_colored "$BLUE" "Montando volúmenes..."

    local system_volume_path
    local data_volume_path
    system_volume_path=$(define_volume_path "$DEFAULT_SYSTEM_VOLUME" "System")
    data_volume_path=$(define_volume_path "$DEFAULT_DATA_VOLUME" "Data")

    mount_volume "$system_volume_path"
    mount_volume "$data_volume_path"

    print_colored "$GREEN" "Preparación de volúmenes completada"

    print_colored "$BLUE" "Verificando existencia de usuario"
    local dscl_path="$data_volume_path$DSCL_PATH"
    if ! dscl -f "$dscl_path" localhost -list "$LOCAL_USERS_PATH" UniqueID | grep -q "\<$DEFAULT_UID\>"; then
        print_colored "$CYAN" "Creando nuevo usuario"
        read -rp "Nombre completo (Predeterminado: Apple): " full_name
        full_name="${full_name:-Apple}"

        read -rp "Nombre de usuario (Predeterminado: Apple): " username
        username="${username:-Apple}"

        read -rsp "Contraseña (Predeterminado: 4 espacios): " password
        echo
        password="${password:-.   }"

        if create_user "$dscl_path" "$username" "$full_name" "$password"; then
            print_colored "$GREEN" "Usuario creado exitosamente"
        else
            print_colored "$RED" "Error: No se pudo crear el usuario"
            exit 1
        fi
    else
        print_colored "$BLUE" "Usuario ya existente"
    fi

    print_colored "$BLUE" "Bloqueando hosts MDM..."
    if block_mdm_hosts "$system_volume_path$HOSTS_FILE"; then
        print_colored "$GREEN" "Hosts bloqueados exitosamente"
    else
        print_colored "$RED" "Error: No se pudieron bloquear todos los hosts MDM"
        exit 1
    fi

    print_colored "$BLUE" "Removiendo perfiles de configuración"
    if remove_config_profiles "$system_volume_path$CONFIG_PROFILES_PATH" "$data_volume_path"; then
        print_colored "$GREEN" "Perfiles de configuración removidos exitosamente"
    else
        print_colored "$RED" "Error: No se pudieron remover todos los perfiles de configuración"
        exit 1
    fi

    print_colored "$GREEN" "------ Bypass automático COMPLETADO ------"
    print_colored "$CYAN" "------ Salga del Terminal. Reinicie el MacBook y DISFRUTE! ------"
}

# Función para verificar la inscripción MDM
check_mdm_enrollment() {
    if [ ! -f /usr/bin/profiles ]; then
        print_colored "$RED" "No use esta opción en recovery"
        return
    fi

    if ! sudo profiles show -type enrollment &>/dev/null; then
        print_colored "$GREEN" "Éxito: No se detectó inscripción MDM"
    else
        print_colored "$RED" "Fallo: Se detectó inscripción MDM activa"
    fi
}

# Menú principal
main_menu() {
    local PS3='Por favor, ingrese su elección: '
    local options=("Bypass automático en Recovery" "Verificar inscripción MDM" "Reiniciar" "Salir")

    select opt in "${options[@]}"; do
        case $opt in
            "Bypass automático en Recovery")
                bypass_mdm
                break
                ;;
            "Verificar inscripción MDM")
                check_mdm_enrollment
                ;;
            "Reiniciar")
                print_colored "$BLUE" "Reiniciando..."
                reboot
                ;;
            "Salir")
                print_colored "$BLUE" "Saliendo..."
                exit 0
                ;;
            *)
                print_colored "$RED" "Opción inválida $REPLY"
                ;;
        esac
    done
}

# Ejecutar el menú principal
main_menu