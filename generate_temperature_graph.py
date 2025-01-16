import matplotlib.pyplot as plt
import sys

temperature_data = sys.argv[1].split(',')

temperature_values = [float(temp) for temp in temperature_data]

time_points = list(range(1, len(temperature_values) + 1))

# Create a plot
plt.figure(figsize=(10, 5))
plt.plot(time_points, temperature_values, label='CPU Temperature (°C)', color='red', marker='o')

# Labeling the graph
plt.title('CPU Temperature Over Time')
plt.xlabel('Time (or Iteration)')
plt.ylabel('Temperature (°C)')
plt.grid(True)
plt.legend()

graph_path = 'cpu_temperature_graph.png'
plt.savefig(graph_path)

# plt.show()

print(graph_path)
