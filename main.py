import os
from openai_utils import call_openai_for_sva
from log_parser import extract_errors_from_log
from sva_refinement import refine_sva_based_on_errors
import json

def main(json_spec_path):
    with open(json_spec_path, 'r') as json_file:
        json_spec = json.load(json_file)

    # Step 1: Generate SVA using OpenAI
    sva_code = call_openai_for_sva(json.dumps(json_spec, indent=2))
    print("Generated SVA code:")
    print(sva_code)

    error_found = True  # Initialize to enter the loop
    while error_found:
        # Step 2: User manually tests SVA in EDA Playground
        input("Please upload the above SVA to EDA Playground, run the simulation, download the results, and place the simulation.log in the current directory. Press Enter to continue after you have done this...")

        # Step 3: Check for simulation.log in the current directory
        log_path = "simulation.log"
        if not os.path.exists(log_path):
            print("Error: simulation.log not found in the current directory.")
            return

        # Step 4: Analyze results
        error_found, log_content = extract_errors_from_log(log_path)
        if error_found:
            sva_code, refined = refine_sva_based_on_errors(sva_code, log_content)
            if refined:
                print("Refined SVA based on simulation errors:")
                print(sva_code)
            else:
                print("No further refinement was necessary. Please check for issues manually.")
        else:
            print("SVA verified successfully with no errors.")
            break  # Exit the loop when no errors are found

if __name__ == "__main__":
    json_input_path = "rv_timer.json"
    main(json_input_path)

