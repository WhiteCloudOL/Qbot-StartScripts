#!/bin/bash
#License: GNU GENERAL PUBLIC LICENSE Version 3
#Author: 清蒸云鸭
#Edited with Gemini
#Update: 2026-01-20

# =========================================================
# 1. 全局配置与变量
# =========================================================

CONFIG_FILE="$HOME/.maibot_config"
INSTALLATION_ACTIVE=false

# --- 颜色定义 ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GREY='\033[0;37m'
NC='\033[0m'

GITHUB_MIRRORS=(
    "https://gh-proxy.org"
    "https://hk.gh-proxy.org"
    "https://cdn.gh-proxy.org"
    "https://gh.llkk.cc"
    "https://github.moeyy.xyz"
)

# 更新测速目标文件
TEST_FILE_PATH="https://raw.githubusercontent.com/Mai-with-u/MaiBot/refs/heads/main/README.md"

# 临时存储用户选择的变量
USER_INSTALL_PATH=""
USER_INSTALL_MODE=""   # normal / clean
USER_VENV_MODE=""      # keep / recreate
USER_GH_PROXY=""
USER_PIP_DISPLAY=""    # UI显示用
USER_PIP_INDEX=""      # 实际配置
USER_PIP_HOST=""       # 实际配置
USER_NAPCAT_MODE="" 

# =========================================================
# 2. UI & 工具函数
# =========================================================

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 标题栏与状态栏绘制 ---
draw_header() {
    clear
    echo -e "${PURPLE}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}           ${WHITE}MaiBot 一键部署与管理脚本 ${CYAN}v1.6${NC}               ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC}                 ${WHITE}Copyright@清蒸云鸭${NC}                     ${PURPLE}│${NC}"
    echo -e "${PURPLE}└────────────────────────────────────────────────────────┘${NC}"
    
    # 状态栏 (面包屑导航) - 仅在安装流程中且已设置路径时显示
    if [[ "$INSTALLATION_ACTIVE" == "true" && -n "$USER_INSTALL_PATH" ]]; then
        echo -e "${WHITE} 配置预览:${NC}"
        echo -e " ${GREY}●${NC} 目录: ${CYAN}${USER_INSTALL_PATH}${NC}"
        
        # 安装模式
        if [[ -n "$USER_INSTALL_MODE" ]]; then
            local mode_str="保留数据更新"
            [[ "$USER_INSTALL_MODE" == "clean" ]] && mode_str="${RED}清空并全新安装${NC}"
            echo -e " ${GREY}●${NC} 模式: ${mode_str}"
        fi

        # 虚拟环境
        if [[ -n "$USER_VENV_MODE" && "$USER_INSTALL_MODE" != "clean" ]]; then
            local venv_str="保留旧环境"
            [[ "$USER_VENV_MODE" == "recreate" ]] && venv_str="${YELLOW}强制重建环境${NC}"
            echo -e " ${GREY}●${NC} 环境: ${venv_str}"
        fi

        # GitHub
        if [[ -n "$USER_GH_PROXY" ]]; then
            local gh_display="自定义/自动"
            [[ "$USER_GH_PROXY" == "https://github.com" ]] && gh_display="官方直连"
            if [[ "$gh_display" == "官方直连" ]]; then
                echo -e " ${GREY}●${NC} Git : ${CYAN}${gh_display}${NC}"
            else
                echo -e " ${GREY}●${NC} Git : ${CYAN}${USER_GH_PROXY}${NC}"
            fi
        fi
        
        # PyPI
        if [[ -n "$USER_PIP_DISPLAY" ]]; then
            echo -e " ${GREY}●${NC} PyPI: ${CYAN}${USER_PIP_DISPLAY}${NC}"
        fi

        # NapCat
        if [[ -n "$USER_NAPCAT_MODE" ]]; then
            local nc_str="暂不安装"
            [[ "$USER_NAPCAT_MODE" == "1" ]] && nc_str="Docker"
            [[ "$USER_NAPCAT_MODE" == "2" ]] && nc_str="Shell脚本"
            echo -e " ${GREY}●${NC} QQ端: ${CYAN}${nc_str}${NC}"
        fi
        echo -e "${PURPLE}──────────────────────────────────────────────────────────${NC}"
    else
        echo -e ""
    fi
}

# --- 分隔线 ---
draw_line() {
    echo -e "${PURPLE}──────────────────────────────────────────────────────────${NC}"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        if [[ -n "$MAI_PATH" ]]; then return 0; fi
    fi
    return 1
}

save_config() {
    local path="$1"
    echo "MAI_PATH=\"$path\"" > "$CONFIG_FILE"
}

check_screen_installed() {
    if ! command -v screen &> /dev/null; then return 1; fi
    return 0
}

# 增强版 Git Clone
git_clone_safe() {
    local url="$1"
    local dir="$2"
    
    # 目录存在处理逻辑
    if [[ -d "$dir" ]]; then
        if [[ "$USER_INSTALL_MODE" == "clean" ]]; then
            log_warning "清理旧目录: $dir"
            rm -rf "$dir"
        else
            log_info "检测到目录 ${CYAN}$dir${NC} 已存在，尝试更新..."
            cd "$dir" || return 1
            git pull
            if [ $? -eq 0 ]; then
                cd ..; return 0
            else
                log_error "更新失败。"
                cd ..
                echo -e "${YELLOW}是否删除旧文件夹并重新克隆？${NC}"
                read -p "请输入 (y/n): " re_choice
                if [[ "$re_choice" == "y" ]]; then rm -rf "$dir"; else return 1; fi
            fi
        fi
    fi

    log_info "正在克隆 ${CYAN}$dir${NC} (显示进度)..."
    git clone --depth 1 --progress "$url" "$dir"
    
    if [ $? -eq 0 ]; then
        log_success "$dir 克隆成功"
        return 0
    else
        log_error "克隆失败！请检查网络或更换加速源。"
        rm -rf "$dir"
        echo -e "1. 重试  2. 跳过  3. 退出"
        read -p "请选择: " retry_choice
        case $retry_choice in
            2) return 1 ;;
            3) exit 1 ;;
            *) ;; 
        esac
    fi
}

# 增强版 Docker Compose Up
docker_compose_safe() {
    local work_dir="$1"
    cd "$work_dir" || return 1
    while true; do
        log_info "正在启动 Docker 容器..."
        docker compose up -d
        if [ $? -eq 0 ]; then return 0; else
            log_error "容器启动失败！"
            echo -e "${YELLOW}尝试清理容器状态...${NC}"
            docker compose down 2>/dev/null
            read -p "1. 重试  2. 放弃 : " dc_choice
            if [[ "$dc_choice" == "2" ]]; then return 1; fi
        fi
    done
}

# Docker 安装函数
install_docker_safe() {
    while true; do
        log_info "调用 LinuxMirrors 脚本安装 Docker..."
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
        if command -v docker &> /dev/null; then log_success "Docker 安装成功！"; return 0; else
            log_error "Docker 安装检测失败。"
            read -p "1. 重试  2. 手动安装后继续  3. 退出 : " d_inst_choice
            case $d_inst_choice in 2) return 0 ;; 3) exit 1 ;; *) ;; esac
        fi
    done
}

# Docker 镜像源配置
configure_docker_mirror() {
    if ! command -v docker &> /dev/null; then return; fi
    echo -e "${BLUE}▶ Docker 镜像加速配置${NC}"
    echo -e "${GREEN}1.${NC} docker.1ms.run ${WHITE}(国内推荐)${NC}"
    echo -e "${GREEN}2.${NC} docker.xuanyuan.me ${WHITE}(国内推荐)${NC}"
    echo -e "${GREEN}3.${NC} 恢复官方源"
    echo -e "${GREEN}4.${NC} 保持不变"
    read -p "请选择 [1-4] (默认4): " mirror_choice
    mirror_choice=${mirror_choice:-4}
    if [[ "$mirror_choice" == "4" ]]; then return; fi

    local mirror_url=""
    case $mirror_choice in
        1) mirror_url="https://docker.1ms.run" ;;
        2) mirror_url="https://docker.xuanyuan.me" ;;
        3) mirror_url="OFFICIAL" ;;
        *) return ;;
    esac

    log_info "正在配置 Docker daemon..."
    local daemon_file="/etc/docker/daemon.json"
    mkdir -p /etc/docker
    if [[ "$mirror_url" == "OFFICIAL" ]]; then
        if [[ -f "$daemon_file" ]]; then echo "{}" > "$daemon_file"; fi
    else
        echo "{\"registry-mirrors\": [\"$mirror_url\"]}" > "$daemon_file"
    fi
    systemctl restart docker
}

