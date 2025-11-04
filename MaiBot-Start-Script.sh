#!/bin/bash

# 文件分布：
# Maim-with-u/
#   MaiBot/
#   MaiBot-Napcat-Adapter/
#   venv/
#   scripts_config/
#     config.json
#   Script.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAIBOT_DIR="$SCRIPT_DIR/MaiBot"
ADAPTER_DIR="$SCRIPT_DIR/MaiBot-Napcat-Adapter"
VENV_PATH="$SCRIPT_DIR/venv/bin/activate"
CONFIG_DIR="$SCRIPT_DIR/scripts_config"
CONFIG_FILE="$CONFIG_DIR/config.json"

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
    
    # 如果jq解析失败，使用默认值
    if [[ "$QQ_NUMBER" == "null" || -z "$QQ_NUMBER" ]]; then
        QQ_NUMBER="123456789"
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

# 检查目录是否存在
check_directories() {
    if [ ! -d "$MAIBOT_DIR" ]; then
        echo -e "${RED}错误: MaiBot目录不存在: $MAIBOT_DIR${NC}"
        return 1
    fi
    
    if [ ! -d "$ADAPTER_DIR" ]; then
        echo -e "${RED}错误: Adapter目录不存在: $ADAPTER_DIR${NC}"
        return 1
    fi
    
    if [ ! -f "$VENV_PATH" ]; then
        echo -e "${RED}错误: 虚拟环境不存在: $VENV_PATH${NC}"
        return 1
    fi
    
    return 0
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
        return 1
    fi
    return 0
}

# 检查并关闭指定名称的screen
kill_screen() {
    local screen_name=$1
    if screen -list | grep -q "$screen_name"; then
        echo -e "${YELLOW}找到已存在的 $screen_name screen，正在关闭...${NC}"
        screen -S "$screen_name" -X quit
        sleep 2
        echo -e "${GREEN}已关闭 $screen_name screen${NC}"
    fi
}

# 启动MaiBot
start_maibot() {
    echo -e "${BLUE}正在启动 MaiBot...${NC}"
    cd "$MAIBOT_DIR" || { echo -e "${RED}无法进入 $MAIBOT_DIR 目录${NC}"; return 1; }
    
    kill_screen "mai-main"
    
    screen -dmS mai-main bash -c "
        source '$VENV_PATH';
        echo -e '${GREEN}MaiBot 启动中...${NC}';
        python3 bot.py;
        echo -e '${YELLOW}MaiBot 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "
    
    if screen -list | grep -q "mai-main"; then
        echo -e "${GREEN}MaiBot 启动成功！screen名称: mai-main${NC}"
        echo -e "${YELLOW}使用 'screen -r mai-main' 查看输出${NC}"
        return 0
    else
        echo -e "${RED}MaiBot 启动失败${NC}"
        return 1
    fi
}

# 启动Adapter
start_adapter() {
    echo -e "${BLUE}正在启动 Adapter...${NC}"
    cd "$ADAPTER_DIR" || { echo -e "${RED}无法进入 $ADAPTER_DIR 目录${NC}"; return 1; }
    
    kill_screen "mai-adapter"
    
    screen -dmS mai-adapter bash -c "
        source '$VENV_PATH';
        echo -e '${GREEN}Adapter 启动中...${NC}';
        python3 main.py;
        echo -e '${YELLOW}Adapter 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "
    
    if screen -list | grep -q "mai-adapter"; then
        echo -e "${GREEN}Adapter 启动成功！screen名称: mai-adapter${NC}"
        echo -e "${YELLOW}使用 'screen -r mai-adapter' 查看输出${NC}"
        return 0
    else
        echo -e "${RED}Adapter 启动失败${NC}"
        return 1
    fi
}

