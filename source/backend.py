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

MODELS_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models")

class LocalBackend(QThread):
    response = pyqtSignal(object)
    def __init__(self, gui):
        super().__init__(gui)
        self.gui = gui
        self.stopping = False
        self.requests = []
        self.inference = inference.Inference(MODELS_PATH, self.makeResponse)
        
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

from server import *

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