# =========================================================
# 3. 配置流程模块
# =========================================================

configure_install_path() {
    draw_header
    echo -e "${BLUE}▶ 1/5 安装目录配置${NC}"
    local default_path="$HOME/maimai"
    load_config
    if [[ -n "$MAI_PATH" ]]; then default_path="$MAI_PATH"; fi
    echo -e "上次/默认安装位置: ${CYAN}$default_path${NC}"
    read -p "请输入安装路径 (回车使用默认): " user_path
    if [[ -z "$user_path" ]]; then USER_INSTALL_PATH="$default_path"; else USER_INSTALL_PATH="${user_path/#\~/$HOME}"; fi
    mkdir -p "$USER_INSTALL_PATH"
}

step_install_mode() {
    draw_header
    echo -e "${BLUE}▶ 2/5 选择安装模式${NC}"
    if [[ ! -d "$USER_INSTALL_PATH/MaiBot" ]]; then
        USER_INSTALL_MODE="normal"; USER_VENV_MODE="recreate"; return
    fi
    echo -e "${GREEN}1.${NC} 正常更新/修复 ${WHITE}(保留配置文件与数据)${NC}"
    echo -e "${RED}2. 全新安装 ${NC}${YELLOW}(⚠️  删除目录下所有内容，配置不保留)${NC}"
    read -p "请选择 [1-2] (默认1): " mode_choice
    case ${mode_choice:-1} in
        2) 
            echo -e "${RED}严重警告：此操作将清空 $USER_INSTALL_PATH 下的所有数据！${NC}"
            read -p "确认执行? 输入 'YES' 继续: " confirm_clean
            if [[ "$confirm_clean" == "YES" ]]; then USER_INSTALL_MODE="clean"; USER_VENV_MODE="recreate"; else USER_INSTALL_MODE="normal"; fi
            ;;
        *) USER_INSTALL_MODE="normal" ;;
    esac
}

step_venv_mode() {
    if [[ "$USER_INSTALL_MODE" == "clean" ]]; then return; fi
    draw_header
    echo -e "${BLUE}▶ 3/5 Python 环境处理${NC}"
    echo -e "${GREEN}1.${NC} 保留现有环境 ${WHITE}(速度快，适合小更新)${NC}"
    echo -e "${YELLOW}2.${NC} 删除并重建环境 ${WHITE}(推荐，彻底解决依赖冲突)${NC}"
    read -p "请选择 [1-2] (默认1): " venv_choice
    case ${venv_choice:-1} in 2) USER_VENV_MODE="recreate" ;; *) USER_VENV_MODE="keep" ;; esac
}

configure_github() {
    draw_header
    echo -e "${BLUE}▶ 4/5 GitHub 线路配置${NC}"
    
    run_speedtest() {
        echo -e "${YELLOW}正在并行测速，请稍候...${NC}"
        local temp_dir=$(mktemp -d)
        local mirrors=("https://github.com" "${GITHUB_MIRRORS[@]}")
        
        # 并行执行测速
        for mirror in "${mirrors[@]}"; do
            (
                local test_url
                [[ "$mirror" == "https://github.com" ]] && test_url="$TEST_FILE_PATH" || test_url="${mirror}/${TEST_FILE_PATH}"
                
                # 设置超时3秒
                local time_cost
                time_cost=$(curl -sL -o /dev/null --max-time 3 -w "%{time_total}" "$test_url")
                local exit_code=$?
                
                if [[ $exit_code -eq 0 ]]; then
                    # awk 计算毫秒取整
                    local ms=$(awk -v t="$time_cost" 'BEGIN {printf "%.0f", t*1000}')
                    echo "$ms $mirror" >> "$temp_dir/results"
                else
                    # 9999 代表超时
                    echo "9999 $mirror" >> "$temp_dir/results"
                fi
            ) &
        done
        wait # 等待所有后台任务完成
        
        # 显示结果
        echo -e "\n   延迟(ms) | 线路地址"
        echo -e "------------|----------------------------------"
        
        local best_mirror=""
        local best_ms=9999

        if [[ -f "$temp_dir/results" ]]; then
            # 排序
            sort -n "$temp_dir/results" > "$temp_dir/sorted"
            
            while read line; do
                local ms=$(echo $line | awk '{print $1}')
                local url=$(echo $line | awk '{print $2}')
                
                if [[ "$ms" == "9999" ]]; then
                    echo -e " ${RED}超时/失败${NC}| $url"
                else
                    # 设置最佳镜像 (取第一个非超时的)
                    if [[ -z "$best_mirror" ]]; then
                        best_mirror=$url
                        best_ms=$ms
                    fi
                    
                    local color=$GREEN
                    if [ "$ms" -gt 800 ]; then color=$YELLOW; fi
                    if [ "$ms" -gt 1500 ]; then color=$RED; fi
                    echo -e " ${color}${ms}ms${NC}\t| $url"
                fi
            done < "$temp_dir/sorted"
        fi

        if [[ -n "$best_mirror" ]]; then
            USER_GH_PROXY="$best_mirror"
            echo -e "\n自动选择: ${CYAN}$best_mirror${NC} (延迟: ${best_ms}ms)"
        else
            USER_GH_PROXY="https://gh-proxy.org"
            echo -e "\n${RED}测速全失败，使用默认代理。${NC}"
        fi
        
        rm -rf "$temp_dir"
        sleep 2
    }

    echo -e "${GREEN}1.${NC} 自动测速选择最佳线路 ${WHITE}(并行极速)${NC}"
    echo -e "${GREEN}2.${NC} 手动选择线路"
    echo -e "${GREEN}3.${NC} 官方直连"
    read -p "选择 [1-3] (默认1): " gh_choice
    case ${gh_choice:-1} in
        2) select mirror in "${GITHUB_MIRRORS[@]}"; do USER_GH_PROXY="$mirror"; break; done ;;
        3) USER_GH_PROXY="https://github.com" ;;
        *) run_speedtest ;;
    esac
}

configure_pip() {
    draw_header
    echo -e "${BLUE}▶ 5/5 Pip 镜像源配置${NC}"
    echo -e "${GREEN}1.${NC} 保持现状/系统默认"
    echo -e "${GREEN}2.${NC} 阿里云"
    echo -e "${GREEN}3.${NC} 清华大学"
    echo -e "${GREEN}4.${NC} 官方源"
    read -p "选择 [1-4] (默认1): " pip_choice
    case ${pip_choice:-1} in
        2) USER_PIP_DISPLAY="阿里云"; USER_PIP_INDEX="https://mirrors.aliyun.com/pypi/simple/"; USER_PIP_HOST="mirrors.aliyun.com" ;;
        3) USER_PIP_DISPLAY="清华大学"; USER_PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"; USER_PIP_HOST="pypi.tuna.tsinghua.edu.cn" ;;
        4) USER_PIP_DISPLAY="官方源"; USER_PIP_INDEX="https://pypi.org/simple"; USER_PIP_HOST="pypi.org" ;;
        *) USER_PIP_DISPLAY="系统默认"; USER_PIP_INDEX=""; USER_PIP_HOST="" ;;
    esac
}

configure_napcat_selection() {
    draw_header
    echo -e "${BLUE}▶ 附加: NapCat (NTQQ) 部署选项${NC}"
    echo -e "${GREEN}1.${NC} Docker 部署 ${WHITE}(推荐)${NC}"
    echo -e "${GREEN}2.${NC} Shell 脚本部署"
    echo -e "${GREEN}3.${NC} 暂不安装"
    read -p "请选择 [1-3] (默认1): " nc_choice
    USER_NAPCAT_MODE=${nc_choice:-1}
}

# =========================================================
# 4. 执行安装模块
# =========================================================

