#!/bin/bash
message="----------------------------------
Welcome to our system metrics tool
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

loop=true


avgTemp() {
    temperatures=$(sensors | grep 'Core' | awk '{print $3}' | sed 's/+//g' | sed 's/°C//g')

    sum=0
    count=0

    for temp in $temperatures; do
        if [[ ! "$temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            continue
        fi

        sum=$(echo "$sum + $temp" | bc)
        count=$((count + 1))
    done

    avg_temp=$(echo "scale=2; $sum / $count" | bc)
    echo "Average CPU Temperature: $avg_temp°C"
}




checkCPU(){
    while true; do
        clear
        echo "CPU Performance and Temperature"
        echo "-------------------------------"
        mpstat
        sensors | grep "Core"
        avgTemp
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
        echo "$vendor"
        if [[ $vendor =~ "NVIDIA" ]]; then
            nvidia-smi -q -d clock | head -14 | tail -5
            nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free,temperature.gpu --format=csv
        elif [[ $vendor =~ "AMD" ]]; then
            radeontop

        else intel_gpu_top
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
    clear
    echo "Disk Usage and SMART Status"
        echo "---------------------------"
        number_of_disks=$(($(df -h | wc -l)-1))
        echo "Disks available on machine: "
        disks=($(df -h | awk '{print $1}' | tail -$number_of_disks))
        for i in "${!disks[@]}"; do
            echo $(($i+1))-${disks[$i]}
        done
        echo "---------------------------"
        echo "Please choose a disk (1-$number_of_disks)"
        read chosen_disk_number
        chosen_disk=${disks[$(($chosen_disk_number-1))]}
        

    while true; do
        clear
        df -h | grep -m 1 "$chosen_disk" | awk '{print "Disk: " $1 "\nUsed: " $3 " / " $2 "\nAvailable: " $4 "\nUse%: " $5}'

        SMART_STATUS=$(sudo smartctl -H "$chosen_disk" | grep -i 'health' | awk '{print $6}')

        if [[ "$SMART_STATUS" == "PASSED" ]]; then
            echo "SMART Status: Your drive is perfectly fine :D"
        else
            echo "SMART Status: Issues detected"
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
        echo -e "Press 'p' to go back to the main menu"
        read -t 1 -n 1 input
        if [[ $input == "p" ]]; then
            clear
            break
        fi
        echo "System Load Metrics"
        echo "-------------------"
        load_average="average access (1 min, 5 min, 15 mins): "
        space=" "
        load_average+=$(uptime | awk '{print $8}')
        load_average+=$space
        load_average+=$(uptime | awk '{print $9}')
        load_average+=$space
        load_average+=$(uptime | awk '{print $10}')
        load_average+=$space
        echo -e $load_average
        dstat -c -d -n -m 1 1 
        sleep 1
    done
}

while [ "$loop" = true ]; do
    clear
    tput cup 0 0 
    echo -e "$message"
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
