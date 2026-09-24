#!/bin/bash

# ============================================================
#  Script de gestión de paquetes para Arch Linux
#  Uso: ./arch-pkg.sh [update|install|clean|full|help]
# ============================================================

# --- Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Detectar gestor de paquetes (yay > paru > pacman) ---
detect_pkg_manager() {
  if command -v yay >/dev/null 2>&1; then
    PKG="yay"
  elif command -v paru >/dev/null 2>&1; then
    PKG="paru"
  elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
  else
    echo -e "${RED}[ERROR] No se encontró pacman, yay ni paru.${NC}"
    exit 1
  fi
  echo -e "${CYAN}[INFO] Usando gestor: ${BOLD}${PKG}${NC}"
}

# --- Verificar que no se ejecute como root (rompe AUR helpers) ---
check_root() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[ERROR] No ejecute este script como root/sudo.${NC}"
    echo -e "${RED}El script pedirá permisos cuando sea necesario.${NC}"
    exit 1
  fi
}

# ============================================================
#  FUNCIÓN: Actualizar sistema
# ============================================================
do_update() {
  echo -e "\n${YELLOW}>> Actualizando el sistema...${NC}"
  detect_pkg_manager

  case "$PKG" in
  yay) yay -Syu ;;
  paru) paru -Syu ;;
  *) sudo pacman -Syu ;;
  esac

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERROR] La actualización falló.${NC}"
    return 1
  fi
  echo -e "${GREEN}[OK] Sistema actualizado.${NC}"
}

# ============================================================
#  FUNCIÓN: Instalar paquetes
# ============================================================
do_install() {
  detect_pkg_manager

  # Si no se pasan argumentos, modo interactivo
  if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}Ingrese los nombres de los paquetes (separados por espacio):${NC}"
    read -r -p "> " -a packages
    if [[ ${#packages[@]} -eq 0 ]]; then
      echo -e "${YELLOW}[INFO] No se especificaron paquetes. Saliendo.${NC}"
      return 0
    fi
  else
    packages=("$@")
  fi

  echo -e "\n${YELLOW}>> Instalando: ${BOLD}${packages[*]}${NC}"
  case "$PKG" in
  yay | paru) $PKG -S "${packages[@]}" ;;
  *) sudo pacman -S "${packages[@]}" ;;
  esac

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}[OK] Instalación completada.${NC}"
  else
    echo -e "${RED}[ERROR] La instalación falló.${NC}"
    return 1
  fi
}

# ============================================================
#  FUNCIÓN: Desinstalar paquetes
# ============================================================
do_remove() {
  detect_pkg_manager

  # Si no se pasan argumentos, modo interactivo
  if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}Ingrese el nombre del paquete:${NC}"
    read -r -p "> " -a packages
    if [[ ${#packages[@]} -eq 0 ]]; then
      echo -e "${YELLOW}[INFO] No se especificó ningún paquete. Saliendo.${NC}"
      return 0
    fi
  else
    packages=("$@")
  fi

  echo -e "\n${YELLOW}>> Desinstalando: ${BOLD}${packages[*]}${NC}"
  case "$PKG" in
  yay | paru) $PKG -Rsnc "${packages[@]}" ;;
  *) sudo pacman -Rsnc "${packages[@]}" ;;
  esac

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}[OK] Desinstalación completada.${NC}"
  else
    echo -e "${RED}[ERROR] La desinstalación falló.${NC}"
    return 1
  fi
}

# ============================================================
#  FUNCIÓN: Buscar paquetes
# ============================================================
do_search() {
  detect_pkg_manager

  # Si no se pasan argumentos, modo interactivo
  if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}Ingrese el nombre del paquete:${NC}"
    read -r -p "> " -a packages
    if [[ ${#packages[@]} -eq 0 ]]; then
      echo -e "${YELLOW}[INFO] No se especificó ningun paquete. Saliendo.${NC}"
      return 0
    fi
  else
    packages=("$@")
  fi

  echo -e "\n${YELLOW}>> Buscando: ${BOLD}${packages[*]}${NC}"
  case "$PKG" in
  yay | paru) $PKG -Ss "${packages[@]}" ;;
  *) sudo pacman -Ss "${packages[@]}" ;;
  esac

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}[OK] Busqueda completada.${NC}"
  else
    echo -e "${RED}[ERROR] No se encontró ninguna coincidencia.${NC}"
    return 1
  fi
}

