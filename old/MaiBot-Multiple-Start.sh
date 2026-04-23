#!/bin/bash

# 文件分布：
# /root
#   maimai-1/
#   maimai-2/
#   maimai-3/
#   maimai-4/
#   maimai-5/
#   maimai/
#     venv/
#   script.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTANCE_COUNT=6
VENV_PATH="$SCRIPT_DIR/maimai-1/venv/bin/activate"

# 检查screen是否安装
check_screen() {
    if ! command -v screen &> /dev/null; then
        echo -e "${RED}错误: 未找到screen命令，请先安装screen${NC}"
        echo "Ubuntu/Debian: sudo apt install screen"
        echo "CentOS/RHEL: sudo yum install screen"
        exit 1
    fi
}

# 获取实例目录
get_instance_dir() {
    local instance_num=$1
    echo "$SCRIPT_DIR/maimai-$instance_num"
}

# 检查目录是否存在
check_instance_directories() {
    local missing_instances=()
    
    for ((i=1; i<=INSTANCE_COUNT; i++)); do
        local instance_dir=$(get_instance_dir $i)
        if [ ! -d "$instance_dir" ]; then
            missing_instances+=($i)
        fi
    done
    
    if [ ! -f "$VENV_PATH" ]; then
        echo -e "${RED}错误: 虚拟环境不存在: $VENV_PATH${NC}"
        return 1
    fi
    
    if [ ${#missing_instances[@]} -gt 0 ]; then
        echo -e "${YELLOW}警告: 以下实例目录不存在: ${missing_instances[*]}${NC}"
        echo -e "${YELLOW}相关功能将不可用${NC}"
    fi
    
    return 0
}

# 检查并关闭指定名称的screen
kill_screen() {
    local screen_name=$1
    if screen -list | grep -q "$screen_name"; then
        echo -e "${YELLOW}找到已存在的 $screen_name screen，正在关闭...${NC}"
        screen -S "$screen_name" -X quit
        sleep 1
        echo -e "${GREEN}已关闭 $screen_name screen${NC}"
    fi
}

# 查看screen窗口
view_screen() {
    local screen_name=$1
    local service_name=$2
    local instance_num=$3
    
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}正在进入 $service_name (实例$instance_num) 的screen窗口...${NC}"
        echo -e "${YELLOW}提示: 要退出screen窗口并保持程序运行，请按 ${CYAN}Ctrl+A${YELLOW} 然后按 ${CYAN}D${YELLOW}${NC}"
        echo -e "${YELLOW}等待2秒...${NC}"
        sleep 2
        screen -r "$screen_name"
    else
        echo -e "${RED}$service_name (实例$instance_num) 未运行，无法查看${NC}"
    fi
}

# 启动单个实例的MaiBot
start_maibot_instance() {
    local instance_num=$1
    local instance_dir=$(get_instance_dir $instance_num)
    local maibot_dir="$instance_dir/MaiBot"
    local screen_name="mai-main-$instance_num"
    
    if [ ! -d "$instance_dir" ]; then
        echo -e "${RED}错误: 实例 $instance_num 目录不存在，跳过启动${NC}"
        return 1
    fi
    
    if [ ! -d "$maibot_dir" ]; then
        echo -e "${RED}错误: MaiBot目录不存在，跳过启动${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在启动 实例$instance_num 的 MaiBot...${NC}"
    cd "$maibot_dir" || { echo -e "${RED}无法进入 $maibot_dir 目录${NC}"; return 1; }
    
    kill_screen "$screen_name"
    
    screen -dmS "$screen_name" bash -c "
        source '$VENV_PATH';
        echo -e '${GREEN}MaiBot 实例$instance_num 启动中...${NC}';
        python3 bot.py;
        echo -e '${YELLOW}MaiBot 实例$instance_num 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "
    
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}MaiBot 实例$instance_num 启动成功！screen名称: $screen_name${NC}"
        return 0
    else
        echo -e "${RED}MaiBot 实例$instance_num 启动失败${NC}"
        return 1
    fi
}

# 启动单个实例的Adapter
start_adapter_instance() {
    local instance_num=$1
    local instance_dir=$(get_instance_dir $instance_num)
    local adapter_dir="$instance_dir/MaiBot-Napcat-Adapter"
    local screen_name="mai-adapter-$instance_num"
    
    if [ ! -d "$instance_dir" ]; then
        echo -e "${RED}错误: 实例 $instance_num 目录不存在，跳过启动${NC}"
        return 1
    fi
    
    if [ ! -d "$adapter_dir" ]; then
        echo -e "${RED}错误: Adapter目录不存在，跳过启动${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在启动 实例$instance_num 的 Adapter...${NC}"
    cd "$adapter_dir" || { echo -e "${RED}无法进入 $adapter_dir 目录${NC}"; return 1; }
    
    kill_screen "$screen_name"
    
    screen -dmS "$screen_name" bash -c "
        source '$VENV_PATH';
        echo -e '${GREEN}Adapter 实例$instance_num 启动中...${NC}';
        python3 main.py;
        echo -e '${YELLOW}Adapter 实例$instance_num 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "
    
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}Adapter 实例$instance_num 启动成功！screen名称: $screen_name${NC}"
        return 0
    else
        echo -e "${RED}Adapter 实例$instance_num 启动失败${NC}"
        return 1
    fi
}

