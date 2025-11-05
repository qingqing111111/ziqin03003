#!/bin/bash

# 定义IP地址组
IP_GROUPS=(
    "18.25.10.01"
    "18.25.10.01_zdh"
    "18.25.40.01"
    "18.25.40.01_zdh"
)

# 18.25.10.01 组的IP地址
IP_GROUP_18_25_10_01=(
    "172.20.8.3"
    "172.20.8.4"
    "172.20.8.5"
    "172.20.8.7"
    "172.20.8.8"
    "172.20.8.9"
    "172.20.8.10"
    "172.20.8.11"
    "172.20.8.12"
)

# 18.25.10.01_zdh 组的IP地址
IP_GROUP_18_25_10_01_ZDH=(
    "172.20.8.7"
    "172.20.8.8"
    "172.20.8.9"
    "172.20.8.10"
    "172.20.8.11"
    "172.20.8.12"
)

# 18.25.40.01 组的IP地址
IP_GROUP_18_25_40_01=(
    "192.168.3.11"
    "192.168.3.12"
    "192.168.3.13"
    "192.168.3.14"
    "192.168.3.200"
    "192.168.3.201"
    "192.168.3.202"
    "192.168.3.203"
    "192.168.3.204"
    "192.168.3.205"
)

# 18.25.40.01_zdh 组的IP地址
IP_GROUP_18_25_40_01_ZDH=(
    "192.168.3.200"
    "192.168.3.201"
    "192.168.3.202"
    "192.168.3.203"
    "192.168.3.204"
    "192.168.3.205"
)

# MySQL Connector 相关变量
MYSQL_LOCAL_ZIP_PATH="./mysql-connector-j-8.0.33.zip"
MYSQL_LOCAL_JAR_PATH="./mysql-connector-j-8.0.33.jar"
MYSQL_POD_NAME_PATTERN="vmax-o-adma-pro"
MYSQL_CONTAINER_NAME="vmax-o-adma-pro"
MYSQL_TARGET_DIR="/home/zxvmax/app/vmax-o-adma-pro/plugins/thirdparty"
MYSQL_TARGET_FILENAME="mysql-connector-j-8.0.33.jar"
MYSQL_NODE_USER="ubuntu"
MYSQL_NODE_PASSWORD="UbuntU1!2@3#4$"

# 时钟同步相关变量
CLOCK_PASSWORD="ZXvmax_2018"

# 删除ZDH节点文件相关变量
ZDH_DELETE_PATHS=(
    "/data4/zdh/trino/plugin/mysql/*"
    "/data4/zdh/trino/plugin/mysql/"
)

# 检查kubectl是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "错误: 未找到 kubectl 命令"
        exit 1
    fi
}

# 显示菜单
show_menu() {
    echo "=== Kubernetes 容器管理脚本 ==="
    echo "1. 查询容器"
    echo "2. 进入容器"
    echo "3. 进入dataintegration容器查看日志"
    echo "4. 时间同步"
    echo "5. 检查节点连通性"
    echo "6. 上传adma插件MySQL Connector"
    echo "7. 删除ZDH节点文件"
    echo "8. 查看/var/log/oki/日志信息"
    echo "9. 重启reagent"
    echo -n "请选择操作 (1-9)【q退出】: "
}

# 查询容器 - 保持原样输出
search_pod() {
    while true; do
        echo -n "请输入容器名称关键字 (输入 'all' 查看所有容器): "
        read pod_keyword

        if [ -z "$pod_keyword" ]; then
            echo "错误: 容器名称不能为空"
            continue
        fi

        if [ "$pod_keyword" = "all" ]; then
            echo "正在查询所有命名空间..."

            # 显示可用的命名空间列表
            echo "可用的命名空间:"
            echo "========================================="
            kubectl get namespaces | awk '{print $1}' | tail -n +2
            echo "========================================="

            while true; do
                echo -n "请输入命名空间名称 (输入 'all' 查看所有命名空间的容器): "
                read namespace

                if [ -z "$namespace" ]; then
                    echo "错误: 命名空间不能为空"
                    continue
                fi

                if [ "$namespace" = "all" ]; then
                    echo "正在查询所有命名空间的所有容器..."
                    echo "========================================="
                    kubectl get pod -A
                    echo "========================================="
                    break
                else
                    # 检查命名空间是否存在
                    if kubectl get namespace "$namespace" &> /dev/null; then
                        echo "正在查询命名空间 '$namespace' 的所有容器..."
                        echo "========================================="
                        kubectl get pod -n "$namespace"
                        echo "========================================="
                        break
                    else
                        echo "错误: 命名空间 '$namespace' 不存在"
                        continue
                    fi
                fi
            done
            break
        else
            echo "正在查询包含 '$pod_keyword' 的容器..."
            echo "========================================="
            kubectl get pod -A | grep "$pod_keyword"
            echo "========================================="
            break
        fi
    done
}

