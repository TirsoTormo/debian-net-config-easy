# 🛠️ debian-net-config-easy


Este proyecto fue desarrollado para facilitar configuracion **Targettas de Red**. Su propósito es **automatizar y simplificar** la tediosa tarea de configurar múltiples **tarjetas de red (NICs)** en entornos Debian.

En lugar de editar manualmente el archivo `/etc/network/interfaces` y arriesgarse a errores de sintaxis, esta herramienta ofrece un **asistente de configuración interactivo** que guía al usuario y asegura la aplicación correcta de los parámetros estáticos (IP, Máscara, Gateway y DNS) o DHCP.

---

## 🚀 Guía de Instalación y Ejecución

Sigue estos tres sencillos pasos para empezar a configurar tus interfaces de red.

### 1. Obtener el Código Fuente

Utiliza Git para clonar el repositorio en tu máquina Debian.

```bash
# Navega al directorio donde quieres guardar el proyecto (ej. /opt)
cd /opt

# Clona el repositorio
git clone https://github.com/TirsoTormo/debian-net-config-easy.git

# Accede al directorio del proyecto
cd debian-net-config-easy

# Darle permisos
chmod +x setup_networking.sh

# Ejecutalo
sudo ./setup_networking.sh
