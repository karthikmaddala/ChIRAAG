from openai_utils import refine_sva_with_openai

def refine_sva_based_on_errors(sva_code, log_content):
    if "error" in log_content.lower():
        return refine_sva_with_openai(sva_code, log_content), True
    return sva_code, False