# 进入容器
enter_pod() {
    while true; do
        echo -n "请输入容器名称关键字: "
        read pod_keyword

        if [ -z "$pod_keyword" ]; then
            echo "错误: 容器名称不能为空"
            continue
        fi

        echo "正在搜索包含 '$pod_keyword' 的容器..."

        # 获取匹配的pod列表
        pod_list=$(kubectl get pod -A | grep "$pod_keyword")

        if [ -z "$pod_list" ]; then
            echo "没有找到包含 '$pod_keyword' 的容器"
            continue  # 重新提示输入
        fi

        # 显示匹配的容器列表（保持原格式）
        echo "找到以下匹配的容器:"
        echo "========================================="
        echo "$pod_list"
        echo "========================================="

        # 统计行数
        count=$(echo "$pod_list" | wc -l)

        if [ $count -eq 0 ]; then
            echo "没有找到匹配的容器"
            continue  # 重新提示输入
        elif [ $count -eq 1 ]; then
            # 只有一个匹配项，自动选择
            line=$(echo "$pod_list" | sed -n "1p")
            namespace=$(echo $line | awk '{print $1}')
            pod_name=$(echo $line | awk '{print $2}')

            echo "只有一个匹配项，自动选择: $pod_name (命名空间: $namespace)"
            echo "使用 Ctrl+D 或输入 'exit' 退出容器"
            echo "========================================="

            # 进入容器
            kubectl exec -it "$pod_name" -n "$namespace" -- sh
            break
        else
            # 多个匹配项，提示用户重新输入更精确的关键字
            echo "发现 $count 个匹配的容器，请使用更精确的关键字进行搜索"
            echo "========================================="
            continue  # 重新提示输入
        fi
    done
}

# 进入dataintegration容器查看日志
enter_datai_logs() {
    echo "正在搜索包含 'datai' 的容器..."

    # 获取匹配的pod列表
    pod_list=$(kubectl get pod -A | grep "datai")

    if [ -z "$pod_list" ]; then
        echo "没有找到包含 'datai' 的容器"
        return 1
    fi

    # 显示匹配的容器列表
    echo "找到以下匹配的容器:"
    echo "========================================="
    echo "$pod_list"
    echo "========================================="

    # 统计行数
    count=$(echo "$pod_list" | wc -l)

    if [ $count -eq 0 ]; then
        echo "没有找到匹配的容器"
        return 1
    elif [ $count -eq 1 ]; then
        selected=1
        echo "只有一个匹配项，自动选择..."
    else
        while true; do
            echo -n "请选择要进入的容器编号 (1-$count): "
            read selected

            if ! [[ "$selected" =~ ^[0-9]+$ ]] || [ "$selected" -lt 1 ] || [ "$selected" -gt "$count" ]; then
                echo "错误: 无效的选择，请输入 1-$count"
                continue
            fi
            break
        done
    fi

    # 获取选择的容器信息
    line=$(echo "$pod_list" | sed -n "${selected}p")
    namespace=$(echo $line | awk '{print $1}')
    pod_name=$(echo $line | awk '{print $2}')

    echo "正在进入容器: $pod_name (命名空间: $namespace)"
    echo "正在查看日志文件: /opt/vmax/dataintegration/logs/dataintegration.info.log"
    echo "使用 Ctrl+C 退出日志查看"
    echo "========================================="

    # 直接进入容器并查看日志（使用正确的路径）
    kubectl exec -it "$pod_name" -n "$namespace" -- sh -c "cd /opt/vmax/dataintegration/logs && tail -f dataintegration.info.log"
}

