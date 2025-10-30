#!/bin/bash

# AstrBot QQ Launcher Script
# Copyright@清蒸云鸭,2025
# 配置文件: astrbot-qq-script-config/config.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/astrbot-qq-script-config"
CONFIG_FILE="$CONFIG_DIR/config.json"
SCREEN_NAME="astrbot"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 创建默认配置
create_default_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
{
    "qq_number": "123456789",
    "working_directory": ".",
    "venv_path": "venv/bin/activate",
    "astrbot_command": "python3 main.py"
}
EOF
    echo -e "${GREEN}已创建默认配置文件: $CONFIG_FILE${NC}"
}

# 加载配置
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}配置文件不存在，正在创建默认配置...${NC}"
        create_default_config
    fi
    
    QQ_NUMBER=$(jq -r '.qq_number' "$CONFIG_FILE" 2>/dev/null)
    WORKING_DIR=$(jq -r '.working_directory' "$CONFIG_FILE" 2>/dev/null)
    VENV_PATH=$(jq -r '.venv_path' "$CONFIG_FILE" 2>/dev/null)
    ASTRBOT_CMD=$(jq -r '.astrbot_command' "$CONFIG_FILE" 2>/dev/null)
    
    # 如果jq解析失败，使用默认值
    if [[ "$QQ_NUMBER" == "null" || -z "$QQ_NUMBER" ]]; then
        QQ_NUMBER="123456789"
    fi
    if [[ "$WORKING_DIR" == "null" || -z "$WORKING_DIR" ]]; then
        WORKING_DIR="."
    fi
    if [[ "$VENV_PATH" == "null" || -z "$VENV_PATH" ]]; then
        VENV_PATH="venv/bin/activate"
    fi
    if [[ "$ASTRBOT_CMD" == "null" || -z "$ASTRBOT_CMD" ]]; then
        ASTRBOT_CMD="python3 main.py"
    fi
    
    # 确保工作目录是绝对路径
    if [[ "$WORKING_DIR" == "." ]]; then
        WORKING_DIR="$SCRIPT_DIR"
    elif [[ ! "$WORKING_DIR" =~ ^/ ]]; then
        WORKING_DIR="$SCRIPT_DIR/$WORKING_DIR"
    fi
}

# 更新配置
update_config() {
    local key="$1"
    local value="$2"
    
    if command -v jq >/dev/null 2>&1; then
        jq ".$key = \"$value\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    else
        echo -e "${YELLOW}警告: 未找到jq命令，无法更新配置文件${NC}"
    fi
}

# 检查screen是否安装
check_screen() {
    if ! command -v screen &> /dev/null; then
        echo -e "${RED}错误: 未找到screen命令，请先安装screen${NC}"
        echo "Ubuntu/Debian: sudo apt install screen"
        echo "CentOS/RHEL: sudo yum install screen"
        exit 1
    fi
}

# 检查napcat是否安装
check_napcat() {
    if ! command -v napcat &> /dev/null; then
        echo -e "${YELLOW}警告: 未找到napcat命令，Napcat相关功能可能无法正常工作${NC}"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}      AstrBot QQ 启动器${NC}"
    echo -e "${BLUE}    COPYRIGHT@清蒸云鸭,2025${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "当前QQ号: ${GREEN}$QQ_NUMBER${NC}"
    echo -e "工作目录: ${GREEN}$WORKING_DIR${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "1. 开启 AstrBot"
    echo -e "2. 关闭 AstrBot"
    echo -e "3. 重启 AstrBot"
    echo -e "4. 开启 NapcatQQ"
    echo -e "5. 关闭 NapcatQQ"
    echo -e "6. 切换 BOT QQ号"
    echo -e "7. 查看 AstrBot 日志"
    echo -e "8. 查看 Napcat 日志"
    echo -e "0. 退出"
    echo -e "${BLUE}================================${NC}"
    echo -n "请选择操作 [0-8]: "
}

