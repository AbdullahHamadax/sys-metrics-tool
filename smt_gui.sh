#!/bin/bash

username="nour"
password="123"

login() {
    credentials=$(zenity --forms \
        --title="Login" \
        --text="Enter your Account" \
        --add-entry="Username" \
        --add-password="Password" \
        --width=350 \
        --height=250)

    if [[ $? -ne 0 ]]; then
        zenity --error --text="Login cancelled... exiting..." --width=300
        exit 1
    fi

    user=$(echo "$credentials" | awk -F '|' '{print $1}')
    pass=$(echo "$credentials" | awk -F '|' '{print $2}')

    if [[ "$user" != "$username" || "$pass" != "$password" ]]; then
        zenity --error --text="Invalid username or password" --width=300
        exit 1
    fi

    zenity --info --text="Login successful!" --width=300
}

# login
DIR="sys_logs"
DIRHTML="smt_html"

if [ ! -d "$DIR" ]; then
    mkdir $DIR
fi

if [ ! -d "$DIRHTML" ]; then
    mkdir $DIRHTML
fi

path="$(pwd)/$DIR"
pathHTML="$(pwd)/$DIRHTML"

loop=true

gatherCPULogs() {
    mpstat >>"$path/cpu_logs.txt"
    sensors | grep "Core" >>"$path/cpu_logs.txt"
    avg_temp=$(avgTemp)
    echo "Average CPU Temperature: $avg_temp°C" >>"$path/cpu_logs.txt"
    echo "" >>"$path/cpu_logs.txt"
}

gatherGPULogs() {

    vendor="$(sudo lshw -C display | grep vendor | head -1)"

    if [[ $vendor =~ "NVIDIA" ]]; then
        nvidia-smi -q -d clock | head -14 | tail -5 >>"$path/gpu_logs.txt"
        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free,temperature.gpu --format=csv >>"$path/gpu_logs.txt"
    elif [[ $vendor =~ "AMD" ]]; then
        radeontop >>"$path/gpu_logs.txt"
    else
        intel_gpu_top >>"$path/gpu_logs.txt"
    fi

    echo "" >>"$path/gpu_logs.txt"
}

gatherMemoryLogs() {
    date >>"$path/memory_logs.txt"
    free -m >>"$path/memory_logs.txt"
}

gatherNetworkLogs() {
    chosen_interface=$1

    date >>"$path/network_logs.txt"

    echo "Network Interface Statistics for $chosen_interface" >>"$path/network_logs.txt"

    echo "----------------------------------------------------" >>"$path/network_logs.txt"

    netstat -i | grep "$chosen_interface" >>"$path/network_logs.txt"

    rx_bytes=$(cat /sys/class/net/$chosen_interface/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/$chosen_interface/statistics/tx_bytes)
    echo -e "Received-Bytes: $rx_bytes B\nTransmitted-Bytes: $tx_bytes B" >>"$path/network_logs.txt"

    rx_errors=$(cat /sys/class/net/$chosen_interface/statistics/rx_errors)
    tx_errors=$(cat /sys/class/net/$chosen_interface/statistics/tx_errors)
    echo -e "Received-Errors: $rx_errors B\nTransmitted-Errors: $tx_errors B" >>"$path/network_logs.txt"

}

gatherSystemLoadData() {
    uptime | awk '{print "Average Access (1 min, 5 min, 15 min): " $8, $9, $10}' >>"$path/system_load_logs.txt"
    dstat -c -d -n -m 1 1 | tail -n 10 >>"$path/system_load_logs.txt"
}

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

    echo "$avg_temp"
}

checkCritTemp() {

    avg_temp=$1

    if (($(echo "$avg_temp >= 70" | bc -l))); then
        paplay /home/abood/Downloads/windows-error-sound-effect-35894.mp3
        zenity --warning --text="Average CPU Temperature is high ($avg_temp°C)!" --title="Be aware cpu is on fire🔥🔥🔥🔥"
    fi
}

