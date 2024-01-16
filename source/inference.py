import os
import glob
import sys
import datetime
import traceback
import re

PARAGRAPH_MATCH = re.compile(r"(.+\n[\s\n]*\n)", flags=re.UNICODE)
LINE_MATCH = re.compile(r"(.+\n)", flags=re.UNICODE)

def log_traceback(label):
    exc_type, exc_value, exc_tb = sys.exc_info()
    tb = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    with open("crash.log", "a", encoding='utf-8') as f:
        f.write(f"{label} {datetime.datetime.now()}\n{tb}\n")
    print(label, tb)
    return tb

def split_sentences(text):
    def get(i):
        if i < len(text):
            return f"{text[i]}"
        return None
    
    sentences = []
    sentence = ""
    end = False
    alpha = False
    while text:
        if end:
            end = False
            alpha = False
            sentences += [sentence]
            sentence = ""
        
        a, b, c = get(0), get(1), get(2)

        if a.isalpha():
            alpha = True

        if a in '.!?' and (b and b in '"') and alpha:
            sentence += a + b
            text = text[2:]
            end = True
            continue
        
        if a in '.!?…' and ((b and b in ' ') or not b) and alpha:
            sentence += a
            text = text[1:]
            end = True
            continue

        if not a in '\n' and (b and b in '\n') and alpha:
            sentence += a + b
            text = text[1:]
            end = True
            continue
            
        sentence += a
        text = text[1:]

    if end:
        sentences += [sentence]
        sentence = ""

    return sentence, sentences

class Inference():
    def __init__(self, models_path, response):
        self.abort = False
        self.llm = None
        self.model = None
        self.models_path = models_path
        self.callback = response

    def respond(self, response):
        self.callback(response)

    def setStatus(self, message):
        self.respond({"type": "status", "data": {"message": message}})

    def setDone(self):
        self.respond({"type": "done"})

    def setError(self, message):
        self.respond({"type": "error", "data": {"message": message}})

    def setAborted(self):
        self.respond({"type": "aborted"})
        self.abort = False

    def stop(self):
        self.abort = True

    def process(self, request):
        loaded = False
        err = None
        try:
            from llama_cpp_cuda import Llama
            loaded = True
        except ModuleNotFoundError:
            pass
        except Exception as e:
            log_traceback("IMPORT (CUDA)")
            err = e
            pass

        if not err and not loaded:        
            try:
                from llama_cpp import Llama
                loaded = True
            except Exception as e:
                log_traceback("IMPORT")
                err = e
                pass

        if not loaded:
            self.setError("failed to load llama-cpp-python: " + str(err))
            return

        try:
            req = request
            typ = req["type"]

            if typ == "load":
                self.setStatus("loading")
                if self.llm:
                    self.llm._model.__del__()
                try:
                    self.model = req["data"].copy()
                    model_path = req["data"]["model_path"]
                    req["data"]["model_path"] = os.path.join(self.models_path, f"{model_path}.gguf")
                    self.llm = Llama(verbose=False, **req["data"])
                except Exception as e:
                    log_traceback("INFERENCE")
                    self.setError("failed to load model: " + str(e))
                    return
                self.setDone()
                return
            if typ == "unload":
                self.setStatus("unloading")
                if self.llm:
                    self.llm._model.__del__()
                self.llm = None
                self.setDone()
                return
            if typ == "options":
                if not os.path.exists(self.models_path):
                    self.setError("failed to locate model folder: " + self.models_path)
                    return

                models = glob.glob(os.path.join(self.models_path, "**", "*.gguf"), recursive=True)
                models = [os.path.relpath(m, self.models_path).rsplit(".",1)[0] for m in models]
                self.respond({"type":"options", "data": {"models": models}})
                return
            if typ == "generate":
                if not self.llm:
                    self.setError("no model loaded")
                    return
                self.setStatus("generating")

                prompt = req["data"]["prompt"]
                n_ctx = self.llm._n_ctx
                n_req = req["data"]["max_tokens"]
                if prompt != "":
                    prompt_tokens = self.llm.tokenize(prompt.encode("utf-8"))
                    if len(prompt_tokens) + n_req > n_ctx:
                        prompt_tokens = prompt_tokens[-(n_ctx-n_req):]
                        prompt = self.llm.detokenize(prompt_tokens).decode("utf-8")
                        req["data"]["prompt"] = prompt
                
                stop = req["data"]["stop_condition"]
                del req["data"]["stop_condition"]

                stream = self.llm(echo=False, stream=True, **req["data"])

                stop_context = ""
                if stop == "Sentence":
                    sentence, _ = split_sentences(req["data"]["prompt"])
                    stop_context = sentence.lstrip()

                output = ""

                errored = False
                stopping = False
                for o in stream:
                    next = o["choices"][0]["text"]

                    if stop == "Sentence":
                        tmp = stop_context + output + next

                        sentence, sentences = split_sentences(tmp)
                        sentences += [sentence]

                        if len(sentences) > 1:
                            sentence = sentences[0]
                            next_tmp = sentence[len(stop_context + output):]
                            output_tmp = sentence[len(stop_context):]
                            if not output_tmp.strip():
                                stop_context = ""
                                output += next
                            else:
                                next = next_tmp
                                output = output_tmp
                                stopping = True
                        else:
                            output += next
                    elif stop == "Paragraph":
                        tmp = output + next
                        match = PARAGRAPH_MATCH.search(output + next)
                        if match:
                            paragraph = tmp[:match.end()]
                            next = paragraph[len(output):]
                            output = paragraph
                            stopping = True
                        else:
                            output += next
                    elif stop == "Line":
                        tmp = output + next
                        match = LINE_MATCH.search(output + next)
                        if match:
                            paragraph = tmp[:match.end()]
                            next = paragraph[len(output):]
                            output = paragraph
                            stopping = True
                        else:
                            output += next
                    elif stop == "None":
                        output += next

                    self.respond({"type":"stream", "data": {"next": next}})
                    if stopping:
                        break

                    if self.abort:
                        errored = True
                        break
                
                rsp = {
                    "type": "output",
                    "data": {
                        "parameters": req["data"].copy(),
                        "model": self.model.copy(),
                        "output": output,
                        "errored": errored
                    }
                }
                self.respond(rsp)
                if not errored:
                    self.setDone()
                else:
                    self.setAborted()
                return
        except Exception as e:
            self.setError(str(e))