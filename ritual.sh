#!/bin/bash

GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
NC='\033[0m'  # No Color

LOG_FILE="$HOME/processed.log"
CONFIG_FILE="wallets.conf"


function print_step() {
  echo -e "${BRIGHT_GREEN}==================================================${NC}"
  echo -e "${GREEN}$1${NC}"
  echo -e "${BRIGHT_GREEN}==================================================${NC}"
}

# Функция для отображения анимированного спиннера
function spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  echo -n " "
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "${GREEN} [%c]  ${NC}" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Функция для отображения анимированного баннера
function print_banner() {
  echo -e "${GREEN}🌟🌟🌟 Добро пожаловать в установщик Ritual Node 🌟🌟🌟${NC}"
  sleep 1
  echo -e "${GREEN}Этот скрипт поможет вам установить и настроить все необходимые компоненты.${NC}"
  echo -e "${GREEN}Пожалуйста, следите за инструкциями на экране для лучшего опыта.${NC}"
  echo ""
}

# Обработка ошибок с подробным сообщением
function handle_error() {
  local step=$1
  echo -e "${BRIGHT_GREEN}⚠️ Произошла ошибка на этапе: '$step'${NC}"
  echo -e "${BRIGHT_GREEN}Пожалуйста, обратитесь в чат поддержки для помощи.${NC}"
  exit 1
}

# Функция для установки Forge
install_forge() {
  print_step "Установка Forge"
  curl -L https://foundry.paradigm.xyz | bash
  source /root/.bashrc
  foundryup
}

# Функция для проверки и установки Docker
install_docker() {
   print_step "Установка необходимых пакетов и Docker"

    # Обновление системы и установка необходимых пакетов
  sudo apt update && sudo apt upgrade -y
  sudo apt -qy install curl git jq lz4 build-essential screen apt-transport-https ca-certificates software-properties-common

  # Проверка наличия Docker
  if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}🐳 Docker не найден, начинаем установку...${NC}"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt install docker-ce -qy
    echo -e "${GREEN}🐳 Docker успешно установлен.${NC}"
  else
    echo -e "${GREEN}🐳 Docker уже установлен.${NC}"
  fi
}

# Функция для установки make и инструментов сборки
install_build_tools() {
  print_step "Проверка и установка make и инструментов сборки"
  if ! command -v make &> /dev/null; then
    echo -e "${GREEN}🛠 Установка make и инструментов сборки...${NC}"
    sudo apt-get install build-essential -y
    echo -e "${GREEN}🛠 make успешно установлен.${NC}"
  else
    echo -e "${GREEN}🛠 make уже установлен.${NC}"
  fi
}

# Функция для клонирования и настройки репозитория
setup_repository() {
  print_step "Настройка репозитория"

  # Проверка на наличие репозитория
  if [ -d "$HOME/infernet-container-starter" ]; then
    echo -e "${GREEN}Репозиторий уже существует. Переход в директорию...${NC}"
    cd $HOME/infernet-container-starter
  else
    echo -e "${GREEN}Репозиторий не найден. Клонирование...${NC}"
    git clone --recurse-submodules https://github.com/ritual-net/infernet-container-starter $HOME/infernet-container-starter || handle_error "Клонирование репозитория"
    cd $HOME/infernet-container-starter || handle_error "Переход в директорию репозитория"
  fi

  docker_compose_file="$HOME/infernet-container-starter/deploy/docker-compose.yaml"

  # Изменение портов в docker-compose.yaml
  sed -i 's/8545:3000/8545:3051/' "$docker_compose_file" || handle_error "Изменение портов в docker-compose.yaml"
  sed -i 's/--port 3000/--port 3051/' "$docker_compose_file" || handle_error "Изменение портов в docker-compose.yaml"
  sed -i 's/3000:3000/3051:3051/' "$docker_compose_file" || handle_error "Изменение портов в docker-compose.yaml"
  sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$docker_compose_file" || handle_error "Изменение портов в docker-compose.yaml"

  screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
  screen -dmS ritual
  screen -S ritual -p 0 -X stuff "project=hello-world make deploy-container\n"
  sleep 15
}

