### Lineworks
--------
An desktop native LLM integrated text editor built for cowriting. Focuses on efficient and hassle-free usage.

![example](https://github.com/arenasys/Lineworks/raw/master/screenshot.png)
\*new\* Discord: [Arena Systems](https://discord.gg/WdjKqUGefU).

## About
Designed for rapidly iterating on text. Generate at any position, quickly revert and regenerate, hotkeys for everything and stopping conditions useful for writing (Sentence, Line, Paragraph). Organized with multiple tabs and working areas that can be saved and restored to a file. Autosaves every two minutes and keeps the outputs from the current session in a searchable history, so you dont lose anything.

Local and remote generation is available ([TogetherAI](https://www.together.ai/) and [OpenAI](https://openai.com/) HTTP APIs are support). Different color schemes available (Light, Classic).

## Usage
To use: [Download](https://github.com/arenasys/Lineworks/archive/refs/heads/master.zip) Lineworks, extract the archive, and then run. NVIDIA or AMD* GPU acceleration is available to choose during install, otherwise choose CPU. Updating is done inside Lineworks via `File->Update`. Linux users run with `bash source/start.sh`.

Uses [llama.cpp](https://github.com/ggerganov/llama.cpp) with its self-contained and quantized model format, GGUF. [Many](https://huggingface.co/TheBloke?search_models=gguf) models are available, for starters try: [Mistral-7B](https://huggingface.co/TheBloke/Mistral-7B-v0.1-GGUF/blob/main/mistral-7b-v0.1.Q5_K_M.gguf). `.gguf` models placed inside the `models` folder will be available to use in Lineworks.

Saving and loading is done with `.json` files, these store the current state of Lineworks. Autosaving is done every two minutes if a save file is open. Lineworks is intended to be operated via keyboard shortcuts, they are all displayed next to their corresponding action in the top menu bar.

*AMD on Windows is still experimental, see [here](https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/tag/rocm) for details.

## Remote
### Together.AI
Currently the easiest way to generate remotely since they are giving free credit to new accounts. 
First [Sign up](http://api.together.ai/), then head to [API Keys](https://api.together.xyz/settings/api-keys) and copy your key. Switch the Lineworks backend from Local to Remote, put `https://api.together.xyz/` as the Endpoint and your API Key as the Key. Press the connect button.

### Websockets
Lineworks has its own websocket API which acts closer to Local than the HTTP APIs. Server hosting is done with `python3.10 source/server.py`, for example:
```
cd ~
git clone https://github.com/arenasys/lineworks
cd ~/lineworks/models
wget https://huggingface.co/TheBloke/Mistral-7B-v0.1-GGUF/resolve/main/mistral-7b-v0.1.Q5_K_M.gguf
cd ~/lineworks
pip install websockets==11.0.3 bson==0.5.10 cryptography==40.0.2 
pip install https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/wheels/llama_cpp_python-0.2.20+cu120-cp310-cp310-manylinux_2_31_x86_64.whl
python source/server.py --bind "127.0.0.1:8080"
```
Which will be accessible on `ws://127.0.0.1:8080`. Different llama-cpp wheels will be needed depending on the system: CUDA 12 (cu120), CUDA 11.8 (cu118), etc.