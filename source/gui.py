import os
import random
import string
import json
import platform
import copy
import time
from datetime import datetime
import unicodedata
IS_WIN = platform.system() == 'Windows'

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, QObject, QUrl, QThread, QMimeData, QByteArray
from PyQt5.QtGui import QDesktopServices, QDrag, QClipboard, QSyntaxHighlighter
from PyQt5.QtWidgets import QApplication
from PyQt5.QtSql import QSqlQuery
from PyQt5.QtQml import qmlRegisterUncreatableType

import sql
import backend
import misc
import git
import tabs

SOURCE_REPO = "https://github.com/arenasys/lineworks"
DEFAULT_PRESETS = {
    "Simple": {
        "temperature": 0.7,
        "top_p": 0.9,
        "top_k": 20,
        "repeat_penalty": 1.15
    }
}

class Update(QThread):
    def run(self):
        git.gitReset(".", SOURCE_REPO)

class HistoryEntry(QObject):
    updated = pyqtSignal()
    def __init__(self, gui):
        super().__init__(gui)
        self.gui = gui
        
        self._context = ""
        self._trailing = ""

        self._parameters = {}
        self._model = {}
        self._output = ""
        self._time = 0

    @pyqtProperty(str, notify=updated)
    def label(self):
        return datetime.fromtimestamp(self._time/1000).strftime("%I:%M %p %b %d")
    
    @pyqtProperty(str, notify=updated)
    def content(self):
        a = self._context.replace("\n", "<br>")
        b = self._output.rstrip().replace("\n", "<br>")

        return f'<span style=\'color: "#808080";\'>{a}</span>{b}'
    
    def toJSON(self):
        data = {
            "context": self._context,
            "output": self._output,
            "time": self._time,
            "trailing": self._trailing,
            "gen": copy.deepcopy(self._parameters),
            "model": copy.deepcopy(self._model)
        }
        return data
    
    def fromJSON(self, data):
        self._context = data["context"]
        self._output = data["output"]
        self._time = data["time"]
        self._trailing = data["trailing"]
        self._parameters = copy.deepcopy(data["gen"])
        self._model = copy.deepcopy(data["model"])
        self.updated.emit()