checkCPU() {

    TEMP_FILE=$(mktemp)

    gather_cpu_data() {
        while true; do
            {
                echo "CPU performance and temperature"
                echo "----------------------------------"

                mpstat

                sensors | grep "Core"

                avg_temp=$(avgTemp)
                echo "Average CPU Temperature: $avg_temp°C"
                checkCritTemp $avg_temp

                gatherCPULogs

                echo ""

            } >"$TEMP_FILE"

            # line_count=$(($(wc -l <"$TEMP_FILE") - 2))

            temperature_graph_plots=$(cat "$path/cpu_logs.txt" | tail -n 120 | grep "Average" | awk '{print $4}' | sed 's/°C//g')

            sleep 1
        done
    }

    gather_cpu_data &

    DATA_PROCESS_PID=$!

    tail -f "$TEMP_FILE" | zenity --text-info --title="CPU Performance and Temperature" --width=600 --height=458 --auto-scroll --cancel-label="Generate HTML report" --ok-label="Go back"

    if [[ $? -eq 1 ]]; then
        openCPUHTML
    fi

    kill $DATA_PROCESS_PID

    rm "$TEMP_FILE"
}

checkGPU() {

    vendor="$(sudo lshw -C display | grep vendor | head -1)"
    TEMP_FILE=$(mktemp)

    gather_gpu_data() {
        while true; do
            {
                echo ""
                echo "GPU Utilization and Health"
                echo "--------------------------"
                echo "$vendor"

                if [[ $vendor =~ "NVIDIA" ]]; then
                    nvidia-smi -q -d clock | head -14 | tail -5
                    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free,temperature.gpu --format=csv
                elif [[ $vendor =~ "AMD" ]]; then
                    radeontop
                else
                    intel_gpu_top
                fi

                gatherGPULogs

                echo -e "\n"
            } >"$TEMP_FILE"

            final_temp=$(cat "$path/gpu_logs.txt" | tail -n 2 | head -n 1 | awk '{print $7}')
        done
    }

    gather_gpu_data &

    DATA_PROCESS_PID=$!

    tail -f "$TEMP_FILE" | zenity --text-info --title="GPU Utilization and Health" --width=600 --height=410 --auto-scroll --cancel-label="Generate HTML report" --ok-label="Go back"

    if [[ $? -eq 1 ]]; then
        echo ${gpu_temperature_plots[*]}

        openGPUHTML "${gpu_temperature_plots[@]}"
    fi

    kill $DATA_PROCESS_PID

    rm "$TEMP_FILE"
}

checkDiskUsage() {
    number_of_disks=$(($(df -h | wc -l) - 1))
    disks=($(df -h | awk '{print $1}' | tail -$number_of_disks))

    disk_list=""
    for i in "${!disks[@]}"; do
        disk_list+="${i}-${disks[$i]}\n"
    done

    chosen_disk=$(zenity --list \
        --title="Disk Usage and SMART Status" \
        --text="Select a disk from the list:" \
        --column="Number-Disk" \
        --width=500 --height=600 \
        $(for i in "${!disks[@]}"; do echo "$((i + 1))-${disks[$i]}"; done))

    if [[ -z $chosen_disk ]]; then
        zenity --error --text="No disk selected! Returning to the main menu."
        return
    fi

    chosen_disk_number=$(echo "$chosen_disk" | cut -d'-' -f1)
    chosen_disk=${disks[$((chosen_disk_number - 1))]}

    while true; do
        disk_info=$(df -h | grep -m 1 "$chosen_disk" | awk '{print "Disk: " $1 "\nUsed: " $3 " / " $2 "\nAvailable: " $4 "\nUse%: " $5}')
        SMART_STATUS=$(sudo smartctl -H "$chosen_disk" | grep -i 'health' | awk '{print $6}')

        if [[ "$SMART_STATUS" == "PASSED" ]]; then
            smart_status_message="SMART Status: Your drive is perfectly fine :D"
        else
            smart_status_message="SMART Status: Issues detected!"
        fi
        echo "$disk_info\n\n$smart_status_message" >>"$path/disk_logs.txt"
        zenity --info \
            --title="Disk Usage and SMART Status" \
            --width=500 \
            --text="$disk_info\n\n$smart_status_message"

        response=$(zenity --question \
            --title="Return to Main Menu?" \
            --text="Do you want to go back to the main menu?" \
            --ok-label="Yes" \
            --cancel-label="No")

        if [[ $? -eq 0 ]]; then
            break
        fi
    done
}

