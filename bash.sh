#!/bin/bash
message="Welcome to our Laptop analysis system
----------------------------------------"
optionMessage="Pick an option to display!!
----------------------------
1- CPU performance and temperature
2- GPU utilization and health
3- Disk usage and SMART status
4- Memory consumption
5- Network interface statistics
6- System load metrics
0- Exit"

echo -e "$message"
loop=true

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
            echo "CPU Performance and Temperature"
            echo "-------------------------------"
            hddtemp 
            echo -e "
            
            
            
            
            "
            ;;
        2)
            clear
            echo "GPU Utilization and Health"
            echo "--------------------------"
            echo -e "
            
            
            
            
            "
            ;;
        3)
            clear
            echo "Disk Usage and SMART Status"
            echo "---------------------------"
            echo -e "
            
            
            
            
            "
            ;;
        4)
            clear
            echo "Memory Consumption"
            echo "------------------"
            echo -e "
            
            
            
            
            "
            ;;
        5)  
            clear
            echo "Network Interface Statistics"
            echo "----------------------------"
            echo -e "
            
            
            
            
            "
            ;;
        6)
            clear
            echo "System Load Metrics"
            echo "-------------------"
            echo -e "
            
            
            
            
            "
            ;;
        *)
            clear
            echo "Invalid option. Please try again."
            ;;
    esac
done
