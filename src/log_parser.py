# log_parser.py
def extract_errors_from_log(log_path):
    """
    Parses the simulation.log file to extract error messages.
    Returns a boolean indicating if errors were found and a string containing all extracted errors.
    """
    error_messages = []
    try:
        with open(log_path, "r") as log_file:
            for line in log_file:
                if "error" in line.lower():  # Assuming 'error' is a keyword for error messages
                    error_messages.append(line.strip())
    except FileNotFoundError:
        return False, "Log file not found."

    if error_messages:
        return True, "\n".join(error_messages)
    return False, "No errors found."

