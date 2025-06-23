#!/usr/bin/python3
# -*- coding: utf-8 -*-
import csv
import argparse
import os

def parse_windows_event_log(txt_file_path, csv_file_path):
    entries = []
    current_entry = {}

    with open(txt_file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith("Id"):
                if current_entry:
                    entries.append(current_entry)
                    current_entry = {}
                current_entry["Id"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("TimeCreated"):
                current_entry["TimeCreated"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("ProviderName"):
                current_entry["ProviderName"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Message"):
                current_entry["Message"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("DumpData"):
                current_entry["DumpData"] = stripped.split(":", 1)[1].strip()
            elif stripped:
                # Handle multiline fields
                if "DumpData" in current_entry and not "Message" in current_entry:
                    current_entry["DumpData"] += " " + stripped
                elif "Message" in current_entry and not "DumpData" in current_entry:
                    current_entry["Message"] += " " + stripped
                elif "DumpData" in current_entry and "Message" in current_entry:
                    if current_entry["DumpData"].endswith("..."):
                        current_entry["DumpData"] += " " + stripped

        if current_entry:
            entries.append(current_entry)

    # Write to CSV
    with open(csv_file_path, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ["Id", "TimeCreated", "ProviderName", "Message", "DumpData"]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(entries)

    print(f"✅ Parsed and saved to: {csv_file_path}")


def main():
    parser = argparse.ArgumentParser(description="Convert Windows Event Log TXT to CSV")
    parser.add_argument('--file', required=True, help="Path to the input .txt file")
    args = parser.parse_args()

    input_txt = args.file
    if not os.path.isfile(input_txt):
        print(f"❌ File not found: {input_txt}")
        return

    base_name = os.path.splitext(os.path.basename(input_txt))[0]
    output_csv = os.path.join(os.path.dirname(input_txt), f"{base_name}_parsed.csv")

    parse_windows_event_log(input_txt, output_csv)


if __name__ == "__main__":
    main()
