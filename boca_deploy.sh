#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOCA_DOCKER_DIR="$ROOT_DIR/boca-docker"
BOCA_URL="http://localhost:8000/boca"
ACTION="${1:-}"

write_section() {
  printf '\n%s\n' "Caramel Coders BOCA - $1"
}

assert_boca_dir() {
  if [ ! -d "$BOCA_DOCKER_DIR" ]; then
    echo "Diretorio nao encontrado: $BOCA_DOCKER_DIR" >&2
    exit 1
  fi
}

test_prerequisites() {
  docker --version >/dev/null
  docker compose version --short >/dev/null
  docker info >/dev/null
}

invoke_compose() {
  assert_boca_dir
  (
    cd "$BOCA_DOCKER_DIR"
    docker compose -f docker-compose.yml -f docker-compose.prod.yml "$@"
  )
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
  local temp_file
  temp_file="$ROOT_DIR/inject_profiles.php"
  cat > "$temp_file" <<'PHP'
<?php
putenv('BOCA_DB_HOST=boca-db');
putenv('BOCA_DB_PASSWORD=dAm0HAiC');
require_once '/var/www/boca/src/db.php';
$c = DBConnect();
$contestPass = hash('sha256', 'Ur#t4i@CCAIFG0!2026xZq');
$adminPass = hash('sha256', 'Ur#t4i@CCAIFG0!2026xZq2');
DBExec($c, "ALTER TABLE usertable ALTER COLUMN username TYPE varchar(50)");
DBExec($c, "UPDATE usertable SET username='CCASuperControlContest', userfullname='Systems', userpassword='$contestPass', usersession='', usersessionextra='' WHERE contestnumber=0 AND usersitenumber=1 AND usernumber=1");
DBExec($c, "INSERT INTO usertable (contestnumber, usersitenumber, usernumber, username, userfullname, userdesc, usertype, userenabled, usermultilogin, userpassword, userip, userlastlogin, usersession, usersessionextra, userlastlogout, userpermitip, updatetime, usericpcid, userinfo) VALUES (0, 1, 1000, 'CCASuperControlRuntime', 'Administrator', NULL, 'admin', 't', 't', '$adminPass', NULL, NULL, '', '', NULL, NULL, CAST(EXTRACT(EPOCH FROM now()) AS int), '', '') ON CONFLICT (contestnumber, usersitenumber, usernumber) DO UPDATE SET username=EXCLUDED.username, userfullname=EXCLUDED.userfullname, usertype=EXCLUDED.usertype, userenabled=EXCLUDED.userenabled, usermultilogin=EXCLUDED.usermultilogin, userpassword=EXCLUDED.userpassword, usersession='', usersessionextra='', updatetime=CAST(EXTRACT(EPOCH FROM now()) AS int)");
echo "Perfis aplicados com sucesso!\n";
?>
PHP
  docker cp "$temp_file" boca-docker-boca-web-1:/var/www/boca/src/inject.php >/dev/null
  docker exec boca-docker-boca-web-1 php /var/www/boca/src/inject.php
  docker exec boca-docker-boca-web-1 rm /var/www/boca/src/inject.php >/dev/null
  rm -f "$temp_file"
}

install_boca() {
  write_section "Install"
  test_prerequisites
  invoke_compose up -d --build
  wait_boca
  apply_profiles
  printf '%s\n' "BOCA: $BOCA_URL"
  printf '%s\n' "Grafana: http://localhost:3001"
}

start_boca() {
  write_section "Start"
  invoke_compose up -d
  wait_boca
  printf '%s\n' "BOCA: $BOCA_URL"
}

stop_boca() {
  write_section "Stop"
  invoke_compose down
}

status_boca() {
  write_section "Status"
  invoke_compose ps
}

logs_boca() {
  write_section "Logs"
  invoke_compose logs -f --tail=50
}

restart_boca() {
  write_section "Restart"
  invoke_compose restart
  wait_boca
  printf '%s\n' "BOCA: $BOCA_URL"
}

reset_boca() {
  write_section "Reset"
  read -r -p "Digite SIM para remover containers e volumes: " confirmation
  if [ "$confirmation" != "SIM" ]; then
    echo "Operacao cancelada."
    return
  fi
  invoke_compose down -v
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

show_menu() {
  while true; do
    write_section "Menu"
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
      *) echo "Opcao invalida." ;;
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
  *) show_menu ;;
esac