run_install() {
    draw_header
    echo -e "${YELLOW}请确认上方配置预览无误。${NC}"
    if [[ "$USER_INSTALL_MODE" == "clean" ]]; then
        echo -e "${RED}警告: 将执行全新安装，目标目录数据将被清除！${NC}"
    fi
    read -p "确认无误开始安装? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi

    echo -e "\n${BLUE}▶ 开始安装系统依赖...${NC}"
    if command -v apt &> /dev/null; then
        sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq
        sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq python3-dev python3-venv python3-pip build-essential git wget curl screen jq
    elif command -v yum &> /dev/null; then
         sudo yum install -y python3-devel git wget curl screen jq
    fi

    # 目录清理
    if [[ "$USER_INSTALL_MODE" == "clean" && -n "$USER_INSTALL_PATH" ]]; then
        if [[ "$USER_INSTALL_PATH" != "/" && "$USER_INSTALL_PATH" != "$HOME" ]]; then
            log_warning "执行清理..."
            rm -rf "${USER_INSTALL_PATH:?}/"*
        fi
    fi

    cd "$USER_INSTALL_PATH" || exit 1
    
    get_url() {
        local repo=$1
        if [[ "$USER_GH_PROXY" == "https://github.com" ]]; then echo "https://github.com/$repo.git"; else echo "${USER_GH_PROXY}/https://github.com/${repo}.git"; fi
    }

    echo -e "\n${BLUE}▶ 下载/更新组件...${NC}"
    git_clone_safe "$(get_url 'MaiM-with-u/MaiBot')" "MaiBot"
    git_clone_safe "$(get_url 'MaiM-with-u/MaiBot-Napcat-Adapter')" "MaiBot-Napcat-Adapter"
    
    echo -e "\n${BLUE}▶ 初始化配置文件...${NC}"
    copy_conf() {
        if [[ ! -f "$2" ]] && [[ -f "$1" ]]; then
            mkdir -p "$(dirname "$2")"
            cp "$1" "$2"
            echo " - 生成配置: $2"
            return 0
        fi
        return 1
    }
    
    copy_conf "MaiBot/template/bot_config_template.toml" "MaiBot/config/bot_config.toml"
    copy_conf "MaiBot/template/model_config_template.toml" "MaiBot/config/model_config.toml"
    if copy_conf "MaiBot/template/template.env" "MaiBot/.env"; then
        sed -i 's/WEBUI_HOST=127.0.0.1/WEBUI_HOST=0.0.0.0/g' "MaiBot/.env"
    fi
    copy_conf "MaiBot-Napcat-Adapter/template/template_config.toml" "MaiBot-Napcat-Adapter/config.toml"

    echo -e "\n${BLUE}▶ 配置 Python 环境...${NC}"
    if [[ "$USER_VENV_MODE" == "recreate" && -d "venv" ]]; then
        log_warning "移除旧虚拟环境..."
        rm -rf venv
    fi
    if [[ ! -d "venv" ]]; then 
        echo " - 创建虚拟环境 venv..."
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    if [[ -n "$USER_PIP_INDEX" ]]; then
        mkdir -p ~/.pip
        echo -e "[global]\nindex-url = $USER_PIP_INDEX\ntrusted-host = $USER_PIP_HOST" > ~/.pip/pip.conf
    fi
    
    echo " - 更新 pip..."
    pip install --upgrade pip
    
    if [[ -f "MaiBot/requirements.txt" ]]; then pip install -r MaiBot/requirements.txt; fi
    if [[ -f "MaiBot-Napcat-Adapter/requirements.txt" ]]; then pip install -r MaiBot-Napcat-Adapter/requirements.txt; fi

    save_config "$USER_INSTALL_PATH"
    log_success "MaiBot 本体部署完成！"
    execute_napcat_install
    
    draw_line
    echo -e "${GREEN}所有任务执行完毕！${NC}"
    echo -e "请使用主菜单的 [管理 MaiBot] 或 [管理 NapCat] 来启动服务。"
    read -p "按回车返回主菜单..."
}

execute_napcat_install() {
    if [[ "$USER_NAPCAT_MODE" == "3" ]]; then return; fi
    echo -e "\n${BLUE}▶ 部署 NapCatQQ...${NC}"
    local NAPCAT_DIR="$USER_INSTALL_PATH/NapCat"

    case $USER_NAPCAT_MODE in
        1)
            if ! command -v docker &> /dev/null; then
                log_warning "未检测到 Docker，准备安装..."
                install_docker_safe
            fi
            configure_docker_mirror
            mkdir -p "$NAPCAT_DIR"
            log_info "生成 docker-compose.yml..."
            # 移除 WEBUI_TOKEN，修改 UID/GID
            cat > "$NAPCAT_DIR/docker-compose.yml" <<EOF
services:
  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat
    restart: always
    environment:
      - NAPCAT_UID=\${NAPCAT_UID:-1000}
      - NAPCAT_GID=\${NAPCAT_GID:-1000}
    volumes:
      - ./config:/app/napcat/config
      - ./qq_config:/app/.config/QQ
    network_mode: "host"
EOF
            docker_compose_safe "$NAPCAT_DIR"
            if [ $? -eq 0 ]; then log_success "NapCat (Docker) 部署成功！"; fi
            ;;
        2)
            cd "$USER_INSTALL_PATH" || return
            while true; do
                curl -o napcat.sh https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh && bash napcat.sh --docker n --cli y
                if [ $? -eq 0 ]; then break; fi
                log_error "脚本执行出错，是否重试? (y/n)"
                read -p "> " sh_retry
                if [[ "$sh_retry" != "y" ]]; then break; fi
            done
            ;;
    esac
}

# =========================================================
# 5. 配置与访问菜单 (合并修改版)
# =========================================================

get_ip() {
    local ip=$(curl -s4 ifconfig.me)
    if [[ -z "$ip" ]]; then ip="127.0.0.1"; fi
    echo "$ip"
}

manage_config_access_menu() {
    if ! load_config; then log_error "未找到配置"; return; fi
    local MAIBOT_DIR="$MAI_PATH/MaiBot"
    local ADAPTER_DIR="$MAI_PATH/MaiBot-Napcat-Adapter"
    local NAPCAT_DIR="$MAI_PATH/NapCat"
    local PUBLIC_IP=$(get_ip)

    while true; do
        draw_header
        echo -e "${BLUE}▶ 配置与访问${NC}"
        echo -e " 公网IP: ${CYAN}${PUBLIC_IP}${NC}"
        draw_line
        # 合并后的选项1
        echo -e "${GREEN}1.${NC} 查看 WebUI 访问信息 (MaiBot & NapCat)"
        echo -e "${GREEN}2.${NC} 修改 Adapter 配置 (黑白名单管理)"
        draw_line
        echo -e "${WHITE}0.${NC} 返回上一级"
        echo -e ""
        read -p " 请选择: " opt
        
        case $opt in
            1) 
                draw_header
                echo -e "${BLUE}▶ WebUI 访问汇总${NC}"
                
                # --- Part A: MaiBot ---
                echo -e "\n${PURPLE}● MaiBot WebUI${NC}"
                if [[ -f "$MAIBOT_DIR/.env" ]] && [[ -f "$MAIBOT_DIR/data/webui.json" ]]; then
                    local port=$(grep "WEBUI_PORT" "$MAIBOT_DIR/.env" | cut -d'=' -f2 | tr -d ' "')
                    local token=""
                    if command -v jq &>/dev/null; then
                        token=$(jq -r '.access_token' "$MAIBOT_DIR/data/webui.json")
                    else
                         token=$(python3 -c "import json; print(json.load(open('$MAIBOT_DIR/data/webui.json'))['access_token'])" 2>/dev/null)
                    fi
                    
                    if [[ -z "$port" ]]; then port="8001 (默认)"; fi
                    echo -e "  访问地址: ${CYAN}http://${PUBLIC_IP}:${port}${NC}"
                    echo -e "  访问密钥: ${YELLOW}${token}${NC}"
                else
                    echo -e "  ${YELLOW}未找到 MaiBot 配置文件 (可能未启动过本体)${NC}"
                fi
                
                draw_line 

                # --- Part B: NapCat ---
                echo -e "${PURPLE}● NapCat WebUI (Docker)${NC}"
                local nc_conf="$NAPCAT_DIR/config/webui.json"
                if [[ -f "$nc_conf" ]]; then
                    local nc_port=""
                    local nc_token=""
                    if command -v jq &>/dev/null; then
                        nc_port=$(jq -r '.port' "$nc_conf")
                        nc_token=$(jq -r '.token' "$nc_conf")
                    else
                        nc_port=$(python3 -c "import json; print(json.load(open('$nc_conf'))['port'])" 2>/dev/null)
                        nc_token=$(python3 -c "import json; print(json.load(open('$nc_conf'))['token'])" 2>/dev/null)
                    fi
                    
                    echo -e "  访问地址: ${CYAN}http://${PUBLIC_IP}:${nc_port}${NC}"
                    echo -e "  访问密钥: ${YELLOW}${nc_token}${NC}"
                else
                    echo -e "  ${YELLOW}未找到 NapCat 配置文件 (未安装或未启动)${NC}"
                fi
                
                echo ""
                read -p "按回车返回..."
                ;;
            2)
                modify_adapter_config "$ADAPTER_DIR/config.toml"
                ;;
            0) return ;;
        esac
    done
}

