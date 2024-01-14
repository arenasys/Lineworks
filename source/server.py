import time
import copy
import argparse
import threading

import websockets.sync.client
import websockets.sync.server
import websockets.exceptions
import secrets
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag
import bson

import inference

DEFAULT_KEY = "Lineworks"
FRAGMENT_SIZE = 524288

def get_scheme(key):
    key = key.encode("utf8")
    h = hashes.Hash(hashes.SHA256())
    h.update(key)
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=h.finalize()[:16],
        iterations=480000,
    )
    return AESGCM(kdf.derive(key))

def encrypt(scheme, obj):
    data = bson.dumps(obj)
    if scheme:
        nonce = secrets.token_bytes(16)
        data = nonce + scheme.encrypt(nonce, data, b"")
    return data

def decrypt(scheme, data):
    if scheme:
        data = scheme.decrypt(data[:16], data[16:], b"")
    obj = bson.loads(data)
    return obj


class RemoteServer():
    def __init__(self, host, port, models_path, key):
        self.key = key
        self.models_path = models_path
        
        self.inference = None
        self.server = websockets.sync.server.serve(self.handleConnection, host=host, port=int(port), max_size=None)
        self.serve = threading.Thread(target=self.serve_forever, daemon=True)

    def start(self):
        print("SERVER: starting")
        self.serve.start()

    def stop(self):
        print("SERVER: stopping")
        self.server.shutdown()
        self.join()
        print("SERVER: done")

    def join(self, timeout=None):
        self.serve.join(timeout)
        if self.serve.is_alive():
            return False # timeout
        return True

    def serve_forever(self):
        self.server.serve_forever()
            
    def handleLoop(self, conn):
        scheme = get_scheme(self.key)

        ctr = 0
        while True:
            while self.responses:
                response = self.responses.pop(0)

                data = encrypt(scheme, response)
                data = [data[i:min(i+FRAGMENT_SIZE,len(data))] for i in range(0, len(data), FRAGMENT_SIZE)]

                try:
                    conn.send(data)
                except:
                    return
            
            data = None
            try:
                data = conn.recv(timeout=0)
            except TimeoutError:
                pass
            except websockets.exceptions.ConnectionClosed:
                break
            except Exception as e:
                print(type(e), e)
                break

            if not data:
                time.sleep(0.01)
                ctr += 1
                if ctr == 200:
                    conn.ping()
                    ctr = 0
                continue

            error = None
            request = None
            if type(data) in {bytes, bytearray}:
                try:
                    request = decrypt(scheme, bytes(data))
                except Exception as e:
                    error = "incorrect key"
            else:
                error = "invalid request"
            if request:
                if request["type"] == "abort":
                    self.inference.abort = True
                else:
                    self.requests += [request]
            else:
                self.responses += [{"type": "error", "data": {"message": error}}]
        self.inference.abort = True
            
    def makeResponse(self,response):
        response = copy.deepcopy(response)
        self.responses += [response]

    def handleConnection(self, conn):
        print("SERVER: client connected")

        self.responses = []
        self.requests = []
        self.inference = inference.Inference(self.models_path, self.makeResponse)
        thread = threading.Thread(target=self.handleLoop, args=(conn,), daemon=True)

        thread.start()

        while True:
            while not self.requests and thread.is_alive():
                time.sleep(0.01)
            if not thread.is_alive():
                break
            request = self.requests.pop(0)
            self.inference.process(request)

        print("SERVER: client disconnected")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='lineworks server')
    parser.add_argument('--bind', type=str, help='address (ip:port) to listen on', default="127.0.0.1:29999")
    parser.add_argument('--key', type=str, help='key to derive encryption key from', default=DEFAULT_KEY)
    parser.add_argument('--models', type=str, help='models path', default="models")
    args = parser.parse_args()

    ip, port = args.bind.rsplit(":",1)

    server = RemoteServer(ip, port, args.models, args.key)
    server.start()
    
    try:
        while True:
            time.sleep(0.01)
    except KeyboardInterrupt:
        pass
    server.stop()