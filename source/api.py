import json
import os

import requests
import sseclient

from inference import *

def get_models(endpoint, key):
    models = {}

    if "api.openai.com" in endpoint:
        response = requests.get(endpoint + "v1/models", headers={"Authorization": f"Bearer {key}"})
        response.raise_for_status()
        result = json.loads(response.text)
        for model in result["data"]:
            if "gpt-3.5-turbo-instruct" in model["id"] or model["id"] in {"davinci-002", "babbage-002"}:
                models[model["id"]] = model["id"]
    elif "api.together.xyz" in endpoint:
        response = requests.get(endpoint + "models/info?=", headers={"Authorization": f"Bearer {key}"})
        response.raise_for_status()
        result = json.loads(response.text)
        for model in result:
            if "display_type" in model and model["display_type"] in {"chat", "language"}:
                models[model["name"]] = model["display_name"]
    elif "api.anthropic.com" in endpoint:
        models = {
            "claude-3-opus-20240229": "Claude 3 Opus",
            "claude-3-sonnet-20240229": "Claude 3 Sonnet"
        }
    else:
        headers = {"Authorization": f"Bearer {key}"} if key.strip() else {}
        response = requests.get(endpoint + "v1/models", headers=headers)
        response.raise_for_status()
        result = json.loads(response.text)
        for model in result["data"]:
            models[model["id"]] = model["id"]
    
    return models

def get_stream(endpoint, key, parameters):
    if "api.openai.com" in endpoint:
        parameters["stream"] = True
        parameters["frequency_penalty"] = parameters["repeat_penalty"]
        del parameters["top_k"]
        del parameters["repeat_penalty"]
        headers = {"Authorization": f"Bearer {key}"}
        response = requests.post(endpoint + "v1/completions", json=parameters, headers=headers, stream=True)
    elif "api.together.xyz" in endpoint:
        parameters["stream_tokens"] = True
        parameters["repetition_penalty"] = parameters["repeat_penalty"]
        del parameters["repeat_penalty"]
        headers = {"Authorization": f"Bearer {key}"}
        response = requests.post(endpoint + "v1/completions", json=parameters, headers=headers, stream=True)
    elif "api.anthropic.com" in endpoint:
        headers = {"x-api-key": f"{key}", "content-type" : "application/json", "anthropic-version": "2023-06-01"}

        system = "[The AI follows instructions in square brackets.]"
        prefill = ""

        prompt = parameters["prompt"]        
        context = re.sub(r"\[[^\]|\n]+\]", "", prompt)
        if len(context) > 20:
            context = "..." + context[-80:].split(" ",1)[-1].rstrip("\n")
        has_prompt, has_context = prompt.strip() != "", context.strip() != ""
        
        messages = [
            {"role": "user", "content": "You are a cowriting assistant, you continue writing from existing text. Recall the text we were writing."},
        ]
        if has_prompt:
            messages.append({"role": "assistant", "content": 'The text you gave me was: ' + parameters["prompt"]})
        else:
            messages.append({"role": "assistant", "content": 'There is no text written so far.'})
        
        if has_prompt and has_context:
            messages.append({"role": "user", "content": "Continue writing from that text as best you can. Continue exactly where it left off."})
        elif has_prompt and not has_context:
            messages.append({"role": "user", "content": "Write text based off this."})
        elif not has_prompt:
            messages.append({"role": "user", "content": "Write whatever text comes to mind."})

        messages.append({"role": "assistant", "content": prefill + context})

        parameters = {
            "model": parameters["model"],
            "system": system,
            "max_tokens": parameters["max_tokens"],
            "stop_sequences": [ '\n\nHuman:', '\n\nSystem:', '\n\nAssistant:' ],
            "temperature": parameters["temperature"],
            "top_p": parameters["top_p"],
            "top_k": parameters["top_k"],
            "stream": True,
            "messages": messages
        }

        response = requests.post(endpoint + "v1/messages", json=parameters, headers=headers, stream=True)
    else:
        parameters["stream"] = True
        parameters["frequency_penalty"] = parameters["repeat_penalty"]
        del parameters["top_k"]
        del parameters["repeat_penalty"]
        headers = {"Authorization": f"Bearer {key}"} if key.strip() else {}
        response = requests.post(endpoint + "v1/completions", json=parameters, headers=headers, stream=True)   
    
    response.raise_for_status()
    
    client = sseclient.SSEClient(response)
    for event in client.events():
        if event.data == "[DONE]":
            break
        data = json.loads(event.data)

        if "choices" in data:
            yield data["choices"][0]["text"]

        if "type" in data:
            if data["type"] == "message_stop":
                break
            if data["type"] == "content_block_delta":
                yield data["delta"]["text"]
    return

class API():
    def __init__(self, endpoint, key, response):
        self.abort = False
        self.endpoint = endpoint
        self.key = key
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
        
    def getHeaders(self):
        return {
            "accept": "application/json",
            "content-type": "application/json",
            "Authorization": f"Bearer {self.key}",
        }

    def check(self):
        try:
            response = requests.get(self.endpoint, headers=self.getHeaders())
        except requests.exceptions.ConnectTimeout:
            raise Exception(f"Connection timed out")
        except requests.exceptions.ConnectionError:
            raise Exception(f"Connection refused")
        except Exception:
            raise Exception(f"Connection failed")
        
        try:
            get_models(self.endpoint, self.key)
        except requests.HTTPError as e:
            raise Exception(e)
        except Exception as e:
            print(e)
            raise Exception(f"Unknown Error")

    def process(self, request):
        try:
            req = request
            typ = req["type"]

            if typ == "options":
                self.models = get_models(self.endpoint, self.key)                
                names = [v for _,v in self.models.items()]
                self.respond({"type":"options", "data": {"models": names}})

            if typ == "generate":
                self.setStatus("generating")
                
                stop = req["data"]["stop_condition"]
                del req["data"]["stop_condition"]

                stop_context = ""
                if stop == "Sentence":
                    sentence, _ = split_sentences(req["data"]["prompt"])
                    stop_context = sentence.lstrip()

                parameters = req["data"].copy()
                parameters["model"] = [k for k,v in self.models.items() if v == parameters["model"]][0]

                output = ""
                errored = False
                stopping = False

                for next in get_stream(self.endpoint, self.key, parameters):
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
                        "model": {
                            "model_path": self.model
                        },
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

            
#https://api.together.xyz/inference