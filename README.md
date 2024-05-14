# **ChIRAAG : An Automated LLM-Based SVA Generation Framework**

ChIRAAG is designed to automate the generation of SystemVerilog Assertions (SVA) using Large Language Models (LLMs). This framework simplifies the process of creating and refining SVAs by leveraging the OpenAI API and a command-line interface.

## **Requirements**
1. **OpenAI API**
2. **Command Line Interface**

## **Installation**
First, install the required Python package using pip:
```bash
pip install openapi
```

## **Environment variables**
```bash
nano ~/.bashrc
export API_KEY="your_api_key_here"
source ~/.bashrc
```
## **Codebase:**

**1)main.py :** Call to all the functions[call_openai_for_sva, extract_errors_from_log].

**2)openai_utils.py:** All the preliminaries and dynamic prompting.

**3)log_parser.py:** Used to parse the log file of the send to LLM.

**4)sva_refinement.py:** Iterative call the LLM to refine the assertions based on the error log.


## **Citation:**
**If you use ChIRAAG for your research, please cite our paper:**
```bash
@misc{mali2024chiraag,
      title={ChIRAAG: ChatGPT Informed Rapid and Automated Assertion Generation}, 
      author={Bhabesh Mali and Karthik Maddala and Sweeya Reddy and Vatsal Gupta and Chandan Karfa and Ramesh Karri},
      year={2024},
      eprint={2402.00093},
      archivePrefix={arXiv},
      primaryClass={cs.SE}
}
```
