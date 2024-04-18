# **ChIRAAG : An automated LLM-based SVA generation framework.**

**Codebase:**

**1)main.py :** Call to all the functions[call_openai_for_sva, extract_errors_from_log].

**2)openai_utils.py:** Prompts are defined here.

**3)log_parser.py:** Used to parse the log file of the send to LLM.

**4)sva_refinement.py:** Iterative call the LLM to refine the assertions based on the error log.




**Running process :**

python3 main.py 
