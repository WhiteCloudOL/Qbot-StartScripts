#!/bin/bash
#License: GNU GENERAL PUBLIC LICENSE Version 3
#Author: 清蒸云鸭
#Edited with Gemini
#Update: 2026-01-19

# =========================================================
# 1. 全局配置与变量
# =========================================================

CONFIG_FILE="$HOME/.maibot_config"

# --- 颜色定义 (全系高亮/粗体) ---
RED='\033[1;31m'      # 亮红
GREEN='\033[1;32m'    # 亮绿
YELLOW='\033[1;33m'   # 亮黄
BLUE='\033[1;34m'     # 亮蓝
PURPLE='\033[1;35m'   # 亮紫
CYAN='\033[1;36m'     # 亮青
WHITE='\033[1;37m'    # 亮白
NC='\033[0m'          # 重置

GITHUB_MIRRORS=(
    "https://gh-proxy.org"
    "https://hk.gh-proxy.org"
    "https://cdn.gh-proxy.org"
    "https://gh.llkk.cc"
    "https://github.moeyy.xyz"
)

TEST_FILE_PATH="https://raw.githubusercontent.com/MaiM-with-u/MaiBot/main/README.md"

# 临时存储用户选择的变量
USER_INSTALL_PATH=""
USER_GH_PROXY=""
USER_PIP_INDEX=""
USER_PIP_HOST=""
USER_NAPCAT_MODE="" 

# =========================================================
# 2. UI & 工具函数
# =========================================================

# --- 日志工具 ---
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 标题栏绘制 ---
draw_header() {
    clear
    echo -e "${PURPLE}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}          ${WHITE}🚀 MaiBot 一键部署与管理脚本 ${CYAN}v1.3${NC}             ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC}                ${WHITE}Copyright@清蒸云鸭,2026${NC}                 ${PURPLE}│${NC}"
    echo -e "${PURPLE}└────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
}

# --- 分隔线 ---
draw_line() {
    echo -e "${PURPLE}──────────────────────────────────────────────────────────${NC}"
}

# --- [新增] 显示当前已选配置 (面包屑导航) ---
print_prev_config() {
    if [[ -n "$USER_INSTALL_PATH" ]]; then
        echo -e "${WHITE}已选配置预览:${NC}"
        echo -e " ${PURPLE}●${NC} 安装路径: ${CYAN}${USER_INSTALL_PATH}${NC}"
    fi
    
    if [[ -n "$USER_GH_PROXY" ]]; then
        local gh_display="自定义/自动"
        [[ "$USER_GH_PROXY" == "https://github.com" ]] && gh_display="官方直连"
        echo -e " ${PURPLE}●${NC} GitHub源: ${CYAN}${gh_display}${NC} (${USER_GH_PROXY})"
    fi
    
    if [[ -n "$USER_PIP_HOST" ]]; then
        echo -e " ${PURPLE}●${NC} Pip 镜像: ${CYAN}${USER_PIP_HOST}${NC}"
    fi
    
    if [[ -n "$USER_INSTALL_PATH" ]]; then
        draw_line
    fi
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

# 增强版 Git Clone (显示进度)
git_clone_safe() {
    local url="$1"
    local dir="$2"
    
    while true; do
        if [[ -d "$dir" ]]; then
            log_info "检测到目录 ${CYAN}$dir${NC} 已存在，尝试更新..."
            cd "$dir" || return 1
            git pull
            if [ $? -eq 0 ]; then
                cd ..
                return 0
            else
                log_error "更新失败。"
                cd ..
                echo -e "${YELLOW}是否删除旧文件夹并重新克隆？${NC}"
                read -p "请输入 (y/n): " re_choice
                if [[ "$re_choice" == "y" ]]; then
                    rm -rf "$dir"
                else
                    return 1
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
            echo -e "${YELLOW}正在清理错误残留...${NC}"
            rm -rf "$dir"
            
            echo -e "1. 重试"
            echo -e "2. 跳过"
            echo -e "3. 退出脚本"
            read -p "请选择 [1-3]: " retry_choice
            case $retry_choice in
                2) return 1 ;;
                3) exit 1 ;;
                *) ;; 
            esac
        fi
    done
}