# 时间同步功能
clock_alignment() {
    echo "=== 时间同步 ==="

    # 选择IP组
    while true; do
        echo "=== 选择IP组 ==="
        for i in "${!IP_GROUPS[@]}"; do
            echo "$(($i+1)). ${IP_GROUPS[$i]}"
        done
        echo -n "请选择IP组 (1-${#IP_GROUPS[@]}, 输入 'q' 退出): "
        read choice

        # 检查是否要退出
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "已退出时间同步功能"
            return 1
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#IP_GROUPS[@]}" ]; then
            echo "错误: 无效的选择，请输入 1-${#IP_GROUPS[@]} 或输入 'q' 退出"
            echo
            continue
        fi

        selected_group="${IP_GROUPS[$(($choice-1))]}"
        echo "已选择: $selected_group"
        break
    done

    # 获取对应的IP数组
    case $selected_group in
        "18.25.10.01")
            ips=("${IP_GROUP_18_25_10_01[@]}")
            ;;
        "18.25.10.01_zdh")
            ips=("${IP_GROUP_18_25_10_01_ZDH[@]}")
            ;;
        "18.25.40.01")
            ips=("${IP_GROUP_18_25_40_01[@]}")
            ;;
        "18.25.40.01_zdh")
            ips=("${IP_GROUP_18_25_40_01_ZDH[@]}")
            ;;
        *)
            echo "错误: 未知的IP组"
            return 1
            ;;
    esac

    if [ ${#ips[@]} -eq 0 ]; then
        echo "错误: 没有找到有效的IP地址"
        return 1
    fi

    echo "找到 ${#ips[@]} 个IP地址"
    echo "开始时间同步..."
    echo

    # 获取当前时间戳
    current_time=$(date +%s)
    echo "当前时间戳: $current_time"
    echo

    success_count=0
    for ip in "${ips[@]}"; do
        echo -n "正在同步 $ip ... "

        # 设置时间
        if sshpass -p "$CLOCK_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$ip "date -s @$current_time" &> /dev/null; then
            echo "✅ 成功"
            ((success_count++))
        else
            echo "❌ 失败"
        fi
    done

    echo "==============================="
    echo "时间同步完成！成功: $success_count/${#ips[@]}"

    # 添加定时任务
    add_cron_job
}

# 添加定时任务
add_cron_job() {
    echo
    echo "=== 添加定时任务 ==="

    if crontab -l | grep -q "clock_alignment"; then
        echo "定时任务已存在"
    else
        filepath=$(pwd)
        crontab -l > $filepath/cron.txt 2>/dev/null || true
        echo "0 * * * * cd $filepath && bash -c 'source $0 && clock_alignment_auto'" >> $filepath/cron.txt
        crontab $filepath/cron.txt
        rm -f $filepath/cron.txt
        echo "定时任务添加成功：每小时执行一次时间同步"
    fi
}

# 自动时间同步（供定时任务使用）
clock_alignment_auto() {
    # 这里可以设置默认的IP组，比如第一个组
    selected_group="${IP_GROUPS[0]}"

    case $selected_group in
        "18.25.10.01")
            ips=("${IP_GROUP_18_25_10_01[@]}")
            ;;
        "18.25.10.01_zdh")
            ips=("${IP_GROUP_18_25_10_01_ZDH[@]}")
            ;;
        "18.25.40.01")
            ips=("${IP_GROUP_18_25_40_01[@]}")
            ;;
        "18.25.40.01_zdh")
            ips=("${IP_GROUP_18_25_40_01_ZDH[@]}")
            ;;
        *)
            return 1
            ;;
    esac

    current_time=$(date +%s)
    echo "$(date '+%Y-%m-%d %H:%M:%S') 开始自动时间同步..."

    for ip in "${ips[@]}"; do
        sshpass -p "$CLOCK_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$ip "date -s @$current_time" &> /dev/null
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') 自动时间同步完成"
}

