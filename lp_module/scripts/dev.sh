#!/bin/bash

# 开发环境管理脚本
# 用法: ./scripts/dev.sh [command]

set -e

# 检查 Docker 是否可用
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装"
        exit 1
    fi
    if ! docker info &> /dev/null; then
        echo "错误: Docker 服务未运行"
        exit 1
    fi
}

# 构建镜像
build() {
    echo "构建 Docker 镜像..."
    docker compose build
}

# 启动服务
start() {
    echo "启动开发环境..."
    docker compose up -d
    echo "完成! 使用 './scripts/dev.sh shell' 进入容器"
}

# 停止服务
stop() {
    echo "停止开发环境..."
    docker compose down
}

# 进入开发容器
shell() {
    docker compose exec dev /bin/bash
}

# 查看日志
logs() {
    docker compose logs -f ${1:-}
}

# 查看状态
status() {
    docker compose ps
}

# 清理资源
clean() {
    echo "警告: 这将删除所有容器、网络和卷"
    read -p "确认继续? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose down -v --remove-orphans
        echo "清理完成"
    fi
}

# 显示帮助
help() {
    cat << EOF
开发环境管理脚本

用法: $0 [command]

命令:
  build      构建 Docker 镜像
  start      启动开发环境
  stop       停止开发环境
  shell      进入开发容器
  logs       查看日志
  status     查看状态
  clean      清理所有资源
  help       显示帮助信息

示例:
  $0 build       # 构建镜像
  $0 start       # 启动环境
  $0 shell       # 进入容器
EOF
}

# 主函数
main() {
    check_docker
    
    case "${1:-help}" in
        build)   build ;;
        start)   start ;;
        stop)    stop ;;
        shell)   shell ;;
        logs)    logs "$2" ;;
        status)  status ;;
        clean)   clean ;;
        *)       help ;;
    esac
}

main "$@"