# ============================================================
#  FUNCIÓN: Limpiar paquetes huérfanos
# ============================================================
do_clean_orphans() {
  echo -e "\n${YELLOW}>> Buscando paquetes huérfanos...${NC}"

  # -Qtdq: paquetes instalados como dependencia (-t) que no son
  #        requeridos por nadie (-d) y solo muestra nombres (-q)
  local orphans
  orphans=$(pacman -Qtdq)

  if [[ -z "$orphans" ]]; then
    echo -e "${GREEN}[OK] No hay paquetes huérfanos. Sistema limpio.${NC}"
    return 0
  fi

  echo -e "${RED}Se encontraron los siguientes paquetes huérfanos:${NC}"
  echo "$orphans" | column
  echo ""

  read -r -p "¿Desea eliminarlos? (s/N): " confirm
  if [[ "$confirm" =~ ^[sS]$ ]]; then
    echo "$orphans" | sudo pacman -Rns -
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}[OK] Huérfanos eliminados.${NC}"
    else
      echo -e "${RED}[ERROR] Falló la eliminación.${NC}"
    fi
  else
    echo -e "${CYAN}[INFO] Operación cancelada.${NC}"
  fi
}

# ============================================================
#  FUNCIÓN: Limpieza de caché (opcional)
# ============================================================
do_clean_cache() {
  if ! command -v paccache >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN] paccache no instalado. Instale 'pacman-contrib'.${NC}"
    return 1
  fi
  echo -e "\n${YELLOW}>> Limpiando caché de paquetes (manteniendo 3 versiones)...${NC}"
  sudo paccache -r
}

# ============================================================
#  FUNCIÓN: Actualización completa (update + clean cache + orphans)
# ============================================================
do_full() {
  do_update || return 1
  do_clean_cache
  do_clean_orphans
  echo -e "\n${GREEN}${BOLD}=========================================${NC}"
  echo -e "${GREEN}${BOLD}   ¡Mantenimiento completo finalizado!${NC}"
  echo -e "${GREEN}${BOLD}=========================================${NC}"
}

# ============================================================
#  MENÚ INTERACTIVO
# ============================================================
do_menu() {
  echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   Gestor de Paquetes para Arch Linux     ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}1${NC}) Actualizar sistema                   ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}2${NC}) Buscar paquetes                      ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}3${NC}) Instalar paquetes                    ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}4${NC}) Desinstalar paquetes                 ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}5${NC}) Limpiar paquetes huérfanos           ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}6${NC}) Actualización y limpieza completa    ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}7${NC}) Ayuda (Help)                         ${BOLD}║${NC}"
  echo -e "${BOLD}║${NC}  ${CYAN}0${NC}) Salir                                ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
  echo ""
  read -r -p "Seleccione una opción: " opt
  case "$opt" in
  1) do_update ;;
  2) do_search ;;
  3) do_install ;;
  4) do_remove ;;
  5) do_clean_orphans ;;
  6) do_full ;;
  7) show_help ;;
  0)
    echo -e "${CYAN}Adiós.${NC}"
    exit 0
    ;;
  *)
    echo -e "${RED}[ERROR] Opción inválida.${NC}"
    exit 1
    ;;
  esac
}

# ============================================================
#  AYUDA
# ============================================================
show_help() {
  echo ""
  echo -e "${BOLD}Uso:${NC} $0 [opción]"
  echo ""
  echo -e "${BOLD}Opciones:${NC}"
  echo -e "${CYAN}update${NC}             Actualiza el sistema (pacman/AUR)"
  echo -e "${CYAN}search [paqs...]${NC}   Busca paquetes (interactivo si no se pasan)"
  echo -e "${CYAN}install [paqs...]${NC}  Instala paquetes (interactivo si no se pasan)"
  echo -e "${CYAN}remove [paqs...]${NC}   Desinstala paquetes (interactivo si no se pasan)"
  echo -e "${CYAN}clean${NC}              Elimina paquetes huérfanos (con confirmación)"
  echo -e "${CYAN}full${NC}               Actualiza + limpia caché + elimina huérfanos"
  echo -e "${CYAN}help${NC}               Muestra esta ayuda"
  echo -e "${CYAN}(sin args)${NC}         Lanza el menú interactivo"
  echo ""
  echo -e "${BOLD}Ejemplos:${NC}"
  echo -e "$0 update"
  echo -e "$0 search neovim"
  echo -e "$0 install firefox vim git"
  echo -e "$0 remove neovim"
  echo -e "$0 clean"
  echo -e "$0 full"
  echo -e "$0 help"
}

# ============================================================
#  PUNTO DE ENTRADA
# ============================================================
check_root

case "${1:-}" in
update) do_update ;;
install)
  shift
  do_install "$@"
  ;;
search)
  shift
  do_search "$@"
  ;;
clean) do_clean_orphans ;;
full) do_full ;;
help | -h | --help) show_help ;;
"") do_menu ;;
*)
  echo -e "${RED}[ERROR] Opción desconocida: $1${NC}"
  show_help
  exit 1
  ;;
esac