# 功能1: 开启AstrBot
start_astrbot() {
    echo -e "${BLUE}正在启动AstrBot...${NC}"
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo -e "${YELLOW}AstrBot已经在运行中!${NC}"
        return 1
    fi
    
    cd "$WORKING_DIR"
    
    if [[ ! -f "$VENV_PATH" ]]; then
        echo -e "${YELLOW}警告: 虚拟环境文件未找到: $VENV_PATH${NC}"
    fi
    
    screen -dmS "$SCREEN_NAME" bash -c "
        cd '$WORKING_DIR';
        if [ -f '$VENV_PATH' ]; then
            source '$VENV_PATH';
        fi;
        $ASTRBOT_CMD;
        exec bash"
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo -e "${GREEN}AstrBot 已开启 (Screen名称: $SCREEN_NAME)${NC}"
    else
        echo -e "${RED}启动AstrBot失败!${NC}"
        return 1
    fi
}

# 功能2: 关闭AstrBot
stop_astrbot() {
    echo -e "${BLUE}正在关闭AstrBot...${NC}"
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        screen -S "$SCREEN_NAME" -X quit
        echo -e "${GREEN}AstrBot 已关闭${NC}"
    else
        echo -e "${YELLOW}AstrBot 未在运行${NC}"
    fi
}

# 功能3: 重启AstrBot
restart_astrbot() {
    echo -e "${BLUE}正在重启AstrBot...${NC}"
    stop_astrbot
    sleep 2
    start_astrbot
}

# 功能4: 开启NapcatQQ
start_napcat() {
    echo -e "${BLUE}正在启动NapcatQQ...${NC}"
    if command -v napcat &> /dev/null; then
        napcat start "$QQ_NUMBER"
        echo -e "${GREEN}NapcatQQ 已启动 (QQ: $QQ_NUMBER)${NC}"
    else
        echo -e "${RED}错误: napcat命令未找到${NC}"
    fi
}

# 功能5: 关闭NapcatQQ
stop_napcat() {
    echo -e "${BLUE}正在关闭NapcatQQ...${NC}"
    if command -v napcat &> /dev/null; then
        napcat stop
        echo -e "${GREEN}NapcatQQ 已关闭${NC}"
    else
        echo -e "${RED}错误: napcat命令未找到${NC}"
    fi
}

# 功能6: 切换QQ号
change_qq() {
    echo -n "请输入新的QQ号: "
    read -r new_qq
    
    if [[ "$new_qq" =~ ^[0-9]+$ ]]; then
        update_config "qq_number" "$new_qq"
        load_config
        echo -e "${GREEN}QQ号已更新为: $QQ_NUMBER${NC}"
    else
        echo -e "${RED}错误: 请输入有效的QQ号${NC}"
    fi
}

# 功能7: 查看AstrBot日志
view_astrbot_log() {
    echo -e "${YELLOW}即将进入AstrBot screen窗口...${NC}"
    echo -e "${YELLOW}要退出窗口，请按 Ctrl+A，然后按 D${NC}"
    echo -e "${YELLOW}按任意键继续...${NC}"
    read -n 1 -s
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        screen -r "$SCREEN_NAME"
    else
        echo -e "${RED}AstrBot 未在运行${NC}"
    fi
}

# 功能8: 查看Napcat日志
view_napcat_log() {
    echo -e "${BLUE}正在显示Napcat日志...${NC}"
    if command -v napcat &> /dev/null; then
        napcat log "$QQ_NUMBER"
    else
        echo -e "${RED}错误: napcat命令未找到${NC}"
    fi
}

main() {
    check_screen
    check_napcat
    load_config
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                start_astrbot
                ;;
            2)
                stop_astrbot
                ;;
            3)
                restart_astrbot
                ;;
            4)
                start_napcat
                ;;
            5)
                stop_napcat
                ;;
            6)
                change_qq
                ;;
            7)
                view_astrbot_log
                ;;
            8)
                view_napcat_log
                ;;
            0)
                echo -e "${GREEN}再见!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入!${NC}"
                ;;
        esac
        
        echo
        echo -n "按任意键返回菜单..."
        read -n 1 -s
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
