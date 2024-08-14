# Skip MDM (Versión 0.2)

## Descripción

Este script permite evadir la gestión de dispositivos móviles (MDM) en dispositivos MacOS, especialmente útil durante la configuración inicial del sistema.

## Uso

Para utilizar este script, sigue estos pasos:

1. Copia el siguiente comando:

   ```bash
   curl https://raw.githubusercontent.com/bcastilloarce/Test-SKIP-MDM/main/MDMTest2.sh -o test.sh && chmod +x ./test.sh && ./test.sh

2. Pega y ejecuta el comando en la Terminal en modo de recuperación.

## Características

- Bypass automático de MDM en modo de recuperación
- Verificación de inscripción MDM
- Creación de usuario personalizado
- Bloqueo de hosts MDM
- Eliminación de perfiles de configuración

## Requisitos

- Compatible con MacOS en arquitecturas Intel y Apple Silicon (M1)
- Debe ejecutarse en modo de recuperación
- Modificaciones del script

En esta versión 0.2:

- Se ha mejorado la estructura y organización del código
- Se han añadido nuevas funciones para una mejor modularidad
- Se ha optimizado el manejo de errores y la retroalimentación al usuario
- Se han incluido tres nuevos dominios de host: gdmf.apple.com, acmdm.apple.com y albert.apple.com

## Contribuciones

Las contribuciones son bienvenidas. Si tienes sugerencias o mejoras, no dudes en abrir un issue o enviar un pull request.

## Licencia

Este script se distribuye bajo la licencia MIT. Consulta el archivo LICENSE para más detalles.

## Soporte

Para reportar problemas o hacer preguntas, por favor abre un issue en este repositorio.

Atribución
Este script ha sido adaptado del trabajo original de skipmdm-phoenixbot, con modificaciones y mejoras significativas.

Esta versión del README proporciona información más detallada y estructurada sobre el script, sus características y uso, al tiempo que mantiene la atribución original y añade secciones importantes como contribuciones y soporte.
