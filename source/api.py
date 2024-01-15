import json
import os

import requests
import sseclient

from inference import *

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
        response = requests.get(self.endpoint, headers=self.getHeaders())
        if response.status_code != 400 and response.status_code != 200:
            try:
                response.raise_for_status()
            except:
                raise Exception(f"Connection failed with {response.status_code}: {response.text}")

    def process(self, request):
        try:
            req = request
            typ = req["type"]

            if typ == "options":
                response = requests.get(self.endpoint + "models/info?=", headers=self.getHeaders())
                result = json.loads(response.text)
                self.models = {}
                for model in result:
                    if "display_type" in model and model["display_type"] in {"chat", "lanaguage"}:
                        self.models[model["name"]] = model["display_name"]
                
                names = [v for _,v in self.models.items()]
                self.respond({"type":"options", "data": {"models": names}})

            if typ == "generate":
                self.setStatus("generating")
                
                stop = req["data"]["stop_condition"]
                del req["data"]["stop_condition"]

                stop_context = ""
                if stop == "Sentance":
                    sentance, _ = split_sentances(req["data"]["prompt"])
                    stop_context = sentance.lstrip()

                payload = req["data"].copy()
                payload["stream_tokens"] = True
                payload["model"] = [k for k,v in self.models.items() if v == payload["model"]][0]

                response = requests.post(self.endpoint + "inference", json=payload, headers=self.getHeaders(), stream=True)
                try:
                    response.raise_for_status()
                except:
                    raise Exception(f"{response.status_code}: {response.text}")
                client = sseclient.SSEClient(response)   

                output = ""
                errored = False
                stopping = False

                for event in client.events():
                    if event.data == "[DONE]":
                        break
                    partial_result = json.loads(event.data)
                    next = partial_result["choices"][0]["text"]

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