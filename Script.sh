#!/bin/bash

# 文件分布：
# Maim-with-u/
#   MaiBot/
#   MaiBot-Napcat-Adapter/
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
    echo -e "1. 一键开启 MaiBot 和 Adapter"
    echo -e "2. 仅开启/重启 MaiBot"
    echo -e "3. 仅开启/重启 Adapter"
    echo -e "4. 一键关闭所有服务"
    echo -e "5. 单独关闭 MaiBot"
    echo -e "6. 单独关闭 Adapter"
    echo -e "7. 查看运行状态"
    echo -e "8. 退出脚本"
    echo -e "${BLUE}=====================================${NC}"
    echo -n "请选择操作 [1-8]: "
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
    
    echo -e "${BLUE}==========================${NC}"
    echo -e "使用 'screen -R 名称' 查看具体输出"
    echo -e "使用 'screen -list' 查看所有screen会话"
}

# 主循环
main() {
    # 检查必要目录
    if ! check_directories; then
        echo -e "${RED}目录检查失败，请确保脚本放在正确的位置${NC}"
        exit 1
    fi
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                echo -e "\n${GREEN}一键启动所有服务...${NC}"
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
                echo -e "\n${YELLOW}关闭所有服务...${NC}"
                stop_all
                check_status
                ;;
            5)
                echo -e "\n${YELLOW}关闭 MaiBot...${NC}"
                stop_service "MaiBot" "mai-main"
                check_status
                ;;
            6)
                echo -e "\n${YELLOW}关闭 Adapter...${NC}"
                stop_service "Adapter" "mai-adapter"
                check_status
                ;;
            7)
                check_status
                ;;
            8)
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