# 启动Napcat
start_napcat() {
    echo -e "${BLUE}正在启动 Napcat...${NC}"
    
    if ! check_napcat; then
        return 1
    fi
    
    # 检查Napcat是否已经在运行
    if napcat status | grep -q "running"; then
        echo -e "${YELLOW}Napcat 已经在运行中${NC}"
        return 0
    fi
    
    napcat start "$QQ_NUMBER"
    
    # 等待一段时间检查状态
    sleep 3
    
    if napcat status | grep -q "running"; then
        echo -e "${GREEN}Napcat 启动成功！QQ号: $QQ_NUMBER${NC}"
        return 0
    else
        echo -e "${RED}Napcat 启动失败${NC}"
        return 1
    fi
}

# 重启Napcat
restart_napcat() {
    echo -e "${BLUE}正在重启 Napcat...${NC}"
    
    if ! check_napcat; then
        return 1
    fi
    
    napcat restart "$QQ_NUMBER"
    
    sleep 3
    
    if napcat status | grep -q "running"; then
        echo -e "${GREEN}Napcat 重启成功！QQ号: $QQ_NUMBER${NC}"
        return 0
    else
        echo -e "${RED}Napcat 重启失败${NC}"
        return 1
    fi
}

# 停止Napcat
stop_napcat() {
    echo -e "${BLUE}正在停止 Napcat...${NC}"
    
    if ! check_napcat; then
        return 1
    fi
    
    if napcat status | grep -q "stopped"; then
        echo -e "${YELLOW}Napcat 已经停止${NC}"
        return 0
    fi
    
    napcat stop
    
    sleep 2
    
    if napcat status | grep -q "stopped"; then
        echo -e "${GREEN}Napcat 已停止${NC}"
        return 0
    else
        echo -e "${RED}Napcat 停止失败${NC}"
        return 1
    fi
}

# 切换QQ号
change_qq() {
    echo -n "请输入新的QQ号: "
    read -r new_qq
    
    if [[ "$new_qq" =~ ^[0-9]+$ ]]; then
        update_config "qq_number" "$new_qq"
        load_config
        echo -e "${GREEN}QQ号已更新为: $QQ_NUMBER${NC}"
        
        # 如果Napcat正在运行，询问是否重启
        if check_napcat && napcat status | grep -q "running"; then
            echo -n "是否重启Napcat以应用新的QQ号？[y/N]: "
            read -r restart_choice
            if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                restart_napcat
            fi
        fi
    else
        echo -e "${RED}错误: 请输入有效的QQ号${NC}"
    fi
}

# 查看Napcat日志
view_napcat_log() {
    echo -e "${BLUE}正在显示Napcat日志...${NC}"
    
    if ! check_napcat; then
        return 1
    fi
    
    echo -e "${YELLOW}按Ctrl+C退出日志查看${NC}"
    napcat log "$QQ_NUMBER"
}

# 关闭所有服务
stop_all() {
    echo -e "${YELLOW}正在关闭所有服务...${NC}"
    
    if screen -list | grep -q "mai-main"; then
        screen -S "mai-main" -X quit
        echo -e "${GREEN}已关闭 MaiBot${NC}"
    else
        echo -e "${YELLOW}MaiBot 未运行${NC}"
    fi
    
    if screen -list | grep -q "mai-adapter"; then
        screen -S "mai-adapter" -X quit
        echo -e "${GREEN}已关闭 Adapter${NC}"
    else
        echo -e "${YELLOW}Adapter 未运行${NC}"
    fi
    
    if check_napcat && napcat status | grep -q "running"; then
        napcat stop
        echo -e "${GREEN}已关闭 Napcat${NC}"
    else
        echo -e "${YELLOW}Napcat 未运行${NC}"
    fi
}

# 关闭指定服务
stop_service() {
    local service_name=$1
    local screen_name=$2
    
    if screen -list | grep -q "$screen_name"; then
        screen -S "$screen_name" -X quit
        echo -e "${GREEN}已关闭 $service_name${NC}"
    else
        echo -e "${YELLOW}$service_name 未运行${NC}"
    fi
}

