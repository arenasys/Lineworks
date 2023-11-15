import os
import glob
import sys
import datetime
import traceback
import re

MODELS_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models")

PARAGRAPH_MATCH = re.compile(r"(.+\n[\s\n]*\n)", flags=re.UNICODE)
LINE_MATCH = re.compile(r"(.+\n)", flags=re.UNICODE)

def log_traceback(label):
    exc_type, exc_value, exc_tb = sys.exc_info()
    tb = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    with open("crash.log", "a", encoding='utf-8') as f:
        f.write(f"{label} {datetime.datetime.now()}\n{tb}\n")
    print(label, tb)
    return tb

def split_sentances(text):
    def get(i):
        if i < len(text):
            return f"{text[i]}"
        return None
    
    sentances = []
    sentance = ""
    end = False
    alpha = False
    while text:
        if end:
            end = False
            alpha = False
            sentances += [sentance]
            sentance = ""
        
        a, b, c = get(0), get(1), get(2)

        if a.isalpha():
            alpha = True

        if a in '.!?' and (b and b in '"') and alpha:
            sentance += a + b
            text = text[2:]
            end = True
            continue
        
        if a in '.!?…' and (b and b in ' ') and alpha:
            sentance += a
            text = text[1:]
            end = True
            continue

        if not a in '\n' and (b and b in '\n'):
            sentance += a + b
            text = text[1:]
            end = True
            continue
            
        sentance += a
        text = text[1:]

    if end:
        sentances += [sentance]
        sentance = ""

    return sentance, sentances

class Inference():
    def __init__(self, response):
        self.abort = False
        self.llm = None
        self.model = None
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
        loaded = ""
        try:
            from llama_cpp_cuda import Llama
            loaded = "gpu"
        except:
            pass
        try:
            from llama_cpp import Llama
            loaded = "cpu"
        except:
            pass

        if not loaded:
            self.setError("failed to load llama_cpp_python")
            return

        try:

            req = request
            typ = req["type"]

            if typ == "load":
                self.setStatus("loading")
                if self.llm:
                    self.llm.__del__()
                try:
                    self.model = req["data"].copy()
                    model_path = req["data"]["model_path"]
                    req["data"]["model_path"] = os.path.join(MODELS_PATH, f"{model_path}.gguf")
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
                    self.llm.__del__()
                self.llm = None
                self.setDone()
                return
            if typ == "options":
                models = glob.glob(os.path.join(MODELS_PATH, "*.gguf"))
                models = [m.rsplit(os.path.sep,1)[-1].rsplit(".",1)[0] for m in models]
                self.respond({"type":"options", "data": {"models": models, "device": loaded}})
                return
            if typ == "generate":
                if not self.llm:
                    self.setError("no model loaded")
                    return
                self.setStatus("generating")

                stop = req["data"]["stop_condition"]
                del req["data"]["stop_condition"]

                self.llm.reset()
                stream = self.llm(echo=False, stream=True, **req["data"])

                stop_context = ""
                if stop == "Sentance":
                    sentance, _ = split_sentances(req["data"]["prompt"])
                    stop_context = sentance

                output = ""

                errored = False
                stopping = False
                for o in stream:
                    next = o["choices"][0]["text"]

                    if stop == "Sentance":
                        tmp = stop_context + output + next

                        sentance, sentances = split_sentances(tmp)
                        sentances += [sentance]

                        if len(sentances) > 1:
                            sentance = sentances[0]
                            next_tmp = sentance[len(stop_context + output):]
                            output_tmp = sentance[len(stop_context):]
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

            