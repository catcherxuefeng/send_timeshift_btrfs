#!/bin/bash
# encoding: utf-8.0
#
# 这个脚本可以发送 btrfs文件系统下timeshift生成的快照到外置存储设备,实现真正的"备份"
# 
# 说明:
# 0.这个脚本只能在ubuntu及其衍生版使用
# 1.目标文件系统必须是btrfs
# 2.第一次备份必须手动执行 
# 3.依赖:pv 
#  
# Usage: sudo bash backup_timeshift.sh
#
# Author: catcherxuefeng
# Date: 2023-12-09
#

# 定义源目标文件夹
s_dir=$(find /run/timeshift/ -maxdepth 4 -type d -name "snapshots")
t_dir="/media/catcher/catcher/catcher_backup/"

# 发送快照函数
send_snapshot(){
    # 将快照改为只读
    btrfs property set -ts $s_dir/$1/@ ro true
    btrfs property set -ts $s_dir/$1/@home ro true
    btrfs property set -ts $s_dir/$2/@ ro true
    btrfs property set -ts $s_dir/$2/@home ro true
    # 创建新目录
    mkdir $t_dir$2
    # 发送快照,显示进度
    btrfs send -p $s_dir/$1/@ $s_dir/$2/@ | pv |btrfs receive $t_dir$2
    btrfs send -p $s_dir/$1/@home $s_dir/$2/@home | pv |btrfs receive $t_dir$2
    echo "send snapshots $2 ok" 
}
# 查看目标磁盘占用
check_useage(){
    use=$(df -h $1 | awk '{ print $5 " " $1 }' | tail -n1)
    echo "Running out of space $use on $(hostname) as on $(date "+%Y-%m-%d-%T")"
}
# 查看目标快照数量
check_target_num(){
    t_num=$(ls -ltr $1 | grep -E '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | awk '{print $9}' | wc -l )
    if [ $t_num -eq 0 ];then
        echo "目标目录中没有快照,请和实或手动进行第一次同步"
    else
        echo "Running out of num snapshots $t_num on $1"
    fi
}
# 主函数
main(){
    # 检查ROOT
    # shellcheck disable=SC2046
    if [ $(id -u) != "0" ]; then
        echo "Error: You must be root to run this script, please use root user"
        exit 1
    fi
    # 启动
    echo -e "\n$(date "+%Y-%m-%d- --- %T") --- Start\n"   
    # 检查文件夹如果不存在退出 
    if [ ! -d $s_dir  ] || [ ! -d $t_dir ];then
        echo "Error: s_dir or d_dir check failed exit!"
        exit 1
    fi 
    # 获取目标目录中最新的文件为参照
    lastest_dir_s=$(ls -ltr $s_dir| grep -E '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | awk '{print $9}' | tail -n 1 )
    lastest_dir_t=$(ls -ltr $t_dir| grep -E '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | awk '{print $9}' | tail -n 1 )
    # 判断最新的目录是否相同
    if [ $lastest_dir_s == $lastest_dir_t ];then
        echo "Latest directories are the same. Exiting."
        exit 0
    else
        echo "Latest directories are different. Syncing directories..."
    fi
    # 执行循环
    while [ $lastest_dir_s != $lastest_dir_t ];do
        # 获取要发送的快照目录
        n_dir=$(ls -ltr $s_dir | awk '{print $9}' | sed -n "/$lastest_dir_t/{N;p}" | tail -n1)
        # 传递参数
        send_snapshot $lastest_dir_t $n_dir
        # 更新最新的目标目录
        lastest_dir_t=$(ls -ltr $t_dir | awk '{print $9}' | tail -n 1 )
    done
    # 结束
    echo -e "\n$(date "+%Y-%m-%d- --- %T") --- Done\n"
    # 子卷数量
    check_target_num $t_dir
    # 磁盘占用
    check_useage $t_dir
}

# 执行主函数
main
