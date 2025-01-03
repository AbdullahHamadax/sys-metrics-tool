Here’s an updated version of the **System Metrics Tool** document including a "How to Run the Project" section:

---

# System Metrics Tool

## Objective

Develop a comprehensive system monitoring solution that collects, analyzes, and reports hardware and software performance metrics.

## Monitoring Targets

- **CPU**: Performance and temperature.
- **GPU**: Utilization and health.
- **Disk**: Usage and SMART status.
- **Memory**: Consumption.
- **Network**: Interface statistics.
- **System Load**: Overall metrics.

## Technologies Used

1. **Bash**: Scripts for system metrics collection.
2. **HTML**: For reporting interfaces.
3. **Zenity**: GUI for user interaction in Bash.
4. **Docker**: Containerization for consistent and portable deployment. *(Planned for future implementation)*

---

## How to Run the Project

### Prerequisites
1. **Operating System**: Linux (preferred for Bash and Zenity compatibility).
2. **Software Requirements**:
   - `bash` (default shell on Linux)
   - `zenity` (for GUI interaction)
   - `smartmontools` (for disk SMART status)
   - `docker` (optional, for containerized deployment)
3. **Hardware Requirements**:
   - Sensors for temperature monitoring (`lm-sensors`)
   - Compatible GPU (if monitoring GPU stats)

---

### Steps to Run

#### 1. **Clone the Repository**
```bash
git clone https://github.com/AbdullahHamadax/sys-metrics-tool.git
cd sys-metrics-tool
```

#### 2. **Install Dependencies**
   Install the necessary tools using your package manager:
   ```bash
   sudo apt update
   sudo apt install zenity smartmontools lm-sensors docker.io -y
   ```

#### 3. **Set Up Sensors**
   Run the following to configure temperature monitoring:
   ```bash
   sudo sensors-detect
   sensors
   ```

#### 4. **Run the Tool**

   To start the tool ( Console version ):
   ```bash
   bash console.sh
   ```

   To start the tool ( GUI version ):
   ```bash
   bash smt_gui.sh
   ```

#### 5. **View the Report**
   - The tool generates an HTML report in the `reports/` directory.
   - Open the report using any browser:
     ```bash
     xdg-open reports/<chosen_hardware>.html
     ```

#### 6. **Optional: Run in Docker**
   Build and run the tool inside a Docker container:
   ```bash
   docker build -t system-metrics-tool .
   docker run --rm -it system-metrics-tool
   ```
---