# 增强版 Docker Compose Up
docker_compose_safe() {
    local work_dir="$1"
    cd "$work_dir" || return 1
    
    while true; do
        log_info "正在启动 Docker 容器..."
        docker compose up -d
        
        if [ $? -eq 0 ]; then
            return 0
        else
            log_error "容器启动失败！"
            echo -e "${YELLOW}尝试清理容器状态...${NC}"
            docker compose down 2>/dev/null
            
            echo -e "1. 重试"
            echo -e "2. 放弃"
            read -p "请选择 [1-2]: " dc_choice
            if [[ "$dc_choice" == "2" ]]; then return 1; fi
        fi
    done
}

# Docker 安装函数
install_docker_safe() {
    while true; do
        log_info "调用 LinuxMirrors 脚本安装 Docker..."
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
        
        if command -v docker &> /dev/null; then
            log_success "Docker 安装成功！"
            return 0
        else
            log_error "Docker 安装检测失败。"
            echo -e "1. 重试"
            echo -e "2. 我已手动安装，继续"
            echo -e "3. 退出"
            read -p "请选择 [1-3]: " d_inst_choice
            case $d_inst_choice in
                2) return 0 ;;
                3) exit 1 ;;
                *) ;;
            esac
        fi
    done
}

# Docker 镜像源配置
configure_docker_mirror() {
    if ! command -v docker &> /dev/null; then return; fi

    echo -e "${BLUE}▶ Docker 镜像加速配置${NC}"
    echo "检测到 Docker 已安装，建议更换镜像源以加速下载。"
    echo -e "${GREEN}1.${NC} docker.1ms.run ${WHITE}(国内推荐)${NC}"
    echo -e "${GREEN}2.${NC} docker.xuanyuan.me ${WHITE}(国内推荐)${NC}"
    echo -e "${GREEN}3.${NC} 恢复官方源 ${WHITE}(清除加速配置)${NC}"
    echo -e "${GREEN}4.${NC} 保持不变 ${WHITE}(默认)${NC}"
    
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
        log_success "已恢复官方源配置"
    else
        echo "{\"registry-mirrors\": [\"$mirror_url\"]}" > "$daemon_file"
        log_success "已设置镜像源为: $mirror_url"
    fi

    log_info "重启 Docker 服务..."
    systemctl restart docker
}

# =========================================================
# 3. 配置流程模块 (串行向导)
# =========================================================

configure_install_path() {
    draw_header
    echo -e "${BLUE}▶ 1/4 安装目录配置${NC}"
    
    local default_path="$HOME/maimai"
    load_config
    if [[ -n "$MAI_PATH" ]]; then default_path="$MAI_PATH"; fi
    
    echo -e "上次/默认安装位置: ${CYAN}$default_path${NC}"
    read -p "请输入安装路径 (回车使用默认): " user_path
    
    if [[ -z "$user_path" ]]; then
        USER_INSTALL_PATH="$default_path"
    else
        USER_INSTALL_PATH="${user_path/#\~/$HOME}"
    fi
    mkdir -p "$USER_INSTALL_PATH"
}

configure_github() {
    draw_header
    print_prev_config
    echo -e "${BLUE}▶ 2/4 GitHub 线路配置${NC}"
    
    run_speedtest() {
        echo "正在测速，请稍候..."
        local temp_dir=$(mktemp -d)
        local mirrors=("${GITHUB_MIRRORS[@]}" "https://github.com")
        for mirror in "${mirrors[@]}"; do
            (
                local test_url=""
                if [[ "$mirror" == "https://github.com" ]]; then test_url="$TEST_FILE_PATH"; else test_url="${mirror}/${TEST_FILE_PATH}"; fi
                local time_cost
                time_cost=$(curl -sL -o /dev/null --max-time 5 -w "%{time_total}" "$test_url")
                if [[ $? -eq 0 ]]; then
                    echo "$time_cost $mirror" >> "$temp_dir/results"
                fi
            ) & 
        done
        wait
        if [[ -f "$temp_dir/results" ]]; then
            sort -n "$temp_dir/results" > "$temp_dir/sorted"
            local best_mirror=$(head -n 1 "$temp_dir/sorted" | awk '{print $2}')
            USER_GH_PROXY="$best_mirror"
            rm -rf "$temp_dir"
        else
            USER_GH_PROXY="https://gh-proxy.org"
            rm -rf "$temp_dir"
        fi
    }

    echo -e "${GREEN}1.${NC} 自动测速选择最佳线路 ${WHITE}(推荐)${NC}"
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
    print_prev_config
    echo -e "${BLUE}▶ 3/4 Pip 镜像源配置${NC}"
    echo -e "${GREEN}1.${NC} 阿里云 ${WHITE}(推荐)${NC}"
    echo -e "${GREEN}2.${NC} 清华大学"
    echo -e "${GREEN}3.${NC} 官方源"
    read -p "选择 [1-3] (默认1): " pip_choice
    case ${pip_choice:-1} in
        1) USER_PIP_INDEX="https://mirrors.aliyun.com/pypi/simple/"; USER_PIP_HOST="mirrors.aliyun.com" ;;
        2) USER_PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"; USER_PIP_HOST="pypi.tuna.tsinghua.edu.cn" ;;
        3) USER_PIP_INDEX="https://pypi.org/simple"; USER_PIP_HOST="pypi.org" ;;
        *) USER_PIP_INDEX="https://mirrors.aliyun.com/pypi/simple/"; USER_PIP_HOST="mirrors.aliyun.com" ;;
    esac
}