class GUI(QObject):
    updated = pyqtSignal()
    workingUpdated = pyqtSignal()
    historyUpdated = pyqtSignal()
    aboutToQuit = pyqtSignal()
    errored = pyqtSignal(str, str)

    def __init__(self, parent):
        super().__init__(parent)
        self._db = sql.Database(self)

        self._gen_config = copy.deepcopy(DEFAULT_PRESETS)
        gen_default_name = list(self._gen_config.keys())[0]
        gen_default = self._gen_config[gen_default_name]

        self._gen_parameters = misc.VariantMap(self, gen_default, strict=True)
        self._gen_presets = misc.VariantMap(self, {
            "preset": gen_default_name,
            "presets": [list(self._gen_config.keys())]
        })
        self._gen_presets.updated.connect(self.syncPreset)
        self._gen_parameters.updated.connect(self.workingUpdated)

        self._model_parameters = misc.VariantMap(self, {
            "model_path": "",
            "model_paths": [],
            "n_gpu_layers": 128,
            "n_ctx": 2048
        }, strict=True)
        self._model_config = {}
        self._model_parameters.updated.connect(self.modelUpdated)

        self._stop_parameters = misc.VariantMap(self, {
            "max_tokens": 128,
            "stop_condition": "None",
            "stop_conditions": ["None", "Sentance", "Paragraph", "Line"]
        }, strict=True)

        self._backend_parameters = misc.VariantMap(self, {
            "endpoint": "ws://127.0.0.1:29999",
            "password": "",
            "mode": "Local",
            "modes": ["Local", "Remote"]
        }, strict=True)
        self._backend_parameters.updated.connect(self.backendUpdated)

        self._file = None
        self._recent = []

        self.initConfig()

        self._tabs = tabs.Tabs(self)

        self._status = "idle"
        self._remote_status = "disconnected"

        self._pending_model = None
        self._current_model = None
        self._current_tab = None

        self._conn = sql.Connection(self)
        self._conn.connect()
        self._conn.doQuery("CREATE TABLE history(id TEXT);")
        self._conn.enableNotifications("history")
        self._history = {}
        self._current_entry = None

        parent.aboutToQuit.connect(self.stop)

        self._needRestart = False
        self._gitInfo = None
        self._gitCommit = None
        self._triedGitInit = False
        self._updating = False
        #self.getVersionInfo()

        self._backend = None
        self.restartBackend()

    @pyqtProperty('QString', notify=updated)
    def title(self):
        if self._file:
            name = self._file.rsplit(os.path.sep,1)[-1]
            return name + " - Lineworks"
        return "Lineworks"
    
    @pyqtProperty('QString', notify=updated)
    def file(self):
        if self._file:
            return self._file
        return ""
    
    @pyqtProperty(list, notify=updated)
    def recent(self):
        return self._recent

    @pyqtProperty(tabs.Tabs, notify=updated)
    def tabs(self):
        return self._tabs

    @pyqtProperty(misc.VariantMap, notify=updated)
    def generateParameters(self):
        return self._gen_parameters
    
    @pyqtProperty(misc.VariantMap, notify=updated)
    def generatePresets(self):
        return self._gen_presets
    
    @pyqtSlot(str, str)
    def renamePreset(self, new, old):
        if not new or new == old:
            return

        altered = self.presetIsAltered
        if old in self._gen_config:
            self._gen_config[new] = self._gen_parameters._map.copy()
            if not altered:
                del self._gen_config[old]
            self.commitPresets(new)

    @pyqtSlot()
    def savePreset(self):
        cfg = self._gen_parameters._map.copy()
        name = self._gen_presets.get("preset")
        self._gen_config[name] = cfg
        self.commitPresets(name)

    @pyqtSlot()
    def deletePreset(self):
        name = self._gen_presets.get("preset")
        if name in self._gen_config:
            del self._gen_config[name]
        if not self._gen_config:
            self._gen_config = copy.deepcopy(DEFAULT_PRESETS)
        self.commitPresets()

    @pyqtSlot()
    def syncPreset(self):
        preset = self._gen_presets.get("preset")
        if preset in self._gen_config:
            parameters = self._gen_config[preset]
            for k, v in parameters.items():
                self._gen_parameters.set(k, v)

    @pyqtSlot()
    def resetPreset(self):
        preset = self._gen_presets.get("preset")
        if preset in self._gen_config:
            for k,v in self._gen_config[preset].items():
                self._gen_parameters.set(k,v)
        self.workingUpdated.emit()

    @pyqtSlot()
    def newPreset(self):
        count = len(self._gen_presets.get("presets"))
        name = f"Preset {count+1}"
        cfg = self._gen_parameters._map.copy()
        self._gen_config[name] = cfg
        self.commitPresets(name)

    def commitPresets(self, name=None):
        self.saveConfig()
        self.loadConfig()
        if name:
            self._gen_presets.set("preset", name)
        self.workingUpdated.emit()

    @pyqtProperty(misc.VariantMap, notify=updated)
    def modelParameters(self):
        return self._model_parameters
    
    @pyqtSlot(str)
    def modelUpdated(self, key):
        if key == "model_path":
            self.resetModel()
        self.workingUpdated.emit()
    
    @pyqtSlot()
    def resetModel(self):
        model = self._model_parameters.get("model_path")
        if model in self._model_config:
            for k,v in self._model_config[model].items():
                self._model_parameters.set(k,v)
        return
    
    @pyqtProperty(misc.VariantMap, notify=updated)
    def stopParameters(self):
        return self._stop_parameters
    
    @pyqtProperty(misc.VariantMap, notify=updated)
    def backendParameters(self):
        return self._backend_parameters
    
    @pyqtSlot(str)
    def backendUpdated(self, key):
        if key == "mode":
            self.restartBackend()
        self.workingUpdated.emit()

    @pyqtSlot()
    def restartBackend(self):
        if self._backend:
            self._backend.response.disconnect()
            self._backend.stop()
            if not self._backend.wait(500):
                self._backend.terminate()

        self._pending_model = None
        self._current_model = None
        self._status = "idle"
        self.workingUpdated.emit()

        mode = self._backend_parameters.get("mode")
        if mode == "Local":
            self._backend = backend.LocalBackend(self)
        else:
            endpoint = self._backend_parameters.get("endpoint")
            password = self._backend_parameters.get("password")
            self._backend = backend.RemoteBackend(self, endpoint, password)
        self._backend.response.connect(self.onResponse)
        self._backend.start()

    @pyqtSlot(str, result=HistoryEntry)
    def getHistory(self, id):
        return self._history[int(id)]

    @pyqtSlot(HistoryEntry)
    def addHistory(self, entry):
        id = entry._time
        self._history[id] = entry

        q = QSqlQuery(self._conn.db)
        q.prepare("INSERT INTO history(id) VALUES (:id);")
        q.bindValue(":id", str(id))
        self._conn.doQuery(q)

    @pyqtSlot()
    def clearHistory(self):
        self._history = {}
        q = QSqlQuery(self._conn.db)
        q.prepare("DELETE FROM history;")
        self._conn.doQuery(q)

    @pyqtSlot()
    def stop(self):
        self.aboutToQuit.emit()

    @pyqtSlot()
    def quit(self):
        QApplication.quit()

    @pyqtSlot(str)
    def openPath(self, path):
        QDesktopServices.openUrl(QUrl.fromLocalFile(path))

    @pyqtSlot(str)
    def openLink(self, link):
        try:
            QDesktopServices.openUrl(QUrl.fromUserInput(link))
        except Exception:
            pass

    @pyqtSlot(str)
    def copyText(self, text):
        QApplication.clipboard().setText(text)
    
    @pyqtSlot(result=str)
    def pasteText(self):
        return QApplication.clipboard().text()
    
    @pyqtSlot(list)
    def visitFiles(self, files):
        folder = os.path.dirname(files[0])
        if IS_WIN:
            try:
                misc.showFilesInExplorer(folder, files)
            except:
                pass
        else:
            self.openPath(folder)

    @pyqtProperty(str, notify=updated)
    def versionInfo(self):
        return self._gitInfo

    @pyqtProperty(bool, notify=updated)
    def needRestart(self):
        return self._needRestart
    
    @pyqtProperty(bool, notify=updated)
    def updating(self):
        return self._updating

    @pyqtSlot()
    def getVersionInfo(self):
        self._updating = False
        self._gitInfo = "Unknown"
        commit, label = git.gitLast(".")
        if commit:
            if self._gitCommit == None:
                self._gitCommit = commit
            self._gitInfo = label
            self._needRestart = self._gitCommit != commit
        elif not self._triedGitInit:
            self._triedGitInit = True
            git.gitInit(".", SOURCE_REPO)
        self.updated.emit()

    @pyqtSlot()
    def update(self):
        self._updating = True
        update = Update(self)
        update.finished.connect(self.getVersionInfo)
        update.start()
        self.updated.emit()

    @pyqtSlot()
    def load(self):
        parameters = {k:v for k,v in self._model_parameters._map.items() if not k in {"model_paths"}}
        self._pending_model = parameters
        self.workingUpdated.emit()

        request = {
            "type": "load",
            "data": parameters
        }
        self._backend.makeRequest(request)

    @pyqtSlot()
    def unload(self):
        request = {"type": "unload"}
        self._pending_model = self._current_model
        self.workingUpdated.emit()

        self._backend.makeRequest(request)

    @pyqtProperty(bool, notify=workingUpdated)
    def presetIsAltered(self):
        preset = self._gen_presets.get("preset")
        altered = False
        if preset in self._gen_config:
            for k,v in self._gen_config[preset].items():
                if v != self._gen_parameters.get(k):
                    altered = True
                    break
        return altered

    @pyqtProperty(bool, notify=workingUpdated)
    def modelIsAltered(self):
        if not self._current_model:
            return False
        for k,v in self._current_model.items():
            if self._model_parameters._map[k] != v:
                return True
        return False

    @pyqtProperty(bool, notify=workingUpdated)
    def modelIsWorking(self):
        return self._pending_model != None
    
    @pyqtProperty(bool, notify=workingUpdated)
    def modelIsLoaded(self):
        return self._current_model != None
    
    @pyqtProperty(bool, notify=workingUpdated)
    def isGenerating(self):
        return self._status == "generating"
    
    @pyqtProperty(bool, notify=workingUpdated)
    def isConnected(self):
        return self._remote_status == "connected"
    
    @pyqtProperty(bool, notify=workingUpdated)
    def isConnecting(self):
        return self._remote_status == "connecting"
    
    @pyqtProperty(str, notify=workingUpdated)
    def currentModel(self):
        if self._current_model:
            return self._current_model["model_path"]
        if self._pending_model:
            return self._pending_model["model_path"]
        return ""

    @pyqtSlot()
    def generate(self):
        area = self._tabs.current
        self._current_tab = area._tabs[area.current]
        parameters = copy.deepcopy(self._gen_parameters._map)
        parameters["prompt"] = self._current_tab.context()
        parameters["max_tokens"] = self._stop_parameters.get("max_tokens")
        parameters["stop_condition"] = self._stop_parameters.get("stop_condition")

        self._current_tab.startStream()

        self._current_entry = HistoryEntry(self)
        self._current_entry._context = self._current_tab.context()
        self._current_entry._trailing = self._current_tab.trailing()
        self._current_entry._parameters = copy.deepcopy(parameters)

        model = copy.deepcopy(self._model_parameters._map)
        del model["model_paths"]
        self._current_entry._model = model
        
        request = {
            "type": "generate",
            "data": parameters
        }

        self._backend.makeRequest(request)

    @pyqtSlot()
    def regenerate(self):
        area = self._tabs.current
        self._current_tab = area._tabs[area.current]
        self._current_tab.revert()
        self.generate()

    @pyqtSlot()
    def abort(self):
        self._backend.makeRequest({"type":"abort"})

    @pyqtSlot(object)
    def onResponse(self, response):
        typ = response["type"]

        if typ == "status":
            status = response["data"]["message"]
            if status in {"connected", "connecting", "disconnected"}:
                self._remote_status = status
            else:
                self._status = status
            self.workingUpdated.emit()

        if typ == "options":
            model = self._model_parameters.get("model_path")
            models = response["data"]["models"]

            self._model_parameters.set("model_paths", models)
            if not model in models and models:
                self._model_parameters.set("model_path", models[0])
            if not models:
                self._model_parameters.set("model_path", "")

        if typ == "done":
            if self._status == "loading":
                self._current_model = self._pending_model
                self._pending_model = None

                name = self._current_model["model_path"]
                cfg = {k:v for k,v in self._current_model.items() if not k == "model_path"}
                self._model_config[name] = cfg
                self.saveConfig()

            if self._status == "unloading":
                self._current_model = None
                self._pending_model = None

            self._status = "idle"
            self.workingUpdated.emit()

        if typ == "output":
            output = ''.join([c for c in response["data"]["output"] if ord(c) < 0x10000])
            self._current_entry._output = output
            self._current_entry._time = int(time.time()*1000)
            self.addHistory(self._current_entry)
            self._current_entry = None

        if typ == "error":
            self.errored.emit(response["data"]["message"].capitalize(), self._status.capitalize())
            self._status = "idle"
            self._pending_model = None
            self.workingUpdated.emit()
        
        if typ == "aborted":
            self._status = "idle"
            self.workingUpdated.emit()

        if typ == "stream":
            stream = ''.join([c for c in response["data"]["next"] if ord(c) < 0x10000])
            self._current_tab.stream(stream)

    @pyqtSlot()
    def initConfig(self):
        if not os.path.exists("config.json"):
            self.saveConfig()
        self.loadConfig()  

    @pyqtSlot()
    def saveConfig(self):
        config = {
            "models":  self._model_config,
            "presets": self._gen_config,
            "recent": self._recent
        }
        try:
            with open("config.json", 'w', encoding="utf-8") as f:
                json.dump(config, f, indent=4)
        except Exception:
            return
        
    @pyqtSlot()
    def loadConfig(self):
        config = {}
        try:
            with open("config.json", 'r', encoding="utf-8") as f:
                config = json.load(f)
        except Exception:
            return
        
        self._recent = config.get("recent", [])
        self._model_config = config.get("models", {})
        self._gen_config = config.get("presets", {})
        presets = list(self._gen_config.keys())
        self._gen_presets.set("presets", presets)
        if presets and not self._gen_presets.get("preset") in presets:
            self._gen_presets.set("preset", presets[0])

    def toJSON(self):
        model = copy.deepcopy(self._model_parameters._map)
        del model["model_paths"]

        gen = copy.deepcopy(self._gen_parameters._map)
        gen["preset"] = self._gen_presets.get("preset")

        stop = copy.deepcopy(self._stop_parameters._map)
        del stop["stop_conditions"]

        data = {
            "gen": gen,
            "model": model,
            "stop": stop,
            "areas": self._tabs.toJSON(),
            "history": [entry.toJSON() for entry in self._history.values()]
        }
        return data
    
    def fromJSON(self, data):
        preset = data["gen"]["preset"]
        self._gen_presets.set("preset", preset)
        for k,v in data["gen"].items():
            if not k == "preset":
                self._gen_parameters.set(k,v)
        if not preset in self._gen_presets.get("presets"):
            self.savePreset()

        model = data["model"]["model_path"]
        if model in self._model_parameters.get("model_paths"):
            self._model_parameters.set("model_path", model)

        for k,v in data["model"].items():
            if not k == "model_path":
                self._model_parameters.set(k,v)
        
        for k,v in data["stop"].items():
            self._stop_parameters.set(k,v)

        self.historyFromJSON(data["history"])
        self.tabsFromJSON(data["areas"])

    def historyFromJSON(self, data):
        self.clearHistory()

        for data_entry in data:
            entry = HistoryEntry(self)
            entry.fromJSON(data_entry)
            self.addHistory(entry)

    def tabsFromJSON(self, data):
        self._tabs.clearAreas()

        for data_area in data:
            area = tabs.TabArea(self._tabs, data_area["position"])
            for data_tab in data_area["tabs"]:
                tab = tabs.Tab(area, data_tab["name"])
                tab._content = data_tab["content"]
                tab._marker = data_tab["marker"]
                area.addTab(tab)
            self._tabs.addArea(area)

    def doSave(self, file):
        self._file = file
        if not file in self._recent:
            self._recent = [file] + self._recent
            self.saveConfig()
        self.updated.emit()

        data = self.toJSON()
        try:
            with open(file, 'w', encoding="utf-8") as f:
                json.dump(data, f, indent=4)
        except Exception:
            return

    @pyqtSlot(str)
    def saveAs(self, file):
        file = os.path.abspath(QUrl(file).toLocalFile())
        self.doSave(file)

    @pyqtSlot()
    def save(self):
        self.doSave(self._file)

    def doOpen(self, file):
        self._file = file

        self._recent = [file] + [f for f in self._recent if not f == file]
        self.saveConfig()
        self.updated.emit()

        data = None
        try:
            with open(file, 'r', encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            return
        self.fromJSON(data)

    @pyqtSlot(str)
    def open(self, file):
        file = os.path.abspath(QUrl(file).toLocalFile())
        self.doOpen(file)

    @pyqtSlot(int)
    def openRecent(self, index):
        file = self._recent[index]
        self.doOpen(file)

    @pyqtSlot()
    def new(self):
        self._file = ""
        self.clearHistory()
        self._tabs.clearAreas()
        self._tabs.addDefaultArea()
        self.updated.emit()
        self.historyUpdated.emit()
    
def registerTypes():
    qmlRegisterUncreatableType(HistoryEntry, "gui", 1, 0, "HistoryEntry", "Not a QML type")