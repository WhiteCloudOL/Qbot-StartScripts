#!/bin/bash

# ============================================
# MaiBot 启动管理脚本
# 文件分布：
# Maim-with-u/
#   ├── MaiBot/
#   ├── maimbot_tts_adapter/   (可选)
#   └── Script.sh
# ============================================

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------- 路径定义 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIBOT_DIR="$SCRIPT_DIR/MaiBot"
TTS_ADAPTER_DIR="$SCRIPT_DIR/maimbot_tts_adapter"

# ---------- Screen 会话定义 ----------
MAIBOT_SCREEN="maibot"
TTS_SCREEN="mai-tts"

# 检查目录是否存在（仅警告，不中断）
check_directories() {
    local missing_dirs=()

    if [ ! -d "$MAIBOT_DIR" ]; then
        missing_dirs+=("MaiBot")
    fi

    if [ ! -d "$TTS_ADAPTER_DIR" ]; then
        missing_dirs+=("maimbot_tts_adapter")
    fi

    if [ ${#missing_dirs[@]} -gt 0 ]; then
        echo -e "${YELLOW}警告: 以下目录不存在: ${missing_dirs[*]}${NC}"
        echo -e "${YELLOW}相关功能将不可用${NC}"
    fi
    echo -e "${YELLOW}注意: TTS非必须项，其是否开启无关主程序${NC}"
    return 0
}

# 检查 screen 是否安装
check_screen() {
    if ! command -v screen &> /dev/null; then
        echo -e "${RED}错误: 未找到screen命令，请先安装screen${NC}"
        echo "Ubuntu/Debian: sudo apt install screen"
        echo "CentOS/RHEL: sudo yum install screen"
        exit 1
    fi
}

# 检查并关闭指定名称的 screen
kill_screen() {
    local screen_name=$1

    if screen -list | grep -q "$screen_name"; then
        echo -e "${YELLOW}找到已存在的 $screen_name screen，正在关闭...${NC}"
        screen -S "$screen_name" -X quit
        sleep 2
        echo -e "${GREEN}已关闭 $screen_name screen${NC}"
    fi
}

# 进入指定 screen 窗口
view_screen() {
    local screen_name=$1
    local service_name=$2

    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}正在进入 $service_name 的screen窗口...${NC}"
        echo -e "${YELLOW}提示: 要退出screen窗口并保持程序运行，请按 ${CYAN}Ctrl+A${YELLOW} 然后按 ${CYAN}D${YELLOW}${NC}"
        echo -e "${YELLOW}等待3秒...${NC}"
        sleep 3
        screen -r "$screen_name"
    else
        echo -e "${RED}$service_name 未运行，无法查看${NC}"
    fi
}

# 启动 MaiBot
start_maibot() {
    if [ ! -d "$MAIBOT_DIR" ]; then
        echo -e "${RED}错误: MaiBot目录不存在，跳过启动${NC}"
        return 1
    fi

    echo -e "${BLUE}正在启动 MaiBot...${NC}"
    cd "$MAIBOT_DIR" || {
        echo -e "${RED}无法进入 $MAIBOT_DIR 目录${NC}"
        return 1
    }

    kill_screen "$MAIBOT_SCREEN"

    screen -dmS "$MAIBOT_SCREEN" bash -c "
        echo -e '${GREEN}MaiBot 启动中...${NC}';
        uv run bot.py;
        echo -e '${YELLOW}MaiBot 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "

    if screen -list | grep -q "$MAIBOT_SCREEN"; then
        echo -e "${GREEN}MaiBot 启动成功！screen名称: $MAIBOT_SCREEN${NC}"
        echo -e "${YELLOW}使用 'screen -r $MAIBOT_SCREEN' 查看输出${NC}"
        return 0
    else
        echo -e "${RED}MaiBot 启动失败${NC}"
        return 1
    fi
}

# 启动 TTS Adapter
start_tts_adapter() {
    if [ ! -d "$TTS_ADAPTER_DIR" ]; then
        echo -e "${RED}错误: TTS Adapter目录不存在，跳过启动${NC}"
        return 1
    fi

    echo -e "${BLUE}正在启动 TTS Adapter...${NC}"
    cd "$TTS_ADAPTER_DIR" || {
        echo -e "${RED}无法进入 $TTS_ADAPTER_DIR 目录${NC}"
        return 1
    }

    kill_screen "$TTS_SCREEN"

    screen -dmS "$TTS_SCREEN" bash -c "
        echo -e '${GREEN}TTS Adapter 启动中...${NC}';
        uv run main.py;
        echo -e '${YELLOW}TTS Adapter 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "

    if screen -list | grep -q "$TTS_SCREEN"; then
        echo -e "${GREEN}TTS Adapter 启动成功！screen名称: $TTS_SCREEN${NC}"
        echo -e "${YELLOW}使用 'screen -r $TTS_SCREEN' 查看输出${NC}"
        return 0
    else
        echo -e "${RED}TTS Adapter 启动失败${NC}"
        return 1
    fi
}

# 关闭所有服务
stop_all() {
    echo -e "${YELLOW}正在关闭所有服务...${NC}"

    local screens=("$MAIBOT_SCREEN" "$TTS_SCREEN")
    local services=("MaiBot" "TTS Adapter")

    for i in "${!screens[@]}"; do
        if screen -list | grep -q "${screens[$i]}"; then
            screen -S "${screens[$i]}" -X quit
            echo -e "${GREEN}已关闭 ${services[$i]}${NC}"
        else
            echo -e "${YELLOW}${services[$i]} 未运行${NC}"
        fi
    done
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

# 显示运行状态
check_status() {
    echo -e "\n${BLUE}====== 服务运行状态 ======${NC}"

    local screens=(
        "$MAIBOT_SCREEN:MaiBot"
        "$TTS_SCREEN:TTS Adapter"
    )

    for screen_info in "${screens[@]}"; do
        IFS=':' read -r screen_name service_name <<< "$screen_info"

        if screen -list | grep -q "$screen_name"; then
            echo -e "$service_name: ${GREEN}运行中${NC} (screen: $screen_name)"
        else
            echo -e "$service_name: ${RED}未运行${NC}"
        fi
    done

    echo -e "${BLUE}==========================${NC}"
    echo -e "使用 'screen -R 名称' 查看具体输出"
    echo -e "使用 'screen -list' 查看所有screen会话"
}

# 显示菜单
show_menu() {
    echo -e "\n${GREEN}By 清蒸云鸭@Q113251172${NC}"
    echo -e "\n${BLUE}========== MaiBot 管理脚本 ==========${NC}"
    echo -e "当前目录: $SCRIPT_DIR"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "1.  一键开启所有服务 (MaiBot + TTS)"
    echo -e "2.  仅开启/重启 MaiBot"
    echo -e "3.  仅开启/重启 TTS Adapter"
    echo -e "4.  一键关闭所有服务"
    echo -e "5.  单独关闭 MaiBot"
    echo -e "6.  单独关闭 TTS Adapter"
    echo -e "7.  查看运行状态"
    echo -e "${PURPLE}--- 查看screen窗口 ---${NC}"
    echo -e "8.  查看 MaiBot 窗口"
    echo -e "9.  查看 TTS Adapter 窗口"
    echo -e "10. 查看所有screen会话"
    echo -e "${PURPLE}--- 查看脚本帮助信息 ---${NC}"
    echo -e "11. 帮助信息"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "0.  退出脚本"
    echo -e "${BLUE}=====================================${NC}"
    echo -n "请选择操作 [0-11]: "
}

# 主循环
main() {
    # 检查必要目录和工具
    check_screen
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
                start_tts_adapter
                check_status
                ;;
            2)
                echo -e "\n${GREEN}启动/重启 MaiBot...${NC}"
                start_maibot
                check_status
                ;;
            3)
                echo -e "\n${GREEN}启动/重启 TTS Adapter...${NC}"
                start_tts_adapter
                check_status
                ;;
            4)
                echo -e "\n${YELLOW}关闭所有服务...${NC}"
                stop_all
                check_status
                ;;
            5)
                echo -e "\n${YELLOW}关闭 MaiBot...${NC}"
                stop_service "MaiBot" "$MAIBOT_SCREEN"
                check_status
                ;;
            6)
                echo -e "\n${YELLOW}关闭 TTS Adapter...${NC}"
                stop_service "TTS Adapter" "$TTS_SCREEN"
                check_status
                ;;
            7)
                check_status
                ;;
            8)
                view_screen "$MAIBOT_SCREEN" "MaiBot"
                ;;
            9)
                view_screen "$TTS_SCREEN" "TTS Adapter"
                ;;
            10)
                echo -e "\n${BLUE}所有screen会话:${NC}"
                screen -list
                ;;
            11)
                echo -e "${GREEN}----帮助信息----\n文件分布：${NC}"
                echo -e "Maim-with-u/"
                echo -e "├──MaiBot/"
                echo -e "├──(可选)maimbot_tts_adapter/"
                echo -e "└──Script.sh"
                ;;
            0)
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