configure_napcat_selection() {
    draw_header
    print_prev_config
    echo -e "${BLUE}▶ 4/4 NapCat (NTQQ) 部署选项${NC}"
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
    echo -e "${YELLOW}请确认以下配置信息：${NC}"
    draw_line
    echo -e " 安装路径: ${CYAN}$USER_INSTALL_PATH${NC}"
    echo -e " GitHub源: ${CYAN}$USER_GH_PROXY${NC}"
    echo -e " Pip 源:   ${CYAN}$USER_PIP_HOST${NC}"
    
    local nc_mode_str="暂不安装"
    if [[ "$USER_NAPCAT_MODE" == "1" ]]; then nc_mode_str="Docker 部署"; 
    elif [[ "$USER_NAPCAT_MODE" == "2" ]]; then nc_mode_str="Shell 脚本"; fi
    echo -e " NapCat:   ${CYAN}${nc_mode_str}${NC}"
    
    draw_line
    read -p "确认无误开始安装? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi

    echo -e "\n${BLUE}▶ 开始安装系统依赖...${NC}"
    if command -v apt &> /dev/null; then
        sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq
        sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq python3-dev python3-venv python3-pip build-essential git wget curl screen jq
    elif command -v yum &> /dev/null; then
         sudo yum install -y python3-devel git wget curl screen jq
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
        if grep -q "WEBUI_HOST=127.0.0.1" "MaiBot/.env"; then
            sed -i 's/WEBUI_HOST=127.0.0.1/WEBUI_HOST=0.0.0.0/g' "MaiBot/.env"
            echo " - 已修改 .env 允许外网访问 WebUI"
        fi
    fi
    copy_conf "MaiBot-Napcat-Adapter/template/template_config.toml" "MaiBot-Napcat-Adapter/config.toml"

    echo -e "\n${BLUE}▶ 配置 Python 环境与依赖 (可能需要几分钟)...${NC}"
    if [[ ! -d "venv" ]]; then 
        echo " - 创建虚拟环境 venv..."
        python3 -m venv venv
    fi
    source venv/bin/activate
    mkdir -p ~/.pip
    echo -e "[global]\nindex-url = $USER_PIP_INDEX\ntrusted-host = $USER_PIP_HOST" > ~/.pip/pip.conf
    
    echo " - 更新 pip..."
    pip install --upgrade pip
    
    if [[ -f "MaiBot/requirements.txt" ]]; then 
        echo " - 安装 MaiBot 依赖..."
        pip install -r MaiBot/requirements.txt
    fi
    if [[ -f "MaiBot-Napcat-Adapter/requirements.txt" ]]; then 
        echo " - 安装 Adapter 依赖..."
        pip install -r MaiBot-Napcat-Adapter/requirements.txt
    fi

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
            # Docker Mode
            if ! command -v docker &> /dev/null; then
                log_warning "未检测到 Docker，准备安装..."
                install_docker_safe
            fi

            configure_docker_mirror

            mkdir -p "$NAPCAT_DIR"
            log_info "生成 docker-compose.yml..."
            cat > "$NAPCAT_DIR/docker-compose.yml" <<EOF
services:
  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat
    restart: always
    environment:
      - NAPCAT_UID=0
      - NAPCAT_GID=0
      - WEBUI_TOKEN=
    volumes:
      - ./config:/app/napcat/config
      - ./qq_config:/app/.config/QQ
    network_mode: "host"
EOF
            docker_compose_safe "$NAPCAT_DIR"
            if [ $? -eq 0 ]; then
                log_success "NapCat (Docker) 部署成功！"
            fi
            ;;
        2)
            # Shell Mode
            cd "$USER_INSTALL_PATH" || return
            while true; do
                curl -o napcat.sh https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh && bash napcat.sh --docker n --cli y
                if [ $? -eq 0 ]; then break; fi
                log_error "NapCat Shell 脚本执行出错。"
                read -p "是否重试? (y/n): " sh_retry
                if [[ "$sh_retry" != "y" ]]; then break; fi
            done
            ;;
    esac
}