checkMemory() {
    TEMP_FILE=$(mktemp)

    gather_memory_data() {
        while true; do
            {
                echo "Memory Consumption"
                echo "------------------"
                free -m
                gatherMemoryLogs
            } >"$TEMP_FILE"
            sleep 1
        done
    }

    gather_memory_data &

    DATA_PROCESS_PID=$!

    tail -f "$TEMP_FILE" | zenity --text-info --title="Memory Consumption" --width=600 --height=275 --auto-scroll --cancel-label="Generate HTML report" --ok-label="Go back"

    if [[ $? -eq 1 ]]; then
        openMemoryHTML
    fi

    kill $DATA_PROCESS_PID

    rm "$TEMP_FILE"
}

checkNetworkInterface() {
    interfaces=$(netstat -i | tail -n +3 | awk '{print $1}' | grep -vE '^Iface')

    if [[ -z "$interfaces" ]]; then
        zenity --error --text="You somehow don't have any network interfaces????" --width=300
        return
    fi

    chosen_interface=$(zenity --list \
        --title="Network Interface Statistics" \
        --text="Select a network interface:" \
        --column="Interface" \
        --width=500 --height=300 \
        $interfaces)

    if [[ -z "$chosen_interface" ]]; then
        zenity --error --text="No interface selected! Returning to the main menu."
        return
    fi

    TEMP_FILE=$(mktemp)

    gather_network_data() {
        while true; do
            {
                echo "Network Interface Statistics for $chosen_interface"
                echo "----------------------------------------------------"

                netstat -i | grep "$chosen_interface"

                rx_bytes=$(cat /sys/class/net/$chosen_interface/statistics/rx_bytes)
                tx_bytes=$(cat /sys/class/net/$chosen_interface/statistics/tx_bytes)
                echo -e "Received-Bytes: $rx_bytes B\nTransmitted-Bytes: $tx_bytes B"

                rx_errors=$(cat /sys/class/net/$chosen_interface/statistics/rx_errors)
                tx_errors=$(cat /sys/class/net/$chosen_interface/statistics/tx_errors)
                echo -e "Received-Errors: $rx_errors B\nTransmitted-Errors: $tx_errors B"

                gatherNetworkLogs $chosen_interface
                echo ""
            } >"$TEMP_FILE"
            sleep 1
        done
    }

    gather_network_data &

    DATA_PROCESS_PID=$!

    tail -f "$TEMP_FILE" | zenity --text-info --title="Network Interface Statistics for $chosen_interface" --width=700 --height=328 --auto-scroll --cancel-label="Generate HTML report" --ok-label="Go back"

    if [[ $? -eq 1 ]]; then
        openNetworkHTML
    fi

    kill $DATA_PROCESS_PID

    rm "$TEMP_FILE"
}

checkSystemLoadMetrics() {
    TEMP_FILE=$(mktemp)

    gather_system_load_data() {
        while true; do
            {
                load_average="System Load Metrics"
                load_average+="\n-------------------"
                load_average+="\nAverage Access (1 min, 5 min, 15 min): $(uptime | awk '{print $8, $9, $10}')"

                load_average+="\n\n$(dstat -c -d -n -m 1 1 | tail -n 10)"

                echo -e "$load_average"
                gatherSystemLoadData
                echo ""
            } >"$TEMP_FILE"
        done
    }

    gather_system_load_data &

    DATA_PROCESS_PID=$!

    tail -f "$TEMP_FILE" | zenity --text-info --title="System Load Metrics" --width=600 --height=345 --auto-scroll --cancel-label="Generate HTML report" --ok-label="Go back"

    if [[ $? -eq 1 ]]; then
        openSystemLoadHTML
    fi

    kill $DATA_PROCESS_PID

    rm "$TEMP_FILE"
}

