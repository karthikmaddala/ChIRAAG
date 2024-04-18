import os
import stat

def extract_errors_from_log(log_path):
    # Ensure the simulation.log file is readable
    if os.path.exists(log_path):
        os.chmod(log_path, stat.S_IRUSR)
    
    # Check if the log file exists
    if not os.path.isfile(log_path):
        print(f"Error: {log_path} not found.")
        return False, ""

    # Read the log file and check for errors
    with open(log_path, "r") as log_file:
        log_content = log_file.read()

    # Look for the word 'error' in the log content
    error_found = "error" in log_content.lower()
    
    return error_found, log_content