# =========================================================
# 5. 配置与访问菜单 (新增)
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
        echo -e "${GREEN}1.${NC} 获取 MaiBot WebUI 密钥与地址"
        echo -e "${GREEN}2.${NC} 获取 NapCat WebUI 密钥与地址 (Docker)"
        echo -e "${GREEN}3.${NC} 修改 Adapter 配置 (黑白名单管理)"
        draw_line
        echo -e "${WHITE}0.${NC} 返回上一级"
        echo -e ""
        read -p " 请选择: " opt
        
        case $opt in
            1) 
                draw_header
                echo -e "${BLUE}▶ MaiBot WebUI 信息${NC}"
                if [[ -f "$MAIBOT_DIR/.env" ]] && [[ -f "$MAIBOT_DIR/data/webui.json" ]]; then
                    # 优先尝试 jq，如果失败使用 Python
                    local port=$(grep "WEBUI_PORT" "$MAIBOT_DIR/.env" | cut -d'=' -f2 | tr -d ' "')
                    local token=""
                    if command -v jq &>/dev/null; then
                        token=$(jq -r '.access_token' "$MAIBOT_DIR/data/webui.json")
                    else
                         token=$(python3 -c "import json; print(json.load(open('$MAIBOT_DIR/data/webui.json'))['access_token'])" 2>/dev/null)
                    fi
                    
                    if [[ -z "$port" ]]; then port="8001 (默认)"; fi
                    echo -e " 访问地址: ${CYAN}http://${PUBLIC_IP}:${port}${NC}"
                    echo -e " 访问密钥: ${YELLOW}${token}${NC}"
                else
                    log_error "未找到配置文件，请先启动一次 MaiBot 本体以生成配置。"
                fi
                read -p "按回车继续..."
                ;;
            2)
                draw_header
                echo -e "${BLUE}▶ NapCat WebUI 信息${NC}"
                # Docker映射路径通常在 NapCat/config
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
                    
                    echo -e " 访问地址: ${CYAN}http://${PUBLIC_IP}:${nc_port}${NC}"
                    echo -e " 访问密钥: ${YELLOW}${nc_token}${NC}"
                else
                    log_warning "未找到 NapCat 配置文件 ($nc_conf)"
                    echo "如果您使用的是 Docker 部署，请确保容器已启动过一次。"
                fi
                read -p "按回车继续..."
                ;;
            3)
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
        # 使用 Python 脚本读取当前配置并显示，避免 sed 解析出错
        python3 - <<EOF
import re
try:
    with open("$config_file", 'r', encoding='utf-8') as f:
        content = f.read()
        
    def find_list(key):
        match = re.search(r'^\s*' + key + r'\s*=\s*\[(.*?)\]', content, re.MULTILINE | re.DOTALL)
        if match:
            # 清理换行和空格，简单展示
            return match.group(1).replace('\n', '').strip()
        return "Not Found"

    def find_val(key):
        match = re.search(r'^\s*' + key + r'\s*=\s*"(.*?)"', content, re.MULTILINE)
        if match: return match.group(1)
        return "Unknown"

    print(f" 1. 群聊模式: \033[1;36m{find_val('group_list_type')}\033[0m")
    print(f"    群聊列表: \033[1;33m[{find_list('group_list')}]\033[0m")
    print(f" 2. 私聊模式: \033[1;36m{find_val('private_list_type')}\033[0m")
    print(f"    私聊列表: \033[1;33m[{find_list('private_list')}]\033[0m")
except Exception as e:
    print(f"读取配置出错: {e}")