openCPUHTML() {
    cpu_data=$(cat "$path/cpu_logs.txt" | tail -n 12)

    temperature_graph_plots=$(cat "$path/cpu_logs.txt" | tail -n 120 | grep "Average" | awk '{print $4}' | sed 's/°C//g')

    temperature_data=$(echo "$temperature_graph_plots" | tr '\n' ',' | sed 's/,$//')

    graph_image_path=$(python3 generate_temperature_graph.py "$temperature_data")

    echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>CPU Report</title>
    <script src=\"https://cdn.tailwindcss.com\"></script>
</head>
<body class=\"flex items-center flex-col min-h-screen bg-sky-700\">
    <h1 class=\"text-3xl text-white font-bold underline text-center mt-5\">
        CPU - HTML REPORT
    </h1>

    <div class=\"flex h-full w-[700px] bg-white border-4 p-7 flex-wrap gap-5 mt-10\">
        <div class=\"graph w-full\">
            <h2 class=\"text-xl font-bold text-center\">CPU Performance and Temperature</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
            $cpu_data
            </pre>
        </div>

        <div class=\"graph w-full mt-5\">
            <h2 class=\"text-xl font-bold text-center\">CPU Temperature Graph</h2>
            <img src=\"$(pwd)/$graph_image_path\" alt=\"CPU Temperature Graph\" class=\"w-full mt-5\" />
        </div>

    </div>
</body>
</html>" >"$pathHTML/cpu.html"

    xdg-open "$pathHTML/cpu.html"

}

