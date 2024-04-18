ChIRAAG: An automated LLM-based SVA generation framework.

Codebase :
1)main.py : Call to all the functions[call_openai_for_sva, extract_errors_from_log].
2)openai_utils.py: Prompts are defined here.
4)loh_parser.py : 
3)sva_refinement.py: Iterative call to the LLM to make refinement of the assertions based on the error log.




Running process :

python3 main.py 
