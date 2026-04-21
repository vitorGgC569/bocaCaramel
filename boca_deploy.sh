#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BOCA_DOCKER_DIR="${BOCA_DOCKER_DIR:-$ROOT_DIR/boca-docker}"
BOCA_URL="${BOCA_URL:-http://localhost:8000/boca}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3001}"
ACTION="${1:-menu}"
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.prod.yml)

section() {
  printf '\nCaramel Coders BOCA - %s\n' "$1"
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Comando nao encontrado: $1"
}

assert_boca_dir() {
  [ -d "$BOCA_DOCKER_DIR" ] || fail "Diretorio nao encontrado: $BOCA_DOCKER_DIR"
}

test_prerequisites() {
  require_command docker
  require_command curl
  docker compose version --short >/dev/null
  docker info >/dev/null
}

compose() {
  assert_boca_dir
  (
    cd "$BOCA_DOCKER_DIR"
    docker compose "${COMPOSE_FILES[@]}" "$@"
  )
}

container_id() {
  compose ps -q "$1"
}

web_container() {
  local id
  id="$(container_id boca-web)"
  [ -n "$id" ] || fail "Container boca-web nao encontrado. Execute ./boca_deploy.sh start ou install."
  printf '%s\n' "$id"
}

wait_boca() {
  local attempt=0
  while [ "$attempt" -lt 36 ]; do
    if curl -fsS "$BOCA_URL" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 5
  done
  return 1
}

apply_profiles() {
  local web
  web="$(web_container)"
  (
  temp_file="$(mktemp "${TMPDIR:-/tmp}/boca_profiles.XXXXXX.php")"
  trap 'rm -f "$temp_file"' EXIT
  cat > "$temp_file" <<'PHP'
<?php
putenv('BOCA_DB_HOST=boca-db');
putenv('BOCA_DB_PASSWORD=dAm0HAiC');
require_once '/var/www/boca/src/db.php';
$c = DBConnect();
$contestPass = hash('sha256', 'Ur#t4i@CCAIFG0!2026xZq');
$adminPass = hash('sha256', 'Ur#t4i@CCAIFG0!2026xZq2');
DBExec($c, "ALTER TABLE usertable ALTER COLUMN username TYPE varchar(50)");
DBExec($c, "UPDATE sitetable SET siteautojudge='t'");
DBExec($c, "UPDATE usertable SET username='CCASuperControlContest', userfullname='Systems', userpassword='$contestPass', usersession='', usersessionextra='' WHERE contestnumber=0 AND usersitenumber=1 AND usernumber=1");
DBExec($c, "INSERT INTO usertable (contestnumber, usersitenumber, usernumber, username, userfullname, userdesc, usertype, userenabled, usermultilogin, userpassword, userip, userlastlogin, usersession, usersessionextra, userlastlogout, userpermitip, updatetime, usericpcid, userinfo) VALUES (0, 1, 1000, 'CCASuperControlRuntime', 'Administrator', NULL, 'admin', 't', 't', '$adminPass', NULL, NULL, '', '', NULL, NULL, CAST(EXTRACT(EPOCH FROM now()) AS int), '', '') ON CONFLICT (contestnumber, usersitenumber, usernumber) DO UPDATE SET username=EXCLUDED.username, userfullname=EXCLUDED.userfullname, usertype=EXCLUDED.usertype, userenabled=EXCLUDED.userenabled, usermultilogin=EXCLUDED.usermultilogin, userpassword=EXCLUDED.userpassword, usersession='', usersessionextra='', updatetime=CAST(EXTRACT(EPOCH FROM now()) AS int)");
echo "Perfis aplicados com sucesso!\n";
?>
PHP
  docker exec "$web" rm -f /var/www/boca/src/inject.php >/dev/null 2>&1 || true
  docker cp "$temp_file" "$web:/var/www/boca/src/inject.php" >/dev/null
  docker exec "$web" php /var/www/boca/src/inject.php
  docker exec "$web" rm -f /var/www/boca/src/inject.php >/dev/null
  )
}

install_boca() {
  section "Install"
  test_prerequisites
  compose up -d --build
  wait_boca || fail "BOCA nao respondeu dentro do tempo esperado."
  apply_profiles
  printf 'BOCA: %s\n' "$BOCA_URL"
  printf 'Grafana: %s\n' "$GRAFANA_URL"
}

start_boca() {
  section "Start"
  test_prerequisites
  compose up -d
  wait_boca || fail "BOCA nao respondeu dentro do tempo esperado."
  printf 'BOCA: %s\n' "$BOCA_URL"
}

stop_boca() {
  section "Stop"
  compose down
}

status_boca() {
  section "Status"
  compose ps
}

logs_boca() {
  section "Logs"
  compose logs -f --tail=50
}

restart_boca() {
  section "Restart"
  compose restart
  wait_boca || fail "BOCA nao respondeu dentro do tempo esperado."
  printf 'BOCA: %s\n' "$BOCA_URL"
}

reset_boca() {
  section "Reset"
  read -r -p "Digite SIM para remover containers e volumes: " confirmation
  if [ "$confirmation" != "SIM" ]; then
    printf '%s\n' "Operacao cancelada."
    return
  fi
  compose down -v
}

open_boca() {
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$BOCA_URL" >/dev/null 2>&1 &
    return
  fi
  if command -v open >/dev/null 2>&1; then
    open "$BOCA_URL"
    return
  fi
  printf '%s\n' "$BOCA_URL"
}

usage() {
  cat <<EOF
Uso: ./boca_deploy.sh <comando>

Comandos:
  install   Constroi, sobe o ambiente e aplica os perfis padrao
  start     Sobe o ambiente existente
  stop      Derruba os containers sem remover volumes
  status    Mostra o estado dos servicos
  logs      Mostra logs em tempo real
  restart   Reinicia os servicos
  reset     Remove containers e volumes apos confirmacao
  profiles  Reaplica usuarios padrao e autojudge nos sites
  open      Abre a URL do BOCA
  menu      Abre o menu interativo
  help      Mostra esta ajuda
EOF
}

show_menu() {
  while true; do
    section "Menu"
    printf '%s\n' "1. install"
    printf '%s\n' "2. start"
    printf '%s\n' "3. stop"
    printf '%s\n' "4. status"
    printf '%s\n' "5. logs"
    printf '%s\n' "6. restart"
    printf '%s\n' "7. reset"
    printf '%s\n' "8. profiles"
    printf '%s\n' "9. open"
    printf '%s\n' "0. sair"
    read -r -p "Escolha uma opcao: " choice
    case "$choice" in
      1) install_boca ;;
      2) start_boca ;;
      3) stop_boca ;;
      4) status_boca ;;
      5) logs_boca ;;
      6) restart_boca ;;
      7) reset_boca ;;
      8) apply_profiles ;;
      9) open_boca ;;
      0) exit 0 ;;
      *) printf '%s\n' "Opcao invalida." ;;
    esac
  done
}

case "$ACTION" in
  install) install_boca ;;
  start) start_boca ;;
  stop) stop_boca ;;
  status) status_boca ;;
  logs) logs_boca ;;
  restart) restart_boca ;;
  reset) reset_boca ;;
  profiles) apply_profiles ;;
  open) open_boca ;;
  menu) show_menu ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
