import os
from openai_utils import call_openai_for_sva
from log_parser import extract_errors_from_log
from sva_refinement import refine_sva_based_on_errors
import json

def main(json_spec_path, download_folder):
    with open(json_spec_path, 'r') as json_file:
        json_spec = json.load(json_file)

    # Step 1: Generate SVA using OpenAI
    sva_code = call_openai_for_sva(json.dumps(json_spec, indent=2))
    print("Generated SVA code:")
    print(sva_code)
    
    # Step 2: User manually tests SVA in EDA Playground
    input("Please upload the above SVA to EDA Playground, run the simulation, download the results, and place them in the specified download folder. Press Enter to continue after you have done this...")
    
    # Step 3: Check for results.zip in the specified download_folder
    result_zip = os.path.join(download_folder, "result.zip")
    if not os.path.exists(result_zip):
        print("Error: results.zip not found in the specified folder.")
        return
    
    # Step 4: Analyze results
    error_found, log_content = extract_errors_from_log(result_zip)
    if error_found:
        sva_code, refined = refine_sva_based_on_errors(sva_code, log_content)
        if refined:
            print("Refined SVA based on simulation errors:")
            print(sva_code)
        else:
            print("No further refinement was necessary.")
    else:
        print("SVA verified successfully with no errors.")

if __name__ == "__main__":
    json_input_path = "rv_timer.json"
    download_path = "home/karthik/Downloads"
    main(json_input_path, download_path)

