import os
import glob
import queue
import threading
import time
import copy
import argparse

from PyQt5.QtCore import pyqtSlot, pyqtSignal, QThread
from PyQt5.QtWidgets import QApplication

import inference

class LocalBackend(QThread):
    response = pyqtSignal(object)
    def __init__(self, gui):
        super().__init__(gui)
        self.gui = gui
        self.stopping = False
        self.requests = []
        self.inference = inference.Inference(self.makeResponse)
        
    def run(self):
        self.inference.process({"type":"options"})

        while not self.stopping:
            QApplication.processEvents()
            if self.requests:
                request = self.requests.pop(0)
                self.inference.process(request)
            else:
                QThread.msleep(10)

    @pyqtSlot()
    def stop(self):
        self.inference.stop()
        self.stopping = True

    @pyqtSlot()
    def makeRequest(self, request):
        if request["type"] == "abort":
            self.inference.abort = True
        request = copy.deepcopy(request)
        self.requests += [request]

    @pyqtSlot()
    def makeResponse(self, response):
        self.response.emit(response)

import websockets.sync.client
import websockets.sync.server
import websockets.exceptions
import secrets
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag
import bson

DEFAULT_PASSWORD = "Lineworks"
FRAGMENT_SIZE = 524288

def get_scheme(password):
    password = password.encode("utf8")
    h = hashes.Hash(hashes.SHA256())
    h.update(password)
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=h.finalize()[:16],
        iterations=480000,
    )
    return AESGCM(kdf.derive(password))

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

class RemoteBackend(QThread):
    response = pyqtSignal(object)
    def __init__(self, gui, endpoint, password=None):
        super().__init__(gui)
        self.gui = gui
        self.stopping = False
        self.requests = []

        self.endpoint = endpoint
        self.client = None

        self.scheme = None
        if not password:
            password = DEFAULT_PASSWORD
        self.password = password

    def connect(self):
        if self.client:
            return
        self.makeResponse({"type": "status", "data": {"message": "connecting"}})
        while not self.client and not self.stopping:
            try:
                self.client = websockets.sync.client.connect(self.endpoint, open_timeout=2, max_size=None)
            except TimeoutError:
                pass
            except ConnectionRefusedError:
                self.makeResponse({"type": "error", "data": {"message": "connection refused"}})
                return
            except Exception as e:
                self.makeResponse({"type": "error", "data": {"message": str(e)}})
                return
        if self.stopping:
            return
        if self.client:
            self.makeResponse({"type": "status", "data": {"message": "connected"}})
            self.requests += [{"type":"options"}]

    def run(self):
        self.scheme = get_scheme(self.password)
        self.connect()
        while self.client and not self.stopping:
            try:
                while True:
                    try:
                        data = self.client.recv(0)
                        response = decrypt(self.scheme, data)
                        self.makeResponse(response)
                        QApplication.processEvents()
                    except TimeoutError:
                        break
                
                if self.requests:
                    request = self.requests.pop(0)
                    data = encrypt(self.scheme, request)
                    data = [data[i:min(i+FRAGMENT_SIZE,len(data))] for i in range(0, len(data), FRAGMENT_SIZE)]

                    self.client.send(data)
                    QApplication.processEvents()
                else:
                    QThread.msleep(5)

            except websockets.exceptions.ConnectionClosed:
                self.makeResponse({"type": "error", "data": {"message": "connection closed"}})
                break
            except Exception as e:
                if type(e) == InvalidTag or type(e) == IndexError:
                    self.makeResponse({"type": "error", "data": {"message": "incorrect password"}})
                else:
                    self.makeResponse({"type": "error", "data": {"message": str(e)}})
                break
        
        self.makeResponse({"type": "status", "data": {"message": "disconnected"}})

        if self.client:
            self.client.close()
            self.client = None

    @pyqtSlot()
    def stop(self):
        self.stopping = True
        if self.client:
            self.client.close()
            self.client = None

    @pyqtSlot()
    def makeRequest(self, request):
        request = copy.deepcopy(request)
        self.requests += [request]

    @pyqtSlot()
    def makeResponse(self, response):
        self.response.emit(response)

class RemoteServer():
    def __init__(self, host, port, password=None):
        if not password:
            password = DEFAULT_PASSWORD
        self.password = password
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
        scheme = get_scheme(self.password)

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
                    error = "incorrect password"
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
        self.inference = inference.Inference(self.makeResponse)
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
    parser.add_argument('--password', type=str, help='password to derive encryption key from', default=DEFAULT_PASSWORD)
    args = parser.parse_args()

    ip, port = args.bind.rsplit(":",1)

    server = RemoteServer(ip, port)
    server.start()
    
    try:
        while True:
            time.sleep(0.01)
    except KeyboardInterrupt:
        pass
    server.stop()