# 启动单个实例的TTS Adapter
start_tts_adapter_instance() {
    local instance_num=$1
    local instance_dir=$(get_instance_dir $instance_num)
    local tts_adapter_dir="$instance_dir/maimbot_tts_adapter"
    local screen_name="mai-tts-$instance_num"
    
    if [ ! -d "$instance_dir" ]; then
        echo -e "${RED}错误: 实例 $instance_num 目录不存在，跳过启动${NC}"
        return 1
    fi
    
    if [ ! -d "$tts_adapter_dir" ]; then
        echo -e "${RED}错误: TTS Adapter目录不存在，跳过启动${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在启动 实例$instance_num 的 TTS Adapter...${NC}"
    cd "$tts_adapter_dir" || { echo -e "${RED}无法进入 $tts_adapter_dir 目录${NC}"; return 1; }
    
    kill_screen "$screen_name"
    
    screen -dmS "$screen_name" bash -c "
        source '$VENV_PATH';
        echo -e '${GREEN}TTS Adapter 实例$instance_num 启动中...${NC}';
        python3 main.py;
        echo -e '${YELLOW}TTS Adapter 实例$instance_num 已停止，按Ctrl+A然后D退出screen${NC}';
        exec bash
    "
    
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}TTS Adapter 实例$instance_num 启动成功！screen名称: $screen_name${NC}"
        return 0
    else
        echo -e "${RED}TTS Adapter 实例$instance_num 启动失败${NC}"
        return 1
    fi
}

# 批量启动所有实例的某个服务
batch_start_all_instances() {
    local service_type=$1  # "maibot", "adapter", "tts", "all"
    local success_count=0
    local total_count=0
    
    for ((i=1; i<=INSTANCE_COUNT; i++)); do
        local instance_dir=$(get_instance_dir $i)
        if [ -d "$instance_dir" ]; then
            total_count=$((total_count + 1))
            
            case $service_type in
                "maibot" | "all")
                    if start_maibot_instance $i; then
                        success_count=$((success_count + 1))
                    fi
                    ;;
            esac
            
            if [ "$service_type" != "maibot" ]; then
                case $service_type in
                    "adapter" | "all")
                        if start_adapter_instance $i; then
                            success_count=$((success_count + 1))
                        fi
                        ;;
                esac
            fi
            
            if [ "$service_type" != "maibot" ] && [ "$service_type" != "adapter" ]; then
                case $service_type in
                    "tts" | "all")
                        if start_tts_adapter_instance $i; then
                            success_count=$((success_count + 1))
                        fi
                        ;;
                esac
            fi
        fi
    done
    
    echo -e "${GREEN}批量启动完成: 成功 $success_count/${total_count}${NC}"
}

# 关闭所有服务
stop_all_services() {
    echo -e "${YELLOW}正在关闭所有服务...${NC}"
    
    local stopped_count=0
    
    for ((i=1; i<=INSTANCE_COUNT; i++)); do
        local screens=("mai-main-$i" "mai-adapter-$i" "mai-tts-$i")
        
        for screen_name in "${screens[@]}"; do
            if screen -list | grep -q "$screen_name"; then
                screen -S "$screen_name" -X quit
                stopped_count=$((stopped_count + 1))
            fi
        done
    done
    
    echo -e "${GREEN}已关闭 $stopped_count 个服务${NC}"
}

# 关闭指定实例的所有服务
stop_instance() {
    local instance_num=$1
    
    echo -e "${YELLOW}正在关闭实例 $instance_num 的所有服务...${NC}"
    
    local screens=("mai-main-$instance_num" "mai-adapter-$instance_num" "mai-tts-$instance_num")
    local services=("MaiBot" "Adapter" "TTS Adapter")
    
    for i in "${!screens[@]}"; do
        if screen -list | grep -q "${screens[$i]}"; then
            screen -S "${screens[$i]}" -X quit
            echo -e "${GREEN}已关闭实例$instance_num的${services[$i]}${NC}"
        fi
    done
}

