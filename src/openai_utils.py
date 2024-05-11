import openai

def call_openai_for_sva(json_spec, prompts):
    """
    Calls OpenAI API to generate SVA based on a generic JSON hardware specification and user prompts.
    """
    messages = [{"role": "system", "content": "You are a helpful assistant capable of generating detailed SystemVerilog Assertions."}]
    messages.extend([{"role": "user", "content": prompt} for prompt in prompts])

    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=messages,
        max_tokens=500  # Adjust token count as needed
    )
    return response.choices[0].message['content'].strip()

def refine_sva_with_openai(sva_code, errors):
    """
    Refines the given SVA code based on identified errors using the OpenAI chat model.
    """
    prompt = f"Refine the following SystemVerilog assertion based on the identified errors:\nSVA Code: {sva_code}\nErrors: {errors}\nPlease provide the corrected SVA."
    messages = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": prompt}
    ]

    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=messages,
        max_tokens=1000  # Larger token limit for potentially complex refinements
    )
    return response.choices[0].message['content'].strip()

