#!/bin/bash
#
#    ____       __     ___        __
#   / __ \___  / /_   / _ \____  / /_______ __
#  / / / / _ \/ __/  / , _/ __ \/ / __/ -_) /
# /_/ /_/\___/\__/  /_/|_|\___/_/\__/\__/_/
#
# Proyecto: debian-net-config-easy (TirsoTormo)
# Descripción: Automatiza la configuración de múltiples interfaces de red en Debian.
#
# -----------------------------------------------------------------

CONFIG_FILE="./config/net_config.cfg"
INTERFACES_FILE="/etc/network/interfaces"
BACKUP_FILE="${INTERFACES_FILE}.$(date +%Y%m%d_%H%M%S).bak"

# --- Funciones ---

# Función para obtener la lista de interfaces de red reales (excluye 'lo')
get_available_interfaces() {
    # Usa 'ip link show' para listar interfaces y 'awk/grep' para limpiar el output.
    ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | tr '\n' ' '
}

# 1. Verificar si el usuario es root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error de permisos: Por favor, ejecuta este script con sudo."
        exit 1
    fi
}

# Función para configurar una única interfaz de forma interactiva
configure_interface() {
    
    # 1. Escanear y mostrar interfaces disponibles para el usuario
    AVAILABLE_NICS=$(get_available_interfaces)
    echo "Interfaces disponibles en el sistema: ${AVAILABLE_NICS}"
    
    # Bucle para validar el nombre de la interfaz
    while true; do
        read -r -p "Introduce el nombre de la interfaz (DEBE ser una de las listadas arriba): " INTERFACE
        
        INTERFACE=$(echo "$INTERFACE" | xargs) # Limpieza de espacios
        
        # Validación de existencia
        if echo "$AVAILABLE_NICS" | grep -w -q "$INTERFACE"; then
            break # El nombre es válido, salir del bucle
        else
            echo "ERROR: La interfaz '$INTERFACE' no existe. Por favor, usa un nombre de la lista."
        fi
    done
    
    # 2. Obtener el método (static/dhcp)
    while true; do
        read -r -p "¿Será configuración estática o DHCP? (static/dhcp): " METHOD
        METHOD=$(echo "$METHOD" | tr '[:upper:]' '[:lower:]')
        if [[ "$METHOD" == "static" || "$METHOD" == "dhcp" ]]; then
            break
        else
            echo "Método no reconocido. Usa 'static' o 'dhcp'."
        fi
    done

    # Escribir la configuración base de la interfaz (auto y iface)
    echo "" >> "$INTERFACES_FILE"
    echo "auto ${INTERFACE}" >> "$INTERFACES_FILE"
    echo "iface ${INTERFACE} inet ${METHOD}" >> "$INTERFACES_FILE"

    # Bloque condicional: STATIC
    if [ "$METHOD" == "static" ]; then
        
        # --- Recolección de datos estáticos ---
        read -r -p "Introduce la dirección IP: " ADDRESS
        
        while true; do
            read -r -p "Introduce la máscara de red (formato: 255.255.255.0): " NETMASK
            # Simple comprobación para desalentar el formato CIDR
            if [[ "$NETMASK" == */* ]]; then
                echo "ADVERTENCIA: Por favor, utiliza la notación decimal con puntos (255.255.255.0)."
            else
                break
            fi
        done

        read -r -p "Introduce el Gateway/Puerta de enlace (Opcional, deja vacío): " GATEWAY
        # Nota: Aquí corregimos el error de variable DNS_SERVER por DNS_SERVERS
        read -r -p "Introduce los Servidores DNS (separados por espacio, ej. 8.8.8.8 1.1.1.1. Opcional): " DNS_SERVERS_INPUT
        
        # --- Limpieza de Espacios (CRÍTICO) ---
        ADDRESS=$(echo "$ADDRESS" | xargs)
        NETMASK=$(echo "$NETMASK" | xargs)
        GATEWAY=$(echo "$GATEWAY" | xargs)
        DNS_SERVERS=$(echo "$DNS_SERVERS_INPUT" | xargs) # Usamos la variable limpia
        
        # --- Validación y Escritura ---
        
        # Verificación de IP y Máscara (son obligatorios para static)
        if [ -z "$ADDRESS" ] || [ -z "$NETMASK" ]; then
            echo "ERROR: La Dirección IP y la Máscara de red son obligatorias para la configuración estática. El servicio fallará."
        else
            # Escribir dirección y máscara (obligatorio)
            echo "  address ${ADDRESS}" >> "$INTERFACES_FILE"
            echo "  netmask ${NETMASK}" >> "$INTERFACES_FILE"
        fi
        
        # Escribir Gateway solo si la variable NO está vacía (-n)
        if [ -n "$GATEWAY" ]; then
            echo "  gateway ${GATEWAY}" >> "$INTERFACES_FILE"
        fi 

        # Escribir DNS solo si la variable NO está vacía (-n)
        if [ -n "$DNS_SERVERS" ]; then
            echo "  dns-nameservers ${DNS_SERVERS}" >> "$INTERFACES_FILE"
        fi
        
    # Bloque DHCP
    elif [ "$METHOD" == "dhcp" ]; then
        echo "  # DNS y otras IPs serán proporcionadas por el servidor DHCP" >> "$INTERFACES_FILE"
    fi

    echo "Configuración de ${INTERFACE} registrada. Continúa con la siguiente."
}

# 2. Función principal (bucle interactivo)
process_interactive_config() {
    echo "Iniciando configuración automática e interactiva..."
    
    echo "Creando copia de seguridad de la configuración actual en ${BACKUP_FILE}"
    cp "$INTERFACES_FILE" "$BACKUP_FILE"

    echo "Generando el nuevo archivo ${INTERFACES_FILE}..."
    
    # Sobrescribir (>) el archivo interfaces con la configuración base
    cat << EOF > "$INTERFACES_FILE"
#
# Archivo de configuración generado por debian-net-config-easy
# Fecha de generación: $(date)
#
auto lo
iface lo inet loopback
EOF

    # Bucle para configurar múltiples tarjetas
    while true; do
        echo ""
        read -r -p "¿Quieres configurar una nueva tarjeta de red? (s/n): " ADD_CARD
        
        if [[ "$ADD_CARD" =~ ^[Nn]$ ]]; then
            break
        fi

        if [[ "$ADD_CARD" =~ ^[Ss]$ ]]; then
            configure_interface
        else
            echo "Respuesta no válida. Inténtalo de nuevo."
        fi
    done

    echo "Archivo de interfaces generado exitosamente."
}

# 3. Aplicar los cambios
apply_changes() {
    echo "Reiniciando el servicio de red..."
    
    if systemctl restart networking; then
        echo "Configuración aplicada con éxito!"
        echo "Verifica tu red con 'ip a' o 'ip route'."
    else
        echo "Error al reiniciar el servicio de red. Revisa el archivo ${INTERFACES_FILE}"
        echo "Restauración: cp ${BACKUP_FILE} ${INTERFACES_FILE}"
    fi
}

# --- Ejecución Principal ---

check_root
process_interactive_config
apply_changes

exit 0