# 关闭指定类型的服务
stop_service_type() {
    local service_prefix=$1  # "mai-main", "mai-adapter", "mai-tts"
    local service_name=$2
    
    echo -e "${YELLOW}正在关闭所有实例的 $service_name...${NC}"
    
    local stopped_count=0
    
    for ((i=1; i<=INSTANCE_COUNT; i++)); do
        local screen_name="$service_prefix-$i"
        if screen -list | grep -q "$screen_name"; then
            screen -S "$screen_name" -X quit
            stopped_count=$((stopped_count + 1))
            echo -e "${GREEN}已关闭实例$i的$service_name${NC}"
        fi
    done
    
    echo -e "${GREEN}总计关闭 $stopped_count 个$service_name服务${NC}"
}

# 显示运行状态
check_status() {
    echo -e "\n${BLUE}====== 服务运行状态 ======${NC}"
    
    local total_services=$((INSTANCE_COUNT * 3))
    local running_services=0
    
    for ((i=1; i<=INSTANCE_COUNT; i++)); do
        local instance_dir=$(get_instance_dir $i)
        local instance_status=""
        
        if [ -d "$instance_dir" ]; then
            instance_status="${GREEN}目录存在${NC}"
        else
            instance_status="${RED}目录不存在${NC}"
        fi
        
        echo -e "\n${PURPLE}实例 $i ($instance_status)${NC}"
        
        local screens=(
            "mai-main-$i:MaiBot"
            "mai-adapter-$i:Adapter" 
            "mai-tts-$i:TTS Adapter"
        )
        
        for screen_info in "${screens[@]}"; do
            IFS=':' read -r screen_name service_name <<< "$screen_info"
            
            if screen -list | grep -q "$screen_name"; then
                echo -e "  $service_name: ${GREEN}运行中${NC} ($screen_name)"
                running_services=$((running_services + 1))
            else
                echo -e "  $service_name: ${RED}未运行${NC}"
            fi
        done
    done
    
    echo -e "\n${BLUE}==========================${NC}"
    echo -e "虚拟环境: ${GREEN}$VENV_PATH${NC}"
    echo -e "总计: $running_services/$total_services 个服务运行中"
    echo -e "${BLUE}==========================${NC}"
    echo -e "使用 'screen -R 名称' 查看具体输出"
    echo -e "使用 'screen -list' 查看所有screen会话"
}

# 显示菜单
show_menu() {
    echo -e "\n${GREEN}By 清蒸云鸭@Q113251172${NC}"
    echo -e "\n${BLUE}========== MaiBot 多实例管理脚本 ==========${NC}"
    echo -e "当前目录: $SCRIPT_DIR"
    echo -e "管理实例数: $INSTANCE_COUNT"
    echo -e "虚拟环境: $VENV_PATH"
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${PURPLE}--- 一键批量操作 (所有实例) ---${NC}"
    echo -e "1. 一键开启所有实例的所有服务"
    echo -e "2. 一键开启所有实例的 MaiBot"
    echo -e "3. 一键开启所有实例的 Adapter"
    echo -e "4. 一键开启所有实例的 TTS Adapter"
    echo -e "5. 一键关闭所有实例的所有服务"
    echo -e "${PURPLE}--- 单实例操作 (选择实例号) ---${NC}"
    echo -e "6. 启动指定实例的所有服务"
    echo -e "7. 关闭指定实例的所有服务"
    echo -e "8. 仅启动指定实例的 MaiBot"
    echo -e "9. 仅启动指定实例的 Adapter"
    echo -e "10. 仅启动指定实例的 TTS Adapter"
    echo -e "${PURPLE}--- 批量关闭特定服务 ---${NC}"
    echo -e "11. 关闭所有实例的 MaiBot"
    echo -e "12. 关闭所有实例的 Adapter"
    echo -e "13. 关闭所有实例的 TTS Adapter"
    echo -e "${PURPLE}--- 状态和查看 ---${NC}"
    echo -e "14. 查看所有实例运行状态"
    echo -e "15. 查看所有screen会话"
    echo -e "16. 查看指定实例的screen窗口"
    echo -e "${PURPLE}--- 帮助信息 ---${NC}"
    echo -e "17. 帮助信息"
    echo -e "${BLUE}=============================================${NC}"
    echo -e "0. 退出脚本"
    echo -e "${BLUE}=============================================${NC}"
    echo -n "请选择操作 [0-17]: "
}