modify_adapter_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then log_error "找不到配置文件: $config_file"; sleep 2; return; fi

    while true; do
        draw_header
        echo -e "${BLUE}▶ Adapter 名单管理${NC}"
        # --- 读取部分保持不变 ---
        python3 - <<EOF
import re
try:
    with open("$config_file", 'r', encoding='utf-8') as f:
        content = f.read()
    def find_list(key):
        match = re.search(r'^\s*' + key + r'\s*=\s*\[(.*?)\]', content, re.MULTILINE | re.DOTALL)
        return match.group(1).replace('\n', '').strip() if match else "Not Found"
    def find_val(key):
        match = re.search(r'^\s*' + key + r'\s*=\s*"(.*?)"', content, re.MULTILINE)
        return match.group(1) if match else "Unknown"

    print(f" 1. 群聊模式: \033[1;36m{find_val('group_list_type')}\033[0m")
    print(f"    群聊列表: \033[1;33m[{find_list('group_list')}]\033[0m")
    print(f" 2. 私聊模式: \033[1;36m{find_val('private_list_type')}\033[0m")
    print(f"    私聊列表: \033[1;33m[{find_list('private_list')}]\033[0m")
except Exception as e:
    print(f"读取配置出错: {e}")
EOF
        draw_line
        echo -e "${GREEN}a.${NC} 添加群号到列表        ${RED}b.${NC} 从列表移除群号"
        echo -e "${GREEN}c.${NC} 添加QQ到私聊列表      ${RED}d.${NC} 从私聊列表移除QQ"
        echo -e "${YELLOW}t.${NC} 切换名单类型 (白名单/黑名单)"
        echo -e "${WHITE}0.${NC} 返回"
        echo -e ""
        read -p " 请选择操作: " m_opt
        if [[ "$m_opt" == "0" ]]; then return; fi

        local py_script=""
        local input_val=""
        case $m_opt in
            a|b|c|d)
                read -p "请输入号码: " input_val
                if [[ -z "$input_val" ]]; then continue; fi
                ;;
        esac

        case $m_opt in
            a) py_script="key='group_list'; action='add'; val=$input_val" ;;
            b) py_script="key='group_list'; action='del'; val=$input_val" ;;
            c) py_script="key='private_list'; action='add'; val=$input_val" ;;
            d) py_script="key='private_list'; action='del'; val=$input_val" ;;
            t) 
                echo -e "1. 修改群聊模式 (group)  2. 修改私聊模式 (private)"
                read -p "选择: " t_type
                if [[ "$t_type" == "1" ]]; then py_script="key='group_list_type'; action='toggle'"; 
                elif [[ "$t_type" == "2" ]]; then py_script="key='private_list_type'; action='toggle'"; 
                else continue; fi
                ;;
            *) continue ;;
        esac

        # --- 写入部分（已修复错误） ---
        python3 - <<EOF
import re
import sys
file_path = "$config_file"
$py_script
try:
    with open(file_path, 'r', encoding='utf-8') as f: content = f.read()
    if action == 'toggle':
        pattern = r'(' + key + r'\s*=\s*")(\w+)(")'
        def switch(match):
            curr = match.group(2)
            new_val = 'blacklist' if curr == 'whitelist' else 'whitelist'
            print(f"模式已切换: {curr} -> {new_val}")
            return f"{match.group(1)}{new_val}{match.group(3)}"
        new_content = re.sub(pattern, switch, content, count=1)
    else:
        # --- 修复点：删除了末尾多余的 parameters 和右括号 ---
        pattern = r'(' + key + r'\s*=\s*\[)(.*?)(\])'
        match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
        if match:
            nums = re.findall(r'\d+', match.group(2))
            target = str(val)
            if action == 'add':
                if target in nums: print(f"号码 {target} 已存在。")
                else: nums.append(target); print(f"已添加 {target}")
            elif action == 'del':
                if target in nums: nums = [n for n in nums if n != target]; print(f"已移除 {target}")
                else: print(f"号码 {target} 不在列表中。")
            new_list_str = ", ".join(nums) # 加个空格美观一点
            new_content = content.replace(match.group(0), f"{match.group(1)}{new_list_str}{match.group(3)}")
        else: 
            print("未找到配置项，操作中止")
            sys.exit(0)
    with open(file_path, 'w', encoding='utf-8') as f: f.write(new_content)
except Exception as e: print(f"修改失败: {e}")
EOF
        read -p "按回车继续..."
    done
}

# =========================================================
# 6. 服务管理菜单
# =========================================================

manage_napcat_menu() {
    local NAPCAT_DIR="$MAI_PATH/NapCat"
    check_docker_status() {
        if command -v docker &> /dev/null; then
            if docker ps --format '{{.Names}}' | grep -q "napcat"; then
                echo -e " NapCat 状态:   ${GREEN}● 运行中 (Docker)${NC}"
            else
                echo -e " NapCat 状态:   ${RED}○ 未运行 / 停止${NC}"
            fi
        else
            echo -e " NapCat 状态:   ${YELLOW}未知 (未安装Docker)${NC}"
        fi
    }

    while true; do
        draw_header
        echo -e "${BLUE}▶ NapCat 管理面板${NC}"
        echo -e " 目录: ${CYAN}$NAPCAT_DIR${NC}"
        check_docker_status
        draw_line
        echo -e "${GREEN}1.${NC} 启动 NapCat"
        echo -e "${GREEN}2.${NC} 停止 NapCat"
        echo -e "${GREEN}3.${NC} 重启 NapCat"
        echo -e "${GREEN}4.${NC} 查看实时日志 ${WHITE}(Ctrl+C 退出)${NC}"
        draw_line
        echo -e "${YELLOW}5.${NC} 重建容器 ${WHITE}(更新/修复，保留配置)${NC}"
        echo -e "${RED}6. 移除容器 ${WHITE}(删除容器与配置，慎用！)${NC}"
        draw_line
        echo -e "${WHITE}0.${NC} 返回上一级"
        echo -e ""
        
        if [[ ! -d "$NAPCAT_DIR" ]]; then
            echo -e "${YELLOW}提示: 未检测到 NapCat 目录，此面板仅支持 Docker 版管理。${NC}"
        fi

        read -p " 请选择: " nc_opt
        if [[ "$nc_opt" =~ [1-5] ]]; then
            if [[ -d "$NAPCAT_DIR" ]]; then cd "$NAPCAT_DIR" || return; else log_error "找不到目录"; sleep 2; continue; fi
        fi

        case $nc_opt in
            1) docker compose up -d; sleep 1 ;;
            2) docker compose stop; sleep 1 ;;
            3) docker compose restart; sleep 1 ;;
            4) docker compose logs -f --tail=100 ;;
            5)
                echo -e "${YELLOW}警告: 即将停止并移除旧容器，拉取新镜像并重新启动。${NC}"
                read -p "确认执行? (y/n): " rebuild_confirm
                if [[ "$rebuild_confirm" == "y" ]]; then
                    docker compose down; docker compose pull; docker compose up -d
                    log_success "重建完成！"
                fi; sleep 2 ;;
            6)
                echo -e "${RED}严重警告: 此操作将删除 NapCat 容器及所有数据！${NC}"
                read -p "请输入 'DELETE' 确认删除: " del_confirm
                if [[ "$del_confirm" == "DELETE" ]]; then
                    if [[ -d "$NAPCAT_DIR" ]]; then cd "$NAPCAT_DIR"; docker compose down 2>/dev/null; cd ..; rm -rf "$NAPCAT_DIR"; log_success "已移除。"; fi
                fi; sleep 2 ;;
            0) return ;;
        esac
        if [[ "$nc_opt" =~ [1-3] ]]; then read -p "操作完成，按回车继续..."; fi
    done
}

