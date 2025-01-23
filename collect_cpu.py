#!/usr/bin/python

import psutil
import time
import os
import argparse

# Parameters
sampling_interval = 1  # In seconds

def collect_cpu_usage(output_file, interval, duration):
    """Collect CPU usage data, including %user, %system, and %softirq."""
    print("Waiting for 2 seconds before starting collection...")
    time.sleep(2)  # Wait for 2 seconds before starting collection

    with open(output_file, "w") as file:
        # Write the header
        file.write("# Time(s)\t%User\t%System\t%SoftIRQ\n")
        start_time = time.time()
        while time.time() - start_time < duration:
            # Get CPU times percent
            cpu_times = psutil.cpu_times_percent(interval=0)
            elapsed_time = time.time() - start_time

            # Handle platform-dependent fields
            softirq = getattr(cpu_times, "softirq", 0.0)

            # Write the data to the file
            file.write(
                f"{elapsed_time:.2f}\t{cpu_times.user:.2f}\t{cpu_times.system:.2f}\t{softirq:.2f}\n"
            )
            time.sleep(interval)

def generate_gnuplot_script(data_file, script_file, output_png):
    """Generate a Gnuplot script for plotting the CPU usage."""
    script_content = f"""
    set terminal pngcairo size 800,600
    set output "{output_png}"
    set title "CPU Usage Over Time"
    set xlabel "Time (s)"
    set ylabel "CPU Usage (%)"
    set grid
    plot "{data_file}" using 1:2 with lines title "%User" lw 2 linecolor "blue", \\
         "{data_file}" using 1:3 with lines title "%System" lw 2 linecolor "red", \\
         "{data_file}" using 1:4 with lines title "%SoftIRQ" lw 2 linecolor "orange"
    """
    with open(script_file, "w") as file:
        file.write(script_content)

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Monitor and plot CPU usage.")
    parser.add_argument("--duration", type=int, required=True, help="Duration to collect CPU usage data (in seconds).")
    parser.add_argument("--output-png", type=str, required=True, help="Final PNG file to save the graph.")
    args = parser.parse_args()

    duration = args.duration
    output_png = args.output_png
    data_file = "cpu_usage.dat"  # Temporary data file
    gnuplot_script = "plot_cpu_usage.gp"  # Temporary Gnuplot script

    # Collect CPU usage data
    print(f"Collecting CPU usage data for {duration} seconds...")
    collect_cpu_usage(data_file, sampling_interval, duration)
    print(f"Data saved to {data_file}")

    # Generate Gnuplot script
    print(f"Generating Gnuplot script...")
    generate_gnuplot_script(data_file, gnuplot_script, output_png)
    print(f"Gnuplot script saved to {gnuplot_script}")

    # Run Gnuplot to generate the graph
    print(f"Generating graph with Gnuplot...")
    os.system(f"gnuplot -p {gnuplot_script}")
    print(f"Graph saved as {output_png}")

    # Clean up temporary files
    os.remove(data_file)
    os.remove(gnuplot_script)
    print("Temporary files removed.")

if __name__ == "__main__":
    main()