# Функция для обновления файлов конфигурации
update_config_files() {
  local wallet=$1
  local private_key=$2

  [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"

  print_step "Обновление файлов конфигурации для $wallet"

  config_file="/root/infernet-container-starter/deploy/config.json"
  docker_compose_file="/root/infernet-container-starter/deploy/docker-compose.yaml"

  # Изменение портов в docker-compose.yaml
  sed -i 's/8545:3000/8545:3051/' "$docker_compose_file"
  sed -i 's/--port 3000/--port 3051/' "$docker_compose_file"
  sed -i 's/3000:3000/3051:3051/' "$docker_compose_file"
  sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$docker_compose_file"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Порт успешно изменен на 3051 в файле docker-compose.yaml.${NC}"
  else
    echo -e "${GREEN}Произошла ошибка при изменении порта.${NC}"
  fi

  sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$config_file"
  sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://base-rpc.publicnode.com\",|" "$config_file"
  sed -i "s|\"private_key\":.*|\"private_key\": \"$private_key\"|" "$config_file"
  sed -i 's/"port": "3000"/"port": "3051"/' "$config_file"
  sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$config_file"

    # Новое значение для поля "snapshot_sync"
  snapshot_sync_value='{"snapshot_sync": {"sleep": 5, "batch_size": 50}}'

    # Обновление или добавление поля "snapshot_sync" с помощью sed
  sed -i '/"snapshot_sync": {/c\'"$snapshot_sync_value" "$config_file"

  new_rpc_url="https://base-rpc.publicnode.com"
  sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|sender := .*|sender := $private_key|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
  sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|RPC_URL := .*|RPC_URL := $new_rpc_url|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
  sed -i "s|address registry.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
}

# Функция для развертывания и обновления конфигурации
deploy_and_update_config() {
    print_step "Развертывание контракта и обновление конфигурации"

    cd "$HOME/infernet-container-starter" || handle_error "Не удалось перейти в директорию проекта"
    
    echo -e "${BLUE}🚀 Развертывание контракта...${NC}"
    output=$(make deploy-contracts project=hello-world 2>&1)
    contract_address=$(echo "$output" | grep -oP 'Deployed SaysHello:  \K[0-9a-fA-Fx]+')

    if [ -z "$contract_address" ]; then
        handle_error "Не удалось извлечь адрес контракта"
    fi

    echo -e "${GREEN}✅ Контракт развернут по адресу: $contract_address${NC}"

    local config_file="$HOME/infernet-container-starter/deploy/config.json"
    jq --arg addr "$contract_address" '.containers[0].allowed_addresses = [$addr]' "$config_file" > tmp.json && mv tmp.json "$config_file"

    local solidity_file="$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"
    sed -i "s|SaysGM(.*);|SaysGM($contract_address);|" "$solidity_file"

    echo -e "${BLUE}🔄 Перезапуск Docker сервисов...${NC}"
    docker-compose down && docker-compose up -d

    echo -e "${BLUE}📞 Вызов контракта...${NC}"
    make call-contract project=hello-world

    echo -e "${GREEN}✅ Конфигурация обновлена и контракт вызван.${NC}"
}

restart_docker_services() {
  print_step "Перезапуск Docker сервисов"
  sleep 20
  docker restart infernet-anvil
  docker restart infernet-node
  docker restart hello-world
  docker restart deploy-node-1
  docker restart deploy-fluentbit-1
  docker restart deploy-redis-1
}

# Функция для остановки и удаления контейнеров
stop_and_remove_containers() {
  print_step "Остановка и удаление всех контейнеров"
  docker compose down
  echo -e "${GREEN}🚮 Контейнеры остановлены и удалены.${NC}"
}

# Функция для обработки каждого кошелька
process_wallet() {
  local wallet=$1
  local private_key=$2

  print_step "🔑 Работаем с кошельком: $wallet"

  #install_forge

  install_docker

  install_build_tools


  # Настройка репозитория
  setup_repository

  # Обновление конфигов с приватным ключом и кошельком
  update_config_files "$wallet" "$private_key"

  # Запуск Docker контейнеров
  docker compose up -d

  # Развертывание и обновление конфигурации
  deploy_and_update_config

  # Лог успешной обработки
  echo "$wallet обработан." >> $LOG_FILE

  # Остановка и удаление контейнеров
  stop_and_remove_containers

  # Удаление сессии screen с именем "ritual"
  screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
  echo -e "${GREEN}🧹 Сессия screen 'ritual' успешно удалена.${NC}"
}

# Основной цикл по кошелькам
main() {
      echo -e "${BRIGHT_GREEN}
    ╔════════════════════════════════════════════════╗
    ║   Добро пожаловать в SDS Ritual Node Installer ║
    ╚════════════════════════════════════════════════╝${NC}"

  print_step "Чтение конфигурационного файла с кошельками"

  # Чтение конфигурационного файла и обработка каждого кошелька
  while IFS=: read -r wallet private_key; do
    # Проверяем, что кошелек не пустой и еще не обработан
    if [[ -n "$wallet" && ! $(grep "$wallet" $LOG_FILE) ]]; then
      process_wallet "$wallet" "$private_key"
    else
      echo -e "${GREEN}Кошелек $wallet уже обработан. Пропуск...${NC}"
    fi
  done < "$CONFIG_FILE"
}

# Запуск основного процесса
main
