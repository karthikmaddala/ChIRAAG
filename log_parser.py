import zipfile
import os

def extract_errors_from_log(zip_path):
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall("temp_results")
    log_path = os.path.join("temp_results", "simulation.log")
    with open(log_path, "r") as log_file:
        log_content = log_file.read()

    error_found = "error" in log_content.lower()
    return error_found, log_content