# 检查节点连通性
check_node_connectivity() {
    echo "=== 检查节点连通性 ==="

    # 选择IP组
    while true; do
        echo "=== 选择IP组 ==="
        for i in "${!IP_GROUPS[@]}"; do
            echo "$(($i+1)). ${IP_GROUPS[$i]}"
        done
        echo -n "请选择IP组 (1-${#IP_GROUPS[@]}, 输入 'q' 退出): "
        read choice

        # 检查是否要退出
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "已退出检查节点连通性功能"
            return 1
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#IP_GROUPS[@]}" ]; then
            echo "错误: 无效的选择，请输入 1-${#IP_GROUPS[@]} 或输入 'q' 退出"
            echo
            continue
        fi

        selected_group="${IP_GROUPS[$(($choice-1))]}"
        echo "已选择: $selected_group"
        break
    done

    echo "==============================="

    # 获取对应的IP数组
    case $selected_group in
        "18.25.10.01")
            ips=("${IP_GROUP_18_25_10_01[@]}")
            ;;
        "18.25.10.01_zdh")
            ips=("${IP_GROUP_18_25_10_01_ZDH[@]}")
            ;;
        "18.25.40.01")
            ips=("${IP_GROUP_18_25_40_01[@]}")
            ;;
        "18.25.40.01_zdh")
            ips=("${IP_GROUP_18_25_40_01_ZDH[@]}")
            ;;
        *)
            echo "错误: 未知的IP组"
            return 1
            ;;
    esac

    if [ ${#ips[@]} -eq 0 ]; then
        echo "错误: 没有找到有效的IP地址"
        return 1
    fi

    echo "找到 ${#ips[@]} 个IP地址"
    echo "开始测试连通性..."
    echo

    success_count=0
    for ip in "${ips[@]}"; do
        echo -n "测试 $ip ... "
        if ping -c 2 -W 2 "$ip" &> /dev/null; then
            echo "✅ 成功"
            ((success_count++))
        else
            echo "❌ 失败"
        fi
    done

    echo "==============================="
    echo "测试完成！成功: $success_count/${#ips[@]}"
}

# 确认操作
confirm_action() {
    local action="$1"
    local ip_count="$2"
    local group_name="$3"

    echo "========================================="
    echo "⚠️  警告: 您即将执行重要操作"
    echo "操作: $action"
    echo "影响节点数: $ip_count 个"
    echo "IP组: $group_name"
    echo "========================================="
    echo -n "请输入 'confirm' 确认执行，或输入其他内容取消: "
    read confirmation

    if [ "$confirmation" = "confirm" ]; then
        return 0
    else
        echo "操作已取消"
        return 1
    fi
}

# 查看/var/log/oki/日志信息
view_oki_logs() {
    echo "=== 查看/var/log/oki/日志信息 ==="

    # 检查/var/log/oki/目录是否存在
    echo "检查/var/log/oki/目录是否存在..."
    if [ ! -d "/var/log/oki/" ]; then
        echo "错误: 当前机器中不存在 /var/log/oki/ 目录"
        return 1
    fi

    # 获取/var/log/oki/目录下的时间目录列表，按时间排序（时间最近的在最下面）
    echo "获取/var/log/oki/目录内容..."
    dir_list=$(ls -1t /var/log/oki/ 2>/dev/null)

    if [ -z "$dir_list" ]; then
        echo "错误: /var/log/oki/目录为空或无法访问"
        return 1
    fi

    # 将目录列表转换为数组
    IFS=$'\n' read -d '' -r -a dir_array <<< "$dir_list"

    # 只取最近的8个目录
    if [ ${#dir_array[@]} -gt 8 ]; then
        dir_array=("${dir_array[@]:0:8}")
    fi

    # 反转数组，让时间最近的显示在最下面（对应数字大的选项）
    reversed_array=()
    for ((i=${#dir_array[@]}-1; i>=0; i--)); do
        reversed_array+=("${dir_array[i]}")
    done

    # 显示目录列表供用户选择
    echo "可用的日志目录 (时间最近的在最下面):"
    echo "========================================="
    for i in "${!reversed_array[@]}"; do
        echo "$(($i+1)). ${reversed_array[$i]}"
    done
    echo "========================================="

    # 用户选择目录
    while true; do
        echo -n "请选择要查看的日志目录编号 (1-${#reversed_array[@]}, 输入 'q' 返回): "
        read dir_choice

        if [ "$dir_choice" = "q" ] || [ "$dir_choice" = "Q" ]; then
            echo "返回主菜单"
            return 0
        fi

        if ! [[ "$dir_choice" =~ ^[0-9]+$ ]] || [ "$dir_choice" -lt 1 ] || [ "$dir_choice" -gt "${#reversed_array[@]}" ]; then
            echo "错误: 无效的选择，请输入 1-${#reversed_array[@]} 或输入 'q' 返回"
            continue
        fi

        selected_dir="${reversed_array[$(($dir_choice-1))]}"
        break
    done

    # 检查日志文件是否存在
    echo "检查日志文件是否存在: /var/log/oki/$selected_dir/oki-cli.log"
    if [ ! -f "/var/log/oki/$selected_dir/oki-cli.log" ]; then
        echo "错误: 日志文件 /var/log/oki/$selected_dir/oki-cli.log 不存在"
        echo "该目录下的文件有:"
        ls -la "/var/log/oki/$selected_dir/" 2>/dev/null || echo "无法访问目录"

        # 显示该目录下所有文件供选择
        echo "请选择要查看的文件:"
        file_list=$(ls -1 "/var/log/oki/$selected_dir/" 2>/dev/null)
        IFS=$'\n' read -d '' -r -a file_array <<< "$file_list"

        for i in "${!file_array[@]}"; do
            echo "$(($i+1)). ${file_array[$i]}"
        done

        echo -n "请选择文件编号 (1-${#file_array[@]}): "
        read file_choice

        if [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -ge 1 ] && [ "$file_choice" -le "${#file_array[@]}" ]; then
            selected_file="${file_array[$(($file_choice-1))]}"
            echo "========================================="
            echo "正在查看日志: /var/log/oki/$selected_dir/$selected_file"
            echo "使用 Ctrl+C 退出查看"
            echo "========================================="
            cat "/var/log/oki/$selected_dir/$selected_file"
        else
            echo "无效的文件选择"
            return 1
        fi
    else
        # 查看日志文件
        echo "========================================="
        echo "正在查看日志: /var/log/oki/$selected_dir/oki-cli.log"
        echo "使用 Ctrl+C 退出查看"
        echo "========================================="

        cat "/var/log/oki/$selected_dir/oki-cli.log"
    fi
}

# 获取调度节点信息
get_schedule_node() {
    local namespace=$1
    local pod_name=$2

    echo "正在获取Pod的调度节点信息..."
    NODE=$(kubectl get pod -n "$namespace" "$pod_name" -o jsonpath='{.spec.nodeName}')
    if [ -z "$NODE" ]; then
        echo "❌ 错误: 无法获取Pod $pod_name 的调度节点"
        return 1
    fi
    echo "Pod $pod_name 运行在节点: $NODE"
    return 0
}

# 重启容器
restart_containers() {
    local namespace=$1
    local pod_name=$2
    local node=$3

    echo "准备在节点 $node 上重启容器..."

    # 检查是否能够SSH连接到节点
    if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$MYSQL_NODE_USER@$node" "echo '连接成功'" &> /dev/null; then
        echo "❌ 错误: 无法SSH连接到节点 $node"
        echo "请检查网络连接或节点状态"
        return 1
    fi

    # 在调度节点上执行docker命令
    echo "在节点 $node 上查找相关容器..."
    CONTAINER_IDS=$(ssh "$MYSQL_NODE_USER@$node" "sudo docker ps -a | grep '$pod_name' | grep -v -E 'mon|Exited|admin' | awk '{print \$1}'")

    if [ -z "$CONTAINER_IDS" ]; then
        echo "❌ 错误: 在节点 $node 上未找到运行中的相关容器"
        return 1
    fi

    echo "找到容器: $CONTAINER_IDS"
    echo "正在重启容器..."

    # 重启所有相关容器
    for container_id in $CONTAINER_IDS; do
        echo "重启容器: $container_id"
        ssh "$MYSQL_NODE_USER@$node" "sudo docker restart $container_id"
        if [ $? -eq 0 ]; then
            echo "✅ 容器 $container_id 重启成功"
        else
            echo "❌ 错误: 容器 $container_id 重启失败"
            return 1
        fi
    done

    echo "✅ 所有容器重启完成"
    return 0
}

# 上传adma插件MySQL Connector
update_mysql_connector() {
    echo "=== 上传adma插件MySQL Connector ==="

    # 检查本地ZIP文件是否存在，如果存在则解压
    if [ -f "$MYSQL_LOCAL_ZIP_PATH" ]; then
        echo "发现ZIP文件，正在解压..."
        unzip -o "$MYSQL_LOCAL_ZIP_PATH"
        echo "解压完成"
    fi

    # 检查本地JAR文件是否存在
    if [ ! -f "$MYSQL_LOCAL_JAR_PATH" ]; then
        echo "错误: 本地JAR文件不存在: $MYSQL_LOCAL_JAR_PATH"
        echo "请确保 mysql-connector-j-8.0.33.jar 文件存在于当前目录"
        return 1
    fi

    # 定义要处理的命名空间列表
    NAMESPACES=("dtcluster1" "dtcluster2")

    local success_count=0
    local fail_count=0

    # 遍历所有命名空间
    for namespace in "${NAMESPACES[@]}"; do
        echo "========================================="
        echo "正在处理命名空间: $namespace"

        # 查找包含指定名称的Pod
        echo "正在查找包含 '$MYSQL_POD_NAME_PATTERN' 的Pod..."
        POD_INFO=$(kubectl get pods -n "$namespace" --no-headers | grep "$MYSQL_POD_NAME_PATTERN" | grep -v "mon" | head -n 1)

        if [ -z "$POD_INFO" ]; then
            echo "警告: 在命名空间 '$namespace' 中未找到包含 '$MYSQL_POD_NAME_PATTERN' 的Pod"
            ((fail_count++))
            continue
        fi

        # 提取Pod名称
        POD_NAME=$(echo "$POD_INFO" | awk '{print $1}')

        echo "找到Pod: $POD_NAME, 命名空间: $namespace"

        # 检查目标目录是否存在，如果不存在则创建
        echo "检查目标目录是否存在..."
        kubectl exec -n "$namespace" "$POD_NAME" -c "$MYSQL_CONTAINER_NAME" -- \
            sh -c "mkdir -p $MYSQL_TARGET_DIR || echo '目录已存在或无法创建'"

        # 复制文件到Pod
        echo "正在复制文件到Pod..."
        if kubectl cp -n "$namespace" -c "$MYSQL_CONTAINER_NAME" \
            "$MYSQL_LOCAL_JAR_PATH" \
            "$POD_NAME:$MYSQL_TARGET_DIR/$MYSQL_TARGET_FILENAME"; then

            echo "文件复制到 $namespace 成功!"

            # 验证文件是否已复制
            echo "验证文件是否存在..."
            kubectl exec -n "$namespace" "$POD_NAME" -c "$MYSQL_CONTAINER_NAME" -- \
                ls -la "$MYSQL_TARGET_DIR/$MYSQL_TARGET_FILENAME"

            # 获取调度节点并重启容器
            echo "开始重启容器以应用更改..."
            if get_schedule_node "$namespace" "$POD_NAME"; then
                if restart_containers "$namespace" "$POD_NAME" "$NODE"; then
                    echo "✅ $namespace 文件上传并容器重启完成"
                    ((success_count++))
                else
                    echo "❌ 错误: $namespace 容器重启失败"
                    ((fail_count++))
                fi
            else
                echo "❌ 错误: $namespace 无法获取调度节点信息"
                ((fail_count++))
            fi
        else
            echo "❌ 错误: 文件复制到 $namespace 失败"
            ((fail_count++))
        fi

        echo "----------------------------------------"
    done

    echo "========================================="
    echo "操作完成!"
    echo "✅ 成功: $success_count 个命名空间"
    echo "❌ 失败: $fail_count 个命名空间"

    if [ $success_count -gt 0 ]; then
        echo "✅ MySQL Connector 已成功上传并重启相关容器!"
    fi
}

# 重启reagent
restart_reagent() {
    echo "=== 重启reagent ==="
    
    # 选择IP组
    while true; do
        echo "=== 选择IP组 ==="
        for i in "${!IP_GROUPS[@]}"; do
            echo "$(($i+1)). ${IP_GROUPS[$i]}"
        done
        echo -n "请选择IP组 (1-${#IP_GROUPS[@]}, 输入 'q' 退出): "
        read choice
        
        # 检查是否要退出
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "已退出重启reagent功能"
            return 1
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#IP_GROUPS[@]}" ]; then
            echo "错误: 无效的选择，请输入 1-${#IP_GROUPS[@]} 或输入 'q' 退出"
            echo
            continue
        fi
        
        selected_group="${IP_GROUPS[$(($choice-1))]}"
        echo "已选择: $selected_group"
        break
    done

    # 获取对应的IP数组
    case $selected_group in
        "18.25.10.01")
            VIRTUAL_MACHINES=("${IP_GROUP_18_25_10_01[@]}")
            ;;
        "18.25.10.01_zdh")
            VIRTUAL_MACHINES=("${IP_GROUP_18_25_10_01_ZDH[@]}")
            ;;
        "18.25.40.01")
            VIRTUAL_MACHINES=("${IP_GROUP_18_25_40_01[@]}")
            ;;
        "18.25.40.01_zdh")
            VIRTUAL_MACHINES=("${IP_GROUP_18_25_40_01_ZDH[@]}")
            ;;
        *)
            echo "错误: 未知的IP组"
            return 1
            ;;
    esac

    # 显示将要操作的节点信息
    echo "========================================="
    echo "即将重启以下节点的reagent服务:"
    for ip in "${VIRTUAL_MACHINES[@]}"; do
        echo "  - $ip"
    done
    echo "========================================="

    # 请求确认
    if ! confirm_action "重启reagent服务" "${#VIRTUAL_MACHINES[@]}" "$selected_group"; then
        return 1
    fi

    # 定义登录信息
    USERNAME="root"
    PASSWORD="ZXvmax_2018"

    # 定义要执行的命令
    RESTART_CMD="/opt/Feagle/dapmanager-agent/service/agent/bin/restart.sh"

    # 日志文件路径
    LOG_FILE="/tmp/restart_agent_$(date +%Y%m%d_%H%M%S).log"

    # 检查是否安装了sshpass
    check_sshpass() {
        if ! command -v sshpass &> /dev/null; then
            echo "错误: 未安装sshpass，请先安装: yum install sshpass 或 apt-get install sshpass"
            return 1
        fi
        echo "sshpass 已安装: $(sshpass -V 2>&1)"
    }

    # 测试单台机器连接
    test_connection() {
        local vm_ip="$1"
        echo "测试连接到 $vm_ip..."
        
        # 测试SSH连接
        timeout 10s sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            -o BatchMode=no "$USERNAME@$vm_ip" "echo '连接测试成功'" 2>&1
        
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "连接测试: 成功"
            return 0
        else
            echo "连接测试: 失败 (退出码: $exit_code)"
            return 1
        fi
    }

    # 函数：在单台虚拟机执行命令
    execute_on_vm() {
        local vm_ip="$1"
        local cmd="$2"
        
        echo "$(date '+%Y-%m-%d %H:%M:%S'): 正在虚拟机 $vm_ip 上执行重启命令..." | tee -a "$LOG_FILE"
        
        # 使用sshpass执行远程命令
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$USERNAME@$vm_ip" "$cmd" 2>&1 | tee -a "$LOG_FILE"
        
        # 检查执行结果
        local exit_code=${PIPESTATUS[0]}
        if [ $exit_code -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S'): $vm_ip 执行成功" | tee -a "$LOG_FILE"
            return 0
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S'): $vm_ip 执行失败，退出码: $exit_code" | tee -a "$LOG_FILE"
            return 1
        fi
    }

    # 主执行逻辑
    echo "===== 开始执行重启脚本 ====="
    if ! check_sshpass; then
        return 1
    fi
    
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "目标脚本: $RESTART_CMD" | tee -a "$LOG_FILE"
    echo "虚拟机数量: ${#VIRTUAL_MACHINES[@]}" | tee -a "$LOG_FILE"
    echo "IP组: $selected_group" | tee -a "$LOG_FILE"
    
    # 显示读取到的IP列表
    echo "IP列表:"
    for ip in "${VIRTUAL_MACHINES[@]}"; do
        echo "  - $ip"
    done
    
    # 先测试第一台机器的连接
    if [ ${#VIRTUAL_MACHINES[@]} -gt 0 ]; then
        echo "正在测试连接..."
        test_connection "${VIRTUAL_MACHINES[0]}"
    else
        echo "错误: 没有找到有效的IP地址"
        return 1
    fi
    
    local success_count=0
    local fail_count=0
    
    echo "开始正式执行..."
    # 遍历所有虚拟机
    for vm_ip in "${VIRTUAL_MACHINES[@]}"; do
        echo "正在处理: $vm_ip"
        if execute_on_vm "$vm_ip" "$RESTART_CMD"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo "----------------------------------------"
        sleep 1  # 添加短暂延迟
    done
    
    # 输出汇总结果
    echo "===== 执行完成 =====" | tee -a "$LOG_FILE"
    echo "总虚拟机数: ${#VIRTUAL_MACHINES[@]}" | tee -a "$LOG_FILE"
    echo "成功: $success_count" | tee -a "$LOG_FILE"
    echo "失败: $fail_count" | tee -a "$LOG_FILE"
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "详细日志请查看: $LOG_FILE"
}

# 删除ZDH节点文件
delete_zdh_files() {
    echo "=== 删除ZDH节点文件 ==="

    # 选择IP组
    while true; do
        echo "=== 选择IP组 ==="
        for i in "${!IP_GROUPS[@]}"; do
            echo "$(($i+1)). ${IP_GROUPS[$i]}"
        done
        echo -n "请选择IP组 (1-${#IP_GROUPS[@]}, 输入 'q' 退出): "
        read choice

        # 检查是否要退出
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "已退出删除ZDH节点文件功能"
            return 1
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#IP_GROUPS[@]}" ]; then
            echo "错误: 无效的选择，请输入 1-${#IP_GROUPS[@]} 或输入 'q' 退出"
            echo
            continue
        fi

        selected_group="${IP_GROUPS[$(($choice-1))]}"
        echo "已选择: $selected_group"
        break
    done

    # 获取对应的IP数组
    case $selected_group in
        "18.25.10.01")
            ips=("${IP_GROUP_18_25_10_01[@]}")
            ;;
        "18.25.10.01_zdh")
            ips=("${IP_GROUP_18_25_10_01_ZDH[@]}")
            ;;
        "18.25.40.01")
            ips=("${IP_GROUP_18_25_40_01[@]}")
            ;;
        "18.25.40.01_zdh")
            ips=("${IP_GROUP_18_25_40_01_ZDH[@]}")
            ;;
        *)
            echo "错误: 未知的IP组"
            return 1
            ;;
    esac

    if [ ${#ips[@]} -eq 0 ]; then
        echo "错误: 没有找到有效的IP地址"
        return 1
    fi

    # 显示将要删除的文件和节点信息
    echo "========================================="
    echo "⚠️  警告: 您即将执行文件删除操作"
    echo "操作: 删除ZDH节点特定文件"
    echo "影响节点数: ${#ips[@]} 个"
    echo "IP组: $selected_group"
    echo "将要删除的文件:"
    for path in "${ZDH_DELETE_PATHS[@]}"; do
        echo "  - $path"
    done
    echo "========================================="

    # 请求确认
    if ! confirm_action "删除ZDH节点文件" "${#ips[@]}" "$selected_group"; then
        return 1
    fi

    echo "开始删除文件..."
    echo

    # 定义登录信息
    USERNAME="root"
    PASSWORD="ZXvmax_2018"

    # 日志文件路径
    LOG_FILE="/tmp/delete_zdh_files_$(date +%Y%m%d_%H%M%S).log"

    success_count=0
    fail_count=0

    # 遍历所有IP地址
    for ip in "${ips[@]}"; do
        echo -n "正在处理 $ip ... "

        # 执行删除命令
        if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USERNAME@$ip" \
            "rm -rf ${ZDH_DELETE_PATHS[*]} && echo '文件删除成功'" &> /dev/null; then
            
            echo "✅ 成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $ip: 文件删除成功" >> "$LOG_FILE"
            ((success_count++))
        else
            echo "❌ 失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $ip: 文件删除失败" >> "$LOG_FILE"
            ((fail_count++))
        fi
    done

    echo "========================================="
    echo "删除操作完成!"
    echo "✅ 成功: $success_count/${#ips[@]}"
    echo "❌ 失败: $fail_count/${#ips[@]}"
    echo "详细日志请查看: $LOG_FILE"
}

# 主函数
main() {
    clear
    check_kubectl
    
    while true; do
        show_menu
        read choice
        
        # 检查是否要退出
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            clear
            exit 0
        fi
        
        case $choice in
            1) search_pod ;;
            2) enter_pod ;;
            3) enter_datai_logs ;;
            4) clock_alignment ;;
            5) check_node_connectivity ;;
            6) update_mysql_connector ;;
            7) delete_zdh_files ;;
            8) view_oki_logs ;;
            9) restart_reagent ;;
            *) 
                echo "错误: 无效的选择，请输入 1-9 或 q 退出"
                ;;
        esac
        
        echo
        echo -n "按回车键继续..."
        read
        clear
    done
}

# 启动脚本
main