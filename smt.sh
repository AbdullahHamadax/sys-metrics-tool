#!/bin/bash
message="----------------------------------
Welcome to our computer analysis system
----------------------------------"
optionMessage="\nPlease pick an option to display!!
----------------------------------
1- CPU performance and temperature
----------------------------------
2- GPU utilization and health
----------------------------------
3- Disk usage and SMART status
----------------------------------
4- Memory consumption
----------------------------------
5- Network interface statistics
----------------------------------
6- System load metrics
----------------------------------
0- Exit"

echo -e "$message"
loop=true

checkCPU(){
    while true; do
        clear
        echo "CPU Performance and Temperature"
        echo "-------------------------------"
        mpstat
        sensors | grep 'Core'
        echo -e "\nPress 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        sleep 1
    done
}

checkGPU(){
    vendor="$(sudo lshw -C display | grep vendor | head -1)"

    while true; do
        clear
        echo "GPU Utilization and Health"
        echo "--------------------------"
        if [[ $vendor =~ "NVIDIA" ]]; then
            nvidia-smi -q -d clock | head -14 | tail -5
            nvidia-smi -q -d temperature | head -18 | tail -9
            nvidia-smi -q -d utilization | head -16 | tail -7
        else
            radeontop
        fi
        echo -e "\nPress 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        sleep 2
    done
}

checkDiskUsage(){
    while true; do
        clear
        echo "Disk Usage and SMART Status"
        echo "---------------------------"
        df -h
        sudo smartctl -H /dev/nvme0n1 | tail -3
        echo -e "\nPress 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        sleep 2
    done
}

checkMemory(){
    while true; do
        clear
        echo "Memory Consumption"
        echo "------------------"
        free -h
        echo -e "\nPress 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        sleep 2
    done
}

checkNetworkInterface(){
     while true; do
        clear
        echo "Network Interface Statistics"
        echo "----------------------------"
        netstat -i
        echo -e "\nPress 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        sleep 2
    done
}


checkSystemLoadMetrics(){
     while true; do
        clear
        echo "System Load Metrics"
        echo "-------------------"
        uptime
        echo -e "\nPress 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        sleep 2
    done
}

while [ "$loop" = true ]; do
    echo -e "$optionMessage"
    read -p "Enter your option: " option
    case $option in
        0)
            clear
            echo "Exiting the program..."
            loop=false
            ;;
        1)
            clear
            checkCPU
            ;;
        2)
            clear
            checkGPU
            ;;
        3)
            clear
            checkDiskUsage
            ;;
        4)
            clear
            checkMemory
            ;;
        5)
            clear
            checkNetworkInterface
            echo -e "
            
            
            
            
            "
            ;;
        6)
            clear
            checkSystemLoadMetrics
            echo -e "
            
            
            
            
            "
            ;;
        *)
            clear
            echo "Invalid option. Please choose an option from [1-6]."
            ;;
    esac
done