openGPUHTML() {
    temperature_gpu_graph=()
    mapfile -t lines < <(tail -n 80 $path/gpu_logs.txt)

    chunk_size=8

    for ((i = 0; i < ${#lines[@]}; i += chunk_size)); do
        chunk=("${lines[@]:i:chunk_size}")

        last_two_lines="${chunk[@]: -2}"

        temperature_gpu_graph+=($(echo "$last_two_lines" | awk '{print $7}'))
    done
    echo ${temperature_gpu_graph[*]}
    gpu_temperature_data=$(echo "${temperature_gpu_graph[*]}" | tr ' ' ',' | sed 's/,$//')

    graph_image_path=$(python3 generate_gpu_temperature.py "$gpu_temperature_data")

    gpu_data=$(cat "$path/gpu_logs.txt" | tail -n 8)
    gpu_info=$(echo -e "$gpu_data" | head -n 5)
    gpu_utilization=$(echo -e "$gpu_data" | tail -n 2)

    echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>GPU Utilization Report</title>
    <script src=\"https://cdn.tailwindcss.com\"></script>
</head>
<body class=\"flex items-center flex-col min-h-screen bg-purple-700\">
    <h1 class=\"text-3xl text-white font-bold underline text-center mt-5\">
        GPU Utilization and Health - HTML REPORT
    </h1>

    <div class=\"flex h-full w-[700px] bg-white border-4 p-7 flex-wrap gap-5 mt-10\">
        <div class=\"stats w-full\">
            <h2 class=\"text-xl font-bold text-center\">GPU Vendor</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
$vendor
            </pre>
        </div>

        <div class=\"utilization w-full mt-5\">
            <h2 class=\"text-xl font-bold text-center\">GPU Information</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
$gpu_info
            </pre>
        </div>

        <div class=\"graph w-full mt-5\">
            <h2 class=\"text-xl font-bold text-center\">GPU Utilization Graph</h2>
            <img src=\"$(pwd)/$graph_image_path\" alt=\"GPU Utilization Graph\" class=\"w-full mt-5\" />
        </div>

        <div class=\"utilization w-full mt-5\">
            <h2 class=\"text-xl font-bold text-center\">GPU Utilization</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
$gpu_utilization
            </pre>
        </div>
    </div>
</body>
</html>" >"$pathHTML/gpu.html"

    xdg-open "$pathHTML/gpu.html"
}

openMemoryHTML() {
    memory_data=$(free -m | awk 'NR==1 || NR==2 {print}')
    total_memory=$(echo "$memory_data" | awk 'NR==2 {print $2}')
    used_memory=$(echo "$memory_data" | awk 'NR==2 {print $3}')
    free_memory=$(echo "$memory_data" | awk 'NR==2 {print $4}')

    echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Memory Report</title>
    <script src=\"https://cdn.tailwindcss.com\"></script>
</head>
<body class=\"flex items-center flex-col min-h-screen bg-green-700\">
    <h1 class=\"text-3xl text-white font-bold underline text-center mt-5\">
        Memory - HTML REPORT
    </h1>

    <div class=\"flex h-full w-[700px] bg-white border-4 p-7 flex-wrap gap-5 mt-10\">
        <div class=\"graph w-full\">
            <h2 class=\"text-xl font-bold text-center\">Memory Consumption</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
Total Memory: ${total_memory}MB
Used Memory: ${used_memory}MB
Free Memory: ${free_memory}MB
            </pre>
        </div>


    </div>
</body>
</html>" >"$pathHTML/memory.html"

    xdg-open "$pathHTML/memory.html"
}

openNetworkHTML() {
    rx_bytes=$(cat /sys/class/net/$chosen_interface/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/$chosen_interface/statistics/tx_bytes)
    rx_errors=$(cat /sys/class/net/$chosen_interface/statistics/rx_errors)
    tx_errors=$(cat /sys/class/net/$chosen_interface/statistics/tx_errors)

    echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Network Interface Report</title>
    <script src=\"https://cdn.tailwindcss.com\"></script>
</head>
<body class=\"flex items-center flex-col min-h-screen bg-purple-700\">
    <h1 class=\"text-3xl text-white font-bold underline text-center mt-5\">
        Network Interface - HTML REPORT
    </h1>

    <div class=\"flex h-full w-[700px] bg-white border-4 p-7 flex-wrap gap-5 mt-10\">
        <div class=\"stats w-full\">
            <h2 class=\"text-xl font-bold text-center\">Interface: $chosen_interface</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
Received Bytes: $rx_bytes B
Transmitted Bytes: $tx_bytes B
Received Errors: $rx_errors
Transmitted Errors: $tx_errors
            </pre>
        </div>



    </div>
</body>
</html>" >"$pathHTML/network.html"

    xdg-open "$pathHTML/network.html"
}

openSystemLoadHTML() {
    load_averages=$(uptime | awk '{print $8, $9, $10}')
    system_load_data=$(dstat -c -d -n -m 1 10)

    load_average_data=$(uptime | awk '{print $8, $9, $10}' | tr ',' ' ')

    echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>System Load Metrics Report</title>
    <script src=\"https://cdn.tailwindcss.com\"></script>
</head>
<body class=\"flex items-center flex-col min-h-screen bg-green-700\">
    <h1 class=\"text-3xl text-white font-bold underline text-center mt-5\">
        System Load Metrics - HTML REPORT
    </h1>

    <div class=\"flex h-full w-[700px] bg-white border-4 p-7 flex-wrap gap-5 mt-10\">
        <div class=\"stats w-full\">
            <h2 class=\"text-xl font-bold text-center\">Load Averages</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
1-minute: ${load_averages%% *}, 5-minute: $(echo $load_averages | awk '{print $2}'), 15-minute: ${load_averages##* }
            </pre>
        </div>


        <div class=\"system-data w-full mt-5\">
            <h2 class=\"text-xl font-bold text-center\">System Load Metrics</h2>
            <pre class=\"whitespace-pre-wrap bg-gray-100 p-3 mt-5 text-sm\">
$system_load_data
            </pre>
        </div>

    </div>
</body>
</html>" >"$pathHTML/load.html"

    xdg-open "$pathHTML/load.html"
}

while [ "$loop" = true ]; do
    clear
    option=$(zenity --list \
        --title="Welcome to our system metrics tool" \
        --text="Pick an option to display:" \
        --column="Option" \
        --width=600 \
        --height=450 \
        "CPU Performance and Temperature" \
        "GPU Utilization and Health" \
        "Disk Usage and SMART Status" \
        "Memory Consumption" \
        "Network Interface Statistics" \
        "System Load Metrics")

    case $option in
    "CPU Performance and Temperature")
        checkCPU
        ;;
    "GPU Utilization and Health")
        checkGPU
        ;;
    "Disk Usage and SMART Status")
        checkDiskUsage
        ;;
    "Memory Consumption")
        checkMemory
        ;;
    "Network Interface Statistics")
        checkNetworkInterface
        ;;
    "System Load Metrics")
        checkSystemLoadMetrics
        ;;
    *)
        if [ -z "$option" ]; then
            zenity --info --text="You are exiting our precious tool😔 \nthanks for using it ❤️" --width=300
            loop=false
        else
            zenity --error --text="Invalid option. Please select a valid one."
        fi
        ;;
    esac
done