manage_maibot_menu() {
    if ! load_config; then
        echo -e "${RED}未找到安装记录${NC}"; echo "请输入 MaiBot 的安装目录:"; read -p "> " manual_path
        if [[ -d "$manual_path" ]]; then save_config "$manual_path"; load_config; else log_error "目录不存在"; return; fi
    fi
    if ! check_screen_installed; then log_error "请先安装 screen"; return; fi

    local MAIBOT_DIR="$MAI_PATH/MaiBot"
    local ADAPTER_DIR="$MAI_PATH/MaiBot-Napcat-Adapter"
    local TTS_ADAPTER_DIR="$MAI_PATH/maimbot_tts_adapter"
    local VENV_PATH="$MAI_PATH/venv/bin/activate"

    start_py_service() {
        local name="$1"; local screen_name="$2"; local dir="$3"; local script="$4"
        if [[ ! -d "$dir" ]]; then log_warning "$name 目录不存在"; return; fi
        
        if [[ "$name" == "MaiBot" ]]; then
             echo -e "${YELLOW}⚠️  启动提示 ⚠️${NC}"
             echo -e "如果是首次启动 MaiBot，你需要同意 ${CYAN}用户协议(EULA)${NC}。"
             echo -e "1. 正常后台启动 (已同意过)"
             echo -e "2. 启动并进入控制台 (首次运行选这个)"
             read -p "请选择 [1/2]: " run_mode
             cd "$dir" || return
             screen -list | grep -q "$screen_name" && screen -S "$screen_name" -X quit
             screen -dmS "$screen_name" bash -c "source '$VENV_PATH'; echo -e '${GREEN}$name 启动中...${NC}'; python3 $script; echo -e '${RED}$name 已停止/崩溃。${NC}'; exec bash"
             sleep 1
             if [[ "$run_mode" == "2" ]]; then
                 echo -e "${GREEN}即将进入控制台... 按 Ctrl+A 然后 D 退出${NC}"
                 read -p "按回车立即进入..." 
                 screen -r "$screen_name"
             else log_success "$name 已在后台启动"; fi
             return
        fi

        cd "$dir" || return
        screen -list | grep -q "$screen_name" && screen -S "$screen_name" -X quit
        echo -e "${BLUE}启动 $name...${NC}"
        screen -dmS "$screen_name" bash -c "source '$VENV_PATH'; echo -e '${GREEN}$name 启动中...${NC}'; python3 $script; echo -e '${RED}$name 已停止/崩溃。${NC}'; exec bash"
        sleep 1
    }

    stop_py_service() {
        local name="$1"; local screen_name="$2"
        if screen -list | grep -q "$screen_name"; then screen -S "$screen_name" -X quit; log_success "已停止 $name"; else echo -e "$name 未运行"; fi
    }

    check_maibot_status() {
        local services=("mai-main:MaiBot(本体)" "mai-adapter:Adapter(适配器)" "mai-tts:TTS(语音)")
        for s in "${services[@]}"; do
            local screen_name=${s%%:*}; local display_name=${s##*:}
            if screen -list | grep -q "$screen_name"; then echo -e " $display_name:\t${GREEN}● 运行中${NC}"; else echo -e " $display_name:\t${RED}○ 未运行${NC}"; fi
        done
    }

    while true; do
        draw_header
        echo -e "${BLUE}▶ MaiBot 核心管理${NC}"
        check_maibot_status
        draw_line
        echo -e "${GREEN}1.${NC} 一键开启 ${WHITE}(Bot + Adapter)${NC}"
        echo -e "${GREEN}2.${NC} 一键停止 ${WHITE}(所有服务)${NC}"
        draw_line
        echo -e "${CYAN}3.${NC} 开启 MaiBot 本体      ${CYAN}4.${NC} 停止 MaiBot 本体"
        echo -e "${CYAN}5.${NC} 开启 Adapter 适配器   ${CYAN}6.${NC} 停止 Adapter 适配器"
        draw_line
        echo -e "${YELLOW}9.${NC} 进入 Screen 控制台 ${WHITE}(查看报错)${NC}"
        echo -e "${WHITE}0.${NC} 返回主菜单"
        echo -e ""
        read -p " 请选择: " m_choice
        case $m_choice in
            1) start_py_service "MaiBot" "mai-main" "$MAIBOT_DIR" "bot.py"; start_py_service "Adapter" "mai-adapter" "$ADAPTER_DIR" "main.py"; if [[ -d "$TTS_ADAPTER_DIR" ]]; then start_py_service "TTS" "mai-tts" "$TTS_ADAPTER_DIR" "main.py"; fi ;;
            2) stop_py_service "MaiBot" "mai-main"; stop_py_service "Adapter" "mai-adapter"; stop_py_service "TTS" "mai-tts" ;;
            3) start_py_service "MaiBot" "mai-main" "$MAIBOT_DIR" "bot.py" ;;
            4) stop_py_service "MaiBot" "mai-main" ;;
            5) start_py_service "Adapter" "mai-adapter" "$ADAPTER_DIR" "main.py" ;;
            6) stop_py_service "Adapter" "mai-adapter" ;;
            9) echo -e "a. MaiBot\nb. Adapter"; read -p "选择窗口: " v; if [[ "$v" == "a" ]]; then screen -r "mai-main"; elif [[ "$v" == "b" ]]; then screen -r "mai-adapter"; fi ;;
            0) return ;;
        esac
        if [[ "$m_choice" != "9" && "$m_choice" != "0" ]]; then read -p "操作已执行，按回车继续..."; fi
    done
}




# =========================================================
# 7. LPMM知识库菜单
# =========================================================

