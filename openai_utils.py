import openai

def call_openai_for_sva(json_spec):
    """
    Calls OpenAI API to generate SVA based on a generic JSON hardware specification.
    Converts JSON specification to a structured prompt for better understanding by the model.
    Uses the chat model API endpoint.
    """
    # Construct a detailed prompt to better guide the AI in generating useful and accurate SVAs.
    messages = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": f"Generate SystemVerilog Assertions based on the following JSON-like hardware specifications:\n{json_spec}"}
    ]
    
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=messages,
        max_tokens=200  # Adjusted for potentially complex SVA generation
    )
    return response['choices'][0]['message']['content'].strip()

def refine_sva_with_openai(sva_code, errors):
    """
    Refines the given SVA code based on identified errors using the OpenAI chat model.
    """
    messages = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": f"Refine the following SystemVerilog assertion based on the identified errors:\nSVA Code: {sva_code}\nErrors: {errors}\nPlease provide the corrected SVA."}
    ]
    
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=messages,
        max_tokens=250
    )
    return response['choices'][0]['message']['content'].strip()

