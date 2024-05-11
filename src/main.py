import os
import sys
import json
from openai_utils import call_openai_for_sva, refine_sva_with_openai
from log_parser import extract_errors_from_log

def main(json_spec_path):
    if len(sys.argv) < 2:
        print("Usage: python main.py <json_spec_path>")
        sys.exit(1)

    with open(json_spec_path, 'r') as json_file:
        json_spec = json.load(json_file)

    while True:
        # User inputs the prompt for generating or refining SVA
        user_prompt = input("Enter your prompt for generating/refining SVA or type 'exit' to quit: ")
        if user_prompt.lower() == 'exit':
            break

        # Serialize JSON specification to a string that can be included in the prompt
        json_string = json.dumps(json_spec, indent=2)

        # Include the JSON specification in the prompt for clarity
        full_prompt = f"{user_prompt}\n\nJSON Specification:\n{json_string}"

        # Generate/Refine SVA using OpenAI with user-provided prompt
        sva_code = call_openai_for_sva(json_string, [full_prompt])
        print("Generated/Refined SVA code:")
        print(sva_code)

        # Step 2: User manually tests SVA in EDA Playground
        input("Please upload the above SVA to EDA Playground, run the simulation, download the results, and place the simulation.log in the current directory. Press Enter to continue after you have done this...")

        # Step 3: Check for simulation.log in the current directory
        log_path = "simulation.log"
        if not os.path.exists(log_path):
            print("Error: simulation.log not found in the current directory.")
            continue

        # Step 4: Analyze results
        error_found, error_message = extract_errors_from_log(log_path)
        if error_found:
            print("Errors found in simulation log:")
            print(error_message)
            sva_code = refine_sva_with_openai(sva_code, error_message)
            print("Refined SVA based on simulation errors:")
            print(sva_code)
        else:
            print("SVA verified successfully with no errors. If satisfied, type 'exit' to quit or continue refining.")

if __name__ == "__main__":
    main(sys.argv[1])