manage_lpmm_menu() {
    # 加载配置，获取安装路径
    if ! load_config; then
        log_error "未找到安装配置，请先执行安装（主菜单选项1）"
        read -p "按回车返回主菜单..."
        return
    fi

    local MAIBOT_DIR="$MAI_PATH/MaiBot"
    local DATA_DIR="$MAIBOT_DIR/data"
    local RAW_DIR="$DATA_DIR/lpmm_raw_data"
    local OPENIE_DIR="$DATA_DIR/openie"
    local VENV_PATH="$MAI_PATH/venv/bin/activate"
    local SCRIPT_INFO="$MAIBOT_DIR/scripts/info_extraction.py"
    local SCRIPT_IMPORT="$MAIBOT_DIR/scripts/import_openie.py"

    # 检查必要目录和脚本是否存在
    if [[ ! -d "$MAIBOT_DIR" ]]; then
        log_error "MaiBot 目录不存在: $MAIBOT_DIR"
        read -p "按回车返回..."
        return
    fi

    if [[ ! -f "$SCRIPT_INFO" ]]; then
        log_warning "未找到 info_extraction.py，可能版本不完整"
    fi
    if [[ ! -f "$SCRIPT_IMPORT" ]]; then
        log_warning "未找到 import_openie.py，可能版本不完整"
    fi

    # 检查 screen 是否安装
    local SCREEN_AVAILABLE=false
    if command -v screen &>/dev/null; then
        SCREEN_AVAILABLE=true
    else
        log_warning "未安装 screen，后台运行功能无法使用"
    fi

    while true; do
        draw_header
        echo -e "${BLUE}▶ LPMM 知识库管理${NC}"
        echo -e " 数据目录: ${CYAN}$DATA_DIR${NC}"

        # 后台任务状态显示
        local info_status import_status
        if [[ "$SCREEN_AVAILABLE" == true ]]; then
            if screen -list | grep -q "mai-lpmm-info"; then
                info_status="${GREEN}● 运行中${NC}"
            else
                info_status="${RED}○ 未运行${NC}"
            fi
            if screen -list | grep -q "mai-lpmm-import"; then
                import_status="${GREEN}● 运行中${NC}"
            else
                import_status="${RED}○ 未运行${NC}"
            fi
        else
            info_status="${YELLOW}不可用${NC}"
            import_status="${YELLOW}不可用${NC}"
        fi
        echo -e " 文本分割与实体提取: ${info_status}"
        echo -e " 知识库导入: ${import_status}"

        draw_line
        echo -e "${GREEN}1.${NC} 初始化LPMM知识库 ${WHITE}(创建目录结构)${NC}"
        echo -e "${GREEN}2.${NC} 文本分割与实体提取 ${WHITE}(前台运行)${NC}"
        echo -e "${GREEN}3.${NC} 文本分割与实体提取 ${WHITE}(后台运行 - screen)${NC}"
        echo -e "${RED}4.${NC} 关闭后台文本分割与实体提取"
        draw_line
        echo -e "${GREEN}5.${NC} 导入LPMM知识库 ${WHITE}(前台运行)${NC}"
        echo -e "${GREEN}6.${NC} 导入LPMM知识库 ${WHITE}(后台运行 - screen)${NC}"
        echo -e "${RED}7.${NC} 关闭后台LPMM知识库导入"
        draw_line
        echo -e "${WHITE}0.${NC} 返回主菜单"
        echo -e ""
        read -p " 请选择: " lpmm_opt

        case $lpmm_opt in
            1)
                draw_header
                echo -e "${BLUE}▶ 初始化LPMM知识库目录${NC}"
                mkdir -p "$RAW_DIR" "$OPENIE_DIR"
                log_success "目录创建完成"
                echo -e "请将知识库 ${YELLOW}txt文件${NC} 放入: ${CYAN}$RAW_DIR${NC}"
                echo -e "将已经提取好的 ${YELLOW}openie文件${NC} 放入: ${CYAN}$OPENIE_DIR${NC}"
                echo -e "${WHITE}提示：${NC}需要先进行文本分割与实体提取（选项2/3），再导入LPMM知识库（选项5/6）"
                read -p "按回车继续..."
                ;;
            2)
                if [[ ! -f "$SCRIPT_INFO" ]]; then
                    log_error "脚本文件不存在: $SCRIPT_INFO"
                    read -p "按回车继续..."
                    continue
                fi
                draw_header
                echo -e "${BLUE}▶ 文本分割与实体提取 (前台)${NC}"
                echo -e "${YELLOW}注意：此过程可能耗时较长，请勿关闭终端窗口！${NC}"
                echo -e "正在激活虚拟环境并运行脚本...\n"
                bash -c "source '$VENV_PATH' && python '$SCRIPT_INFO'"
                echo -e "\n${GREEN}脚本执行完毕。${NC}"
                read -p "按回车继续..."
                ;;
            3)
                if [[ "$SCREEN_AVAILABLE" == false ]]; then
                    log_error "screen 未安装，无法使用后台功能"
                    read -p "按回车继续..."
                    continue
                fi
                if [[ ! -f "$SCRIPT_INFO" ]]; then
                    log_error "脚本文件不存在: $SCRIPT_INFO"
                    read -p "按回车继续..."
                    continue
                fi
                draw_header
                echo -e "${BLUE}▶ 文本分割与实体提取 (后台)${NC}"
                if screen -list | grep -q "mai-lpmm-info"; then
                    echo -e "${YELLOW}后台任务已存在，会话名: mai-lpmm-info${NC}"
                    echo -e "1. 进入该会话查看 (screen -r)"
                    echo -e "2. 关闭现有并重新启动"
                    echo -e "3. 返回"
                    read -p "请选择 [1-3]: " exist_opt
                    case $exist_opt in
                        1)
                            echo -e "进入 screen 会话，退出请按 ${WHITE}Ctrl+A 然后 D${NC}"
                            sleep 1
                            screen -r mai-lpmm-info
                            ;;
                        2)
                            screen -S mai-lpmm-info -X quit 2>/dev/null
                            log_info "已关闭旧会话，重新启动..."
                            screen -dmS mai-lpmm-info bash -c "source '$VENV_PATH'; python '$SCRIPT_INFO'"
                            log_success "已在后台启动，会话名: mai-lpmm-info"
                            echo -e "查看进度: ${CYAN}screen -r mai-lpmm-info${NC}"
                            echo -e "退出 screen: ${WHITE}Ctrl+A 然后 D${NC}"
                            read -p "是否立即进入该 screen 会话？(y/n): " enter_now
                            if [[ "$enter_now" == "y" || "$enter_now" == "Y" ]]; then
                                screen -r mai-lpmm-info
                            fi
                            ;;
                        3) ;;
                    esac
                else
                    screen -dmS mai-lpmm-info bash -c "source '$VENV_PATH'; python '$SCRIPT_INFO'"
                    log_success "已在后台启动，会话名: mai-lpmm-info"
                    echo -e "查看进度: ${CYAN}screen -r mai-lpmm-info${NC}"
                    echo -e "退出 screen: ${WHITE}Ctrl+A 然后 D${NC}"
                    read -p "是否立即进入该 screen 会话？(y/n): " enter_now
                    if [[ "$enter_now" == "y" || "$enter_now" == "Y" ]]; then
                        screen -r mai-lpmm-info
                    fi
                fi
                read -p "按回车继续..."
                ;;
            4)
                draw_header
                echo -e "${BLUE}▶ 关闭后台文本分割与实体提取${NC}"
                if screen -list | grep -q "mai-lpmm-info"; then
                    screen -S mai-lpmm-info -X quit
                    log_success "已关闭会话 mai-lpmm-info"
                else
                    log_info "没有正在运行的后台任务 (mai-lpmm-info)"
                fi
                read -p "按回车继续..."
                ;;
            5)
                if [[ ! -f "$SCRIPT_IMPORT" ]]; then
                    log_error "脚本文件不存在: $SCRIPT_IMPORT"
                    read -p "按回车继续..."
                    continue
                fi
                draw_header
                echo -e "${BLUE}▶ 导入LPMM知识库 (前台)${NC}"
                echo -e "${YELLOW}注意：此过程可能耗时较长，请勿关闭终端窗口！${NC}"
                echo -e "正在激活虚拟环境并运行脚本...\n"
                bash -c "source '$VENV_PATH' && python '$SCRIPT_IMPORT'"
                echo -e "\n${GREEN}脚本执行完毕。${NC}"
                read -p "按回车继续..."
                ;;
            6)
                if [[ "$SCREEN_AVAILABLE" == false ]]; then
                    log_error "screen 未安装，无法使用后台功能"
                    read -p "按回车继续..."
                    continue
                fi
                if [[ ! -f "$SCRIPT_IMPORT" ]]; then
                    log_error "脚本文件不存在: $SCRIPT_IMPORT"
                    read -p "按回车继续..."
                    continue
                fi
                draw_header
                echo -e "${BLUE}▶ 导入LPMM知识库 (后台)${NC}"
                if screen -list | grep -q "mai-lpmm-import"; then
                    echo -e "${YELLOW}后台任务已存在，会话名: mai-lpmm-import${NC}"
                    echo -e "1. 进入该会话查看"
                    echo -e "2. 关闭现有并重新启动"
                    echo -e "3. 返回"
                    read -p "请选择 [1-3]: " exist_opt
                    case $exist_opt in
                        1)
                            echo -e "进入 screen 会话，退出请按 ${WHITE}Ctrl+A 然后 D${NC}"
                            sleep 1
                            screen -r mai-lpmm-import
                            ;;
                        2)
                            screen -S mai-lpmm-import -X quit 2>/dev/null
                            log_info "已关闭旧会话，重新启动..."
                            screen -dmS mai-lpmm-import bash -c "source '$VENV_PATH'; python '$SCRIPT_IMPORT'"
                            log_success "已在后台启动，会话名: mai-lpmm-import"
                            echo -e "查看进度: ${CYAN}screen -r mai-lpmm-import${NC}"
                            echo -e "退出 screen: ${WHITE}Ctrl+A 然后 D${NC}"
                            read -p "是否立即进入该 screen 会话？(y/n): " enter_now
                            if [[ "$enter_now" == "y" || "$enter_now" == "Y" ]]; then
                                screen -r mai-lpmm-import
                            fi
                            ;;
                        3) ;;
                    esac
                else
                    screen -dmS mai-lpmm-import bash -c "source '$VENV_PATH'; python '$SCRIPT_IMPORT'"
                    log_success "已在后台启动，会话名: mai-lpmm-import"
                    echo -e "查看进度: ${CYAN}screen -r mai-lpmm-import${NC}"
                    echo -e "退出 screen: ${WHITE}Ctrl+A 然后 D${NC}"
                    read -p "是否立即进入该 screen 会话？(y/n): " enter_now
                    if [[ "$enter_now" == "y" || "$enter_now" == "Y" ]]; then
                        screen -r mai-lpmm-import
                    fi
                fi
                read -p "按回车继续..."
                ;;
            7)
                draw_header
                echo -e "${BLUE}▶ 关闭后台LPMM知识库导入${NC}"
                if screen -list | grep -q "mai-lpmm-import"; then
                    screen -S mai-lpmm-import -X quit
                    log_success "已关闭会话 mai-lpmm-import"
                else
                    log_info "没有正在运行的后台任务 (mai-lpmm-import)"
                fi
                read -p "按回车继续..."
                ;;
            0)
                return
                ;;
            *)
                log_warning "无效选项"
                sleep 1
                ;;
        esac
    done
}