EOF
        draw_line
        echo -e "${GREEN}a.${NC} 添加群号到列表       ${RED}b.${NC} 从列表移除群号"
        echo -e "${GREEN}c.${NC} 添加QQ到私聊列表     ${RED}d.${NC} 从私聊列表移除QQ"
        echo -e "${YELLOW}t.${NC} 切换名单类型 (白名单/黑名单)"
        echo -e "${WHITE}0.${NC} 返回"
        echo -e ""
        read -p " 请选择操作: " m_opt

        if [[ "$m_opt" == "0" ]]; then return; fi

        # Python 处理逻辑
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

        # 执行修改
        python3 - <<EOF
import re
import sys

file_path = "$config_file"
$py_script

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if action == 'toggle':
        # 切换 whitelist <-> blacklist
        pattern = r'(' + key + r'\s*=\s*")(\w+)(")'
        def switch(match):
            curr = match.group(2)
            new_val = 'blacklist' if curr == 'whitelist' else 'whitelist'
            print(f"模式已切换: {curr} -> {new_val}")
            return f"{match.group(1)}{new_val}{match.group(3)}"
        new_content = re.sub(pattern, switch, content, count=1)
        
    else:
        # 列表增删
        pattern = r'(' + key + r'\s*=\s*\[)(.*?)(\])'
        match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
        if match:
            # 提取现有的数字
            raw_list = match.group(2)
            # 使用简单的正则提取所有数字
            nums = re.findall(r'\d+', raw_list)
            current_set = set(nums)
            target = str(val)
            
            if action == 'add':
                if target in current_set:
                    print(f"号码 {target} 已存在。")
                else:
                    nums.append(target)
                    print(f"已添加 {target}")
            elif action == 'del':
                if target in current_set:
                    nums = [n for n in nums if n != target]
                    print(f"已移除 {target}")
                else:
                    print(f"号码 {target} 不在列表中。")
            
            # 重建列表字符串
            new_list_str = ",".join(nums)
            new_content = content.replace(match.group(0), f"{match.group(1)}{new_list_str}{match.group(3)}")
        else:
            print("未找到列表配置项")
            sys.exit(0)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

except Exception as e:
    print(f"修改失败: {e}")
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
            if [[ -d "$NAPCAT_DIR" ]]; then
                cd "$NAPCAT_DIR" || return
            else
                log_error "找不到目录: $NAPCAT_DIR"
                sleep 2
                continue
            fi
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
                    docker compose down
                    docker compose pull
                    docker compose up -d
                    log_success "重建完成！"
                fi
                sleep 2
                ;;
            6)
                echo -e "${RED}严重警告: 此操作将删除 NapCat 容器及所有数据！${NC}"
                read -p "请输入 'DELETE' 确认删除: " del_confirm
                if [[ "$del_confirm" == "DELETE" ]]; then
                    if [[ -d "$NAPCAT_DIR" ]]; then
                         cd "$NAPCAT_DIR" || return
                         docker compose down 2>/dev/null
                         cd ..
                         rm -rf "$NAPCAT_DIR"
                         log_success "已移除。"
                    fi
                fi
                sleep 2
                ;;
            0) return ;;
            *) ;;
        esac
        if [[ "$nc_opt" =~ [1-3] ]]; then read -p "操作完成，按回车继续..."; fi
    done
}