# 选择实例号
select_instance() {
    while true; do
        echo -n "请输入实例号 [1-$INSTANCE_COUNT]: "
        read instance_num
        
        if [[ $instance_num =~ ^[0-9]+$ ]] && [ $instance_num -ge 1 ] && [ $instance_num -le $INSTANCE_COUNT ]; then
            local instance_dir=$(get_instance_dir $instance_num)
            if [ ! -d "$instance_dir" ]; then
                echo -e "${RED}实例 $instance_num 目录不存在${NC}"
                continue
            fi
            return $instance_num
        else
            echo -e "${RED}请输入有效的实例号 (1-$INSTANCE_COUNT)${NC}"
        fi
    done
}

# 选择窗口类型
select_window_type() {
    echo -e "\n选择要查看的窗口类型:"
    echo -e "1. MaiBot (mai-main)"
    echo -e "2. Adapter (mai-adapter)"
    echo -e "3. TTS Adapter (mai-tts)"
    echo -n "请选择 [1-3]: "
    read choice
    
    case $choice in
        1) echo "mai-main" ;;
        2) echo "mai-adapter" ;;
        3) echo "mai-tts" ;;
        *) echo "" ;;
    esac
}

# 主循环
main() {
    check_screen
    if ! check_instance_directories; then
        echo -e "${RED}目录检查失败${NC}"
        exit 1
    fi
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                echo -e "\n${GREEN}一键启动所有实例的所有服务...${NC}"
                batch_start_all_instances "all"
                check_status
                ;;
            2)
                echo -e "\n${GREEN}一键启动所有实例的 MaiBot...${NC}"
                batch_start_all_instances "maibot"
                check_status
                ;;
            3)
                echo -e "\n${GREEN}一键启动所有实例的 Adapter...${NC}"
                batch_start_all_instances "adapter"
                check_status
                ;;
            4)
                echo -e "\n${GREEN}一键启动所有实例的 TTS Adapter...${NC}"
                batch_start_all_instances "tts"
                check_status
                ;;
            5)
                echo -e "\n${YELLOW}一键关闭所有实例的所有服务...${NC}"
                stop_all_services
                check_status
                ;;
            6)
                select_instance
                instance_num=$?
                echo -e "\n${GREEN}启动实例 $instance_num 的所有服务...${NC}"
                start_maibot_instance $instance_num
                start_adapter_instance $instance_num
                start_tts_adapter_instance $instance_num
                check_status
                ;;
            7)
                select_instance
                instance_num=$?
                stop_instance $instance_num
                check_status
                ;;
            8)
                select_instance
                instance_num=$?
                start_maibot_instance $instance_num
                check_status
                ;;
            9)
                select_instance
                instance_num=$?
                start_adapter_instance $instance_num
                check_status
                ;;
            10)
                select_instance
                instance_num=$?
                start_tts_adapter_instance $instance_num
                check_status
                ;;
            11)
                stop_service_type "mai-main" "MaiBot"
                check_status
                ;;
            12)
                stop_service_type "mai-adapter" "Adapter"
                check_status
                ;;
            13)
                stop_service_type "mai-tts" "TTS Adapter"
                check_status
                ;;
            14)
                check_status
                ;;
            15)
                echo -e "\n${BLUE}所有screen会话:${NC}"
                screen -list
                ;;
            16)
                select_instance
                instance_num=$?
                window_type=$(select_window_type)
                
                if [ -n "$window_type" ]; then
                    screen_name="$window_type-$instance_num"
                    case $window_type in
                        "mai-main") service_name="MaiBot" ;;
                        "mai-adapter") service_name="Adapter" ;;
                        "mai-tts") service_name="TTS Adapter" ;;
                    esac
                    view_screen "$screen_name" "$service_name" "$instance_num"
                else
                    echo -e "${RED}选择无效${NC}"
                fi
                ;;
            17)
                echo -e "${GREEN}----帮助信息----\n文件分布：${NC}"
                echo -e "/root"
                echo -e "├──maimai-1/"
                echo -e "│  ├──MaiBot/"
                echo -e "│  ├──MaiBot-Napcat-Adapter/"
                echo -e "│  └──(可选)maimbot_tts_adapter/"
                echo -e "├──maimai-2/"
                echo -e "│  └──...(类似结构)"
                echo -e "..."
                echo -e "├──maimai-5/"
                echo -e "├──maimai/"
                echo -e "│  └──venv/  (共享虚拟环境)"
                echo -e "└──script.sh"
                echo -e "\n${YELLOW}screen命名规则:${NC}"
                echo -e "MaiBot: mai-main-1, mai-main-2, ..."
                echo -e "Adapter: mai-adapter-1, mai-adapter-2, ..."
                echo -e "TTS: mai-tts-1, mai-tts-2, ..."
                echo -e "\n${YELLOW}虚拟环境:${NC}"
                echo -e "所有实例共享: /root/maimai/venv/bin/activate"
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
echo -e "${GREEN}MaiBot 多实例管理脚本启动中...${NC}"
main