# =========================================================
# 8. 插件管理菜单
# =========================================================

manage_plugins_menu() {
    if ! load_config; then
        log_error "未找到安装配置，请先执行安装"
        read -p "按回车返回主菜单..."
        return
    fi

    local MAIBOT_DIR="$MAI_PATH/MaiBot"
    local PLUGINS_DIR="$MAIBOT_DIR/plugins"
    local VENV_PATH="$MAI_PATH/venv/bin/activate"

    if [[ ! -d "$MAIBOT_DIR" ]]; then
        log_error "MaiBot 目录不存在: $MAIBOT_DIR"
        read -p "按回车返回..."
        return
    fi

    mkdir -p "$PLUGINS_DIR"

    # 获取当前配置的 GitHub 加速源，如果未设置则进行选择
    get_github_proxy() {
        if [[ -n "$USER_GH_PROXY" ]]; then
            return
        fi
        
        draw_header
        echo -e "${BLUE}▶ GitHub 线路配置${NC}"
        
        run_speedtest() {
            echo -e "${YELLOW}正在并行测速，请稍候...${NC}"
            local temp_dir=$(mktemp -d)
            local mirrors=("https://github.com" "${GITHUB_MIRRORS[@]}")
            
            for mirror in "${mirrors[@]}"; do
                (
                    local test_url
                    [[ "$mirror" == "https://github.com" ]] && test_url="$TEST_FILE_PATH" || test_url="${mirror}/${TEST_FILE_PATH}"
                    
                    local time_cost
                    time_cost=$(curl -sL -o /dev/null --max-time 3 -w "%{time_total}" "$test_url")
                    local exit_code=$?
                    
                    if [[ $exit_code -eq 0 ]]; then
                        local ms=$(awk -v t="$time_cost" 'BEGIN {printf "%.0f", t*1000}')
                        echo "$ms $mirror" >> "$temp_dir/results"
                    else
                        echo "9999 $mirror" >> "$temp_dir/results"
                    fi
                ) &
            done
            wait
            
            echo -e "\n   延迟(ms) | 线路地址"
            echo -e "------------|----------------------------------"
            
            local best_mirror=""
            local best_ms=9999

            if [[ -f "$temp_dir/results" ]]; then
                sort -n "$temp_dir/results" > "$temp_dir/sorted"
                
                while read line; do
                    local ms=$(echo $line | awk '{print $1}')
                    local url=$(echo $line | awk '{print $2}')
                    
                    if [[ "$ms" == "9999" ]]; then
                        echo -e " ${RED}超时/失败${NC}| $url"
                    else
                        if [[ -z "$best_mirror" ]]; then
                            best_mirror=$url
                            best_ms=$ms
                        fi
                        
                        local color=$GREEN
                        if [ "$ms" -gt 800 ]; then color=$YELLOW; fi
                        if [ "$ms" -gt 1500 ]; then color=$RED; fi
                        echo -e " ${color}${ms}ms${NC}\t| $url"
                    fi
                done < "$temp_dir/sorted"
            fi

            if [[ -n "$best_mirror" ]]; then
                USER_GH_PROXY="$best_mirror"
                echo -e "\n自动选择: ${CYAN}$best_mirror${NC} (延迟: ${best_ms}ms)"
            else
                USER_GH_PROXY="https://gh-proxy.org"
                echo -e "\n${RED}测速全失败，使用默认代理。${NC}"
            fi
            
            rm -rf "$temp_dir"
            sleep 2
        }

        echo -e "${GREEN}1.${NC} 自动测速选择最佳线路 ${WHITE}(并行极速)${NC}"
        echo -e "${GREEN}2.${NC} 手动选择线路"
        echo -e "${GREEN}3.${NC} 官方直连"
        read -p "选择 [1-3] (默认1): " gh_choice
        case ${gh_choice:-1} in
            2) select mirror in "${GITHUB_MIRRORS[@]}"; do USER_GH_PROXY="$mirror"; break; done ;;
            3) USER_GH_PROXY="https://github.com" ;;
            *) run_speedtest ;;
        esac
    }

    # 将 GitHub URL 转换为加速 URL
    convert_github_url() {
        local url="$1"
        
        # ���除末尾的 .git
        url="${url%.git}"
        
        # 提取 username/repo
        local repo=""
        if [[ "$url" =~ github\.com/([^/]+/[^/]+)$ ]]; then
            repo="${BASH_REMATCH[1]}"
        else
            echo "$url"
            return
        fi
        
        if [[ "$USER_GH_PROXY" == "https://github.com" ]]; then
            echo "https://github.com/$repo.git"
        else
            echo "${USER_GH_PROXY}/https://github.com/${repo}.git"
        fi
    }

    list_plugins() {
        if [[ ! -d "$PLUGINS_DIR" ]]; then return; fi
        local count=0
        for dir in "$PLUGINS_DIR"/*; do
            # 跳过 __pycache__ 目录
            if [[ -d "$dir" && "$(basename "$dir")" != "__pycache__" ]]; then
                count=$((count + 1))
                echo -e " ${CYAN}$(basename "$dir")${NC}"
            fi
        done
        if [[ $count -eq 0 ]]; then echo -e " ${GREY}(无插件)${NC}"; fi
    }

    while true; do
        draw_header
        echo -e "${BLUE}▶ 插件管理${NC}"
        echo -e " 插件目录: ${CYAN}$PLUGINS_DIR${NC}"
        echo -e "\n 已安装插件:"
        list_plugins
        draw_line
        echo -e "${GREEN}1.${NC} 安装插件"
        echo -e "${GREEN}2.${NC} 卸载插件"
        echo -e "${GREEN}3.${NC} 安装插件依赖"
        draw_line
        echo -e "${WHITE}0.${NC} 返回主菜单"
        echo -e ""
        read -p " 请选择: " plugin_opt

        case $plugin_opt in
            1)
                draw_header
                echo -e "${BLUE}▶ 安装插件${NC}"
                echo -e "请输入插件 GitHub 地址，支持以下格式："
                echo -e " • https://github.com/username/repo"
                echo -e " • https://github.com/username/repo.git"
                echo -e " • username/repo"
                read -p "请输入: " plugin_input

                if [[ -z "$plugin_input" ]]; then
                    log_warning "输入不能为空"
                    read -p "按回车继续..."
                    continue
                fi

                # 获取 GitHub 加速源
                get_github_proxy

                # 规范化 URL
                local git_url=""
                if [[ "$plugin_input" =~ ^https?:// ]]; then
                    git_url=$(convert_github_url "$plugin_input")
                else
                    git_url=$(convert_github_url "https://github.com/$plugin_input")
                fi

                # 提取插件名称
                local plugin_name=$(echo "$git_url" | sed 's|.*/||' | sed 's|\.git$||')
                local plugin_path="$PLUGINS_DIR/$plugin_name"

                echo -e "\n${BLUE}插件信息:${NC}"
                echo -e " 名称: ${CYAN}$plugin_name${NC}"
                echo -e " 地址: ${CYAN}$git_url${NC}"
                echo -e " 路径: ${CYAN}$plugin_path${NC}"

                if [[ -d "$plugin_path" ]]; then
                    log_info "检测到插件已存在，尝试更新..."
                    cd "$plugin_path" || continue
                    git pull
                    if [ $? -eq 0 ]; then
                        log_success "插件更新成功"
                        cd "$MAI_PATH" || continue
                    else
                        log_error "更新失败"
                        cd "$MAI_PATH" || continue
                        echo -e "${YELLOW}是否删除旧插件并重新克隆？${NC}"
                        read -p "请输入 (y/n): " re_choice
                        if [[ "$re_choice" != "y" ]]; then
                            read -p "按回车继续..."
                            continue
                        fi
                        rm -rf "$plugin_path"
                    fi
                fi

                if [[ ! -d "$plugin_path" ]]; then
                    log_info "正在克隆插件 ${CYAN}$plugin_name${NC}..."
                    git clone --depth 1 --progress "$git_url" "$plugin_path"
                    if [ $? -ne 0 ]; then
                        log_error "克隆失败！"
                        rm -rf "$plugin_path"
                        read -p "按回车继续..."
                        continue
                    fi
                fi

                # 创建 .gitignore 屏蔽 __pycache__
                if [[ ! -f "$plugin_path/.gitignore" ]]; then
                    echo "__pycache__/" > "$plugin_path/.gitignore"
                    echo "*.pyc" >> "$plugin_path/.gitignore"
                    echo ".DS_Store" >> "$plugin_path/.gitignore"
                fi

                if [[ -f "$plugin_path/requirements.txt" ]]; then
                    echo -e "\n${BLUE}▶ 安装插件依赖${NC}"
                    source "$VENV_PATH"
                    pip install -r "$plugin_path/requirements.txt"
                    if [ $? -eq 0 ]; then
                        log_success "依赖安装成功"
                    else
                        log_error "依赖安装失败"
                    fi
                else
                    log_info "未找到 requirements.txt，跳过依赖安装"
                fi

                log_success "插件 ${CYAN}$plugin_name${NC} 安装完成"
                read -p "按回车继续..."
                ;;
            2)
                draw_header
                echo -e "${BLUE}▶ 卸载插件${NC}"
                if [[ ! -d "$PLUGINS_DIR" ]] || [[ -z "$(ls -A "$PLUGINS_DIR" 2>/dev/null)" ]]; then
                    log_warning "没有已安装的插件"
                    read -p "按回车继续..."
                    continue
                fi

                echo -e "已安装的插件:"
                local plugins=()
                local idx=1
                for dir in "$PLUGINS_DIR"/*; do
                    if [[ -d "$dir" && "$(basename "$dir")" != "__pycache__" ]]; then
                        local plugin_name=$(basename "$dir")
                        plugins+=("$plugin_name")
                        echo -e " ${GREEN}$idx.${NC} $plugin_name"
                        idx=$((idx + 1))
                    fi
                done

                read -p "请输入插件名称或序号: " plugin_input
                local target_plugin=""

                if [[ "$plugin_input" =~ ^[0-9]+$ ]]; then
                    if [[ $plugin_input -ge 1 && $plugin_input -le ${#plugins[@]} ]]; then
                        target_plugin="${plugins[$((plugin_input - 1))]}"
                    fi
                else
                    target_plugin="$plugin_input"
                fi

                if [[ -z "$target_plugin" ]]; then
                    log_error "无效的选择"
                    read -p "按回车继续..."
                    continue
                fi

                local target_path="$PLUGINS_DIR/$target_plugin"
                if [[ ! -d "$target_path" ]]; then
                    log_error "插件目录不存在: $target_plugin"
                    read -p "按回车继续..."
                    continue
                fi

                echo -e "\n${YELLOW}确认删除以下内容：${NC}"
                echo -e " ${RED}$target_path${NC}"
                echo -e "\n${RED}警告：此操作不可撤销！${NC}"
                read -p "请输入插件名称确认删除: " confirm_name

                if [[ "$confirm_name" == "$target_plugin" ]]; then
                    rm -rf "$target_path"
                    log_success "插件 ${CYAN}$target_plugin${NC} 已卸载"
                else
                    log_warning "确认失败，操作已取消"
                fi
                read -p "按回车继续..."
                ;;
            3)
                draw_header
                echo -e "${BLUE}▶ 安装插件依赖${NC}"
                if [[ ! -d "$PLUGINS_DIR" ]] || [[ -z "$(ls -A "$PLUGINS_DIR" 2>/dev/null)" ]]; then
                    log_warning "没有已安装的插件"
                    read -p "按回车继续..."
                    continue
                fi

                echo -e "已安装的插件:"
                local plugins=()
                local idx=1
                for dir in "$PLUGINS_DIR"/*; do
                    if [[ -d "$dir" && "$(basename "$dir")" != "__pycache__" ]]; then
                        local plugin_name=$(basename "$dir")
                        plugins+=("$plugin_name")
                        echo -e " ${GREEN}$idx.${NC} $plugin_name"
                        idx=$((idx + 1))
                    fi
                done

                read -p "请输入插件名称或序号: " plugin_input
                local target_plugin=""

                if [[ "$plugin_input" =~ ^[0-9]+$ ]]; then
                    if [[ $plugin_input -ge 1 && $plugin_input -le ${#plugins[@]} ]]; then
                        target_plugin="${plugins[$((plugin_input - 1))]}"
                    fi
                else
                    target_plugin="$plugin_input"
                fi

                if [[ -z "$target_plugin" ]]; then
                    log_error "无效的选择"
                    read -p "按回车继续..."
                    continue
                fi

                local target_path="$PLUGINS_DIR/$target_plugin"
                if [[ ! -d "$target_path" ]]; then
                    log_error "插件目录不存在: $target_plugin"
                    read -p "按回车继续..."
                    continue
                fi

                if [[ ! -f "$target_path/requirements.txt" ]]; then
                    log_warning "未找到 requirements.txt"
                    read -p "按回车继续..."
                    continue
                fi

                echo -e "\n${BLUE}正在安装 ${CYAN}$target_plugin${NC} 的依赖...${NC}"
                source "$VENV_PATH"
                pip install -r "$target_path/requirements.txt"
                if [ $? -eq 0 ]; then
                    log_success "依赖安装成功"
                else
                    log_error "依赖安装失败"
                fi
                read -p "按回车继续..."
                ;;
            0)
                return
                ;;
        esac
    done
}


# =========================================================
# 9. 入口
# =========================================================

main_menu() {
    while true; do
        draw_header
        echo -e "${GREEN}1.${NC} 安装 / 更新 MaiBot ${WHITE}(全新部署)${NC}"
        draw_line
        echo -e "${PURPLE}2.${NC} 管理 MaiBot 核心   ${WHITE}(Bot / Adapter / TTS)${NC}"
        echo -e "${CYAN}3.${NC} 管理 NapCat 服务   ${WHITE}(Docker Start / Stop)${NC}"
        echo -e "${BLUE}4.${NC} 配置与访问         ${WHITE}(密钥 / 黑白名单)${NC}"
        echo -e "${YELLOW}5.${NC} LPMM知识库         ${WHITE}(文本提取/导入)${NC}"
        echo -e "${GREEN}6.${NC} 插件管理           ${WHITE}(安装/卸载/依赖)${NC}"
        draw_line
        echo -e "${WHITE}0.${NC} 退出脚本"
        echo -e ""
        read -p " 请输入选项: " choice
        
        case $choice in
            1) 
                INSTALLATION_ACTIVE=true
                configure_install_path
                step_install_mode
                step_venv_mode
                configure_github
                configure_pip
                configure_napcat_selection
                run_install
                INSTALLATION_ACTIVE=false
                ;;
            2) manage_maibot_menu ;;
            3) 
                if load_config; then manage_napcat_menu
                else log_error "未找到安装配置，请先执行安装。"; read -p "按回车继续..."
                fi ;;
            4) manage_config_access_menu ;;
            5) manage_lpmm_menu ;;
            6) manage_plugins_menu ;;
            0) exit 0 ;;
        esac
    done
}


main_menu