manage_maibot_menu() {
    if ! load_config; then
        echo -e "${RED}未找到安装记录${NC}"
        echo "请输入 MaiBot 的安装目录:"
        read -p "> " manual_path
        if [[ -d "$manual_path" ]]; then save_config "$manual_path"; load_config; else log_error "目录不存在"; return; fi
    fi
    if ! check_screen_installed; then log_error "请先安装 screen"; return; fi

    local MAIBOT_DIR="$MAI_PATH/MaiBot"
    local ADAPTER_DIR="$MAI_PATH/MaiBot-Napcat-Adapter"
    local TTS_ADAPTER_DIR="$MAI_PATH/maimbot_tts_adapter"
    local VENV_PATH="$MAI_PATH/venv/bin/activate"

    start_py_service() {
        local name="$1"
        local screen_name="$2"
        local dir="$3"
        local script="$4"
        if [[ ! -d "$dir" ]]; then log_warning "$name 目录不存在"; return; fi
        
        # --- 新增：MaiBot 用户协议检测逻辑 ---
        if [[ "$name" == "MaiBot" ]]; then
             # 检测是否是首次运行(简单判断是否有logs或data，或者直接每次都提示)
             # 为了保险，我们提示用户
             echo -e "${YELLOW}⚠️  启动提示 ⚠️${NC}"
             echo -e "如果是首次启动 MaiBot，你需要同意 ${CYAN}用户协议(EULA)${NC}。"
             echo -e "程序将会在后台 Screen 启动，若未同意协议，它会卡在等待输入界面。"
             echo -e "1. 正常后台启动 (已同意过)"
             echo -e "2. 启动并进入控制台 (首次运行选这个)"
             read -p "请选择 [1/2]: " run_mode
             
             cd "$dir" || return
             screen -list | grep -q "$screen_name" && screen -S "$screen_name" -X quit
             echo -e "${BLUE}正在启动 $name...${NC}"
             
             # 启动 screen
             screen -dmS "$screen_name" bash -c "source '$VENV_PATH'; echo -e '${GREEN}$name 启动中...${NC}'; python3 $script; echo -e '${RED}$name 已停止/崩溃。${NC}'; exec bash"
             sleep 1
             
             if [[ "$run_mode" == "2" ]]; then
                 echo -e "${GREEN}即将进入控制台...${NC}"
                 echo -e "----------------------------------------"
                 echo -e "请在控制台输入 ${CYAN}同意${NC} 或 ${CYAN}confirmed${NC} 并回车"
                 echo -e "完成后按 ${YELLOW}Ctrl+A${NC} 然后按 ${YELLOW}D${NC} 来退出控制台保持后台运行"
                 echo -e "----------------------------------------"
                 read -p "按回车立即进入..." 
                 screen -r "$screen_name"
             else
                 log_success "$name 已在后台启动"
             fi
             return
        fi
        # -----------------------------------

        cd "$dir" || return
        screen -list | grep -q "$screen_name" && screen -S "$screen_name" -X quit
        echo -e "${BLUE}启动 $name...${NC}"
        screen -dmS "$screen_name" bash -c "source '$VENV_PATH'; echo -e '${GREEN}$name 启动中...${NC}'; python3 $script; echo -e '${RED}$name 已停止/崩溃。${NC}'; exec bash"
        sleep 1
    }

    stop_py_service() {
        local name="$1"
        local screen_name="$2"
        if screen -list | grep -q "$screen_name"; then screen -S "$screen_name" -X quit; log_success "已停止 $name"; else echo -e "$name 未运行"; fi
    }

    check_maibot_status() {
        local services=("mai-main:MaiBot(本体)" "mai-adapter:Adapter(适配器)" "mai-tts:TTS(语音)")
        for s in "${services[@]}"; do
            local screen_name=${s%%:*}
            local display_name=${s##*:}
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
        echo -e "${CYAN}3.${NC} 开启 MaiBot 本体     ${CYAN}4.${NC} 停止 MaiBot 本体"
        echo -e "${CYAN}5.${NC} 开启 Adapter 适配器  ${CYAN}6.${NC} 停止 Adapter 适配器"
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
# 7. 入口
# =========================================================

main_menu() {
    while true; do
        draw_header
        echo -e "${GREEN}1.${NC} 安装 / 更新 MaiBot ${WHITE}(全新部署)${NC}"
        draw_line
        echo -e "${PURPLE}2.${NC} 管理 MaiBot 核心   ${WHITE}(Bot / Adapter / TTS)${NC}"
        echo -e "${CYAN}3.${NC} 管理 NapCat 服务   ${WHITE}(Docker Start / Stop)${NC}"
        echo -e "${BLUE}4.${NC} 配置与访问         ${WHITE}(密钥 / 黑白名单)${NC}"
        draw_line
        echo -e "${WHITE}0.${NC} 退出脚本"
        echo -e ""
        read -p " 请输入选项: " choice
        
        case $choice in
            1) 
                configure_install_path
                configure_github
                configure_pip
                configure_napcat_selection
                run_install 
                ;;
            2) manage_maibot_menu ;;
            3) 
                if load_config; then
                    manage_napcat_menu
                else
                    log_error "未找到安装配置，请先执行安装或手动指定路径。"
                    read -p "按回车继续..."
                fi
                ;;
            4) manage_config_access_menu ;;
            0) exit 0 ;;
            *) ;;
        esac
    done
}

main_menu