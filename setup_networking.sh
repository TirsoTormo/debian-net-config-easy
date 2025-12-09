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

# 1. Verificar si el usuario es root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error de permisos: Por favor, ejecuta este script con sudo."
        exit 1
    fi
}

# Función para configurar una única interfaz de forma interactiva
configure_interface() {
    
    # 1. Obtener el nombre de la interfaz y el método (static/dhcp)
    
    read -r -p "Introduce el nombre de la interfaz (ej. eth0, enp0s3): " INTERFACE
    
    while true; do
        read -r -p "¿Será configuración estática o DHCP? (static/dhcp): " METHOD
        METHOD=$(echo "$METHOD" | tr '[:upper:]' '[:lower:]')
        if [[ "$METHOD" == "static" || "$METHOD" == "dhcp" ]]; then
            break
        else
            echo "Método no reconocido. Usa 'static' o 'dhcp'."
        fi
    done

    # Escribir la configuración base de la interfaz
    echo "" >> "$INTERFACES_FILE"
    echo "auto ${INTERFACE}" >> "$INTERFACES_FILE"
    echo "iface ${INTERFACE} inet ${METHOD}" >> "$INTERFACES_FILE"

    # 2. Bloque condicional: Solo si es estática, se piden los detalles
    if [ "$METHOD" == "static" ]; then
        
        # --- Preguntas SOLO para STATIC ---
        read -r -p "Introduce la dirección IP: " ADDRESS
        read -r -p "Introduce la máscara de red: " NETMASK
        read -r -p "Introduce el Gateway/Puerta de enlace (Opcional, deja vacío): " GATEWAY
        read -r -p "Introduce los Servidores DNS (separados por espacio, ej. 8.8.8.8 1.1.1.1. Opcional): " DNS_SERVERS
        
        # Escribir los detalles estáticos en el archivo
        echo "  address ${ADDRESS}" >> "$INTERFACES_FILE"
        echo "  netmask ${NETMASK}" >> "$INTERFACES_FILE"
        
        [ -n "$GATEWAY" ] && echo "  gateway ${GATEWAY}" >> "$INTERFACES_FILE" 

        # Añadir DNS (si se proporcionaron)
        if [ -n "$DNS_SERVERS" ]; then
            echo "  dns-nameservers ${DNS_SERVERS}" >> "$INTERFACES_FILE"
        fi
        
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
        echo "Error al reiniciar el servicio de red."
        echo "Restauración: cp ${BACKUP_FILE} ${INTERFACES_FILE}"
    fi
}

# --- Ejecución Principal ---

check_root
process_interactive_config
apply_changes

exit 0