# 显示菜单
show_menu() {
    echo -e "\n${GREEN}By 清蒸云鸭@Q113251172${NC}"
    echo -e "\n${BLUE}========== MaiBot 管理脚本 ==========${NC}"
    echo -e "当前目录: $SCRIPT_DIR"
    echo -e "当前QQ号: ${GREEN}$QQ_NUMBER${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "1. 一键开启所有服务 (MaiBot + Adapter + Napcat)"
    echo -e "2. 仅开启/重启 MaiBot"
    echo -e "3. 仅开启/重启 Adapter"
    echo -e "4. 开启/重启 Napcat"
    echo -e "5. 一键关闭所有服务"
    echo -e "6. 单独关闭 MaiBot"
    echo -e "7. 单独关闭 Adapter"
    echo -e "8. 单独关闭 Napcat"
    echo -e "9. 切换 QQ号"
    echo -e "10. 查看运行状态"
    echo -e "11. 查看 Napcat 日志"
    echo -e "12. 退出脚本"
    echo -e "${BLUE}=====================================${NC}"
    echo -n "请选择操作 [1-12]: "
}

# 检查运行状态
check_status() {
    echo -e "\n${BLUE}====== 服务运行状态 ======${NC}"
    
    if screen -list | grep -q "mai-main"; then
        echo -e "MaiBot: ${GREEN}运行中${NC} (screen: mai-main)"
    else
        echo -e "MaiBot: ${RED}未运行${NC}"
    fi
    
    if screen -list | grep -q "mai-adapter"; then
        echo -e "Adapter: ${GREEN}运行中${NC} (screen: mai-adapter)"
    else
        echo -e "Adapter: ${RED}未运行${NC}"
    fi
    
    if check_napcat; then
        if napcat status | grep -q "running"; then
            echo -e "Napcat: ${GREEN}运行中${NC} (QQ: $QQ_NUMBER)"
        else
            echo -e "Napcat: ${RED}未运行${NC}"
        fi
    else
        echo -e "Napcat: ${YELLOW}未安装${NC}"
    fi
    
    echo -e "${BLUE}==========================${NC}"
    echo -e "使用 'screen -R 名称' 查看具体输出"
    echo -e "使用 'screen -list' 查看所有screen会话"
    echo -e "使用 'napcat status' 查看Napcat状态"
}

# 主循环
main() {
    # 检查必要目录和工具
    check_screen
    if ! check_directories; then
        echo -e "${RED}目录检查失败，请确保脚本放在正确的位置${NC}"
        exit 1
    fi
    
    # 加载配置
    load_config
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                echo -e "\n${GREEN}一键启动所有服务...${NC}"
                start_napcat
                start_maibot
                start_adapter
                check_status
                ;;
            2)
                echo -e "\n${GREEN}启动/重启 MaiBot...${NC}"
                start_maibot
                check_status
                ;;
            3)
                echo -e "\n${GREEN}启动/重启 Adapter...${NC}"
                start_adapter
                check_status
                ;;
            4)
                echo -e "\n${GREEN}启动/重启 Napcat...${NC}"
                restart_napcat
                check_status
                ;;
            5)
                echo -e "\n${YELLOW}关闭所有服务...${NC}"
                stop_all
                check_status
                ;;
            6)
                echo -e "\n${YELLOW}关闭 MaiBot...${NC}"
                stop_service "MaiBot" "mai-main"
                check_status
                ;;
            7)
                echo -e "\n${YELLOW}关闭 Adapter...${NC}"
                stop_service "Adapter" "mai-adapter"
                check_status
                ;;
            8)
                echo -e "\n${YELLOW}关闭 Napcat...${NC}"
                stop_napcat
                check_status
                ;;
            9)
                echo -e "\n${GREEN}切换 QQ号...${NC}"
                change_qq
                ;;
            10)
                check_status
                ;;
            11)
                view_napcat_log
                ;;
            12)
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac
        
        echo -e "\n按回车键继续..."
        read
        clear
    done
}

# 启动主程序
clear
echo -e "${GREEN}MaiBot 管理脚本启动中...${NC}"
main
