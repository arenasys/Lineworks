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

import backend
import misc
import git
import tabs
from tabs import Tab, TabArea
import spellcheck

SOURCE_REPO = "https://github.com/arenasys/Lineworks"
DEFAULT_PRESETS = {
    "Simple": {
        "temperature": 1.2,
        "min_p": 0.1,
        "top_p": 0.9,
        "top_k": 20,
        "repeat_penalty": 1.15
    },
}
DEFAULT_PRESET = "Simple"

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
        self._index = 0

    @pyqtProperty(str, notify=updated)
    def label(self):
        t = self._output.replace('\n','').strip()
        t = t if len(t) < 50 else t[:50]
        return t
    
    @pyqtProperty(str, notify=updated)
    def id(self):
        return str(self._time)
    
    @pyqtProperty(int, notify=updated)
    def index(self):
        return self._index
    
    @pyqtProperty(str, notify=updated)
    def context(self):
        a = self._context.replace("\n", "<br>")
        if len(a) > 40:
            a = a[-40:]
            
            i = 0
            try:
                i = a.index(' ')
            except:
                pass
            
            if i and i < 20:
                a = a[i+1:]

            a = "... " + a
        return f'<span style=\'color: "#808080";\'>{a}</span>'
    
    @pyqtProperty(str, notify=updated)
    def output(self):
        b = self._output.rstrip().replace("\n", "<br>")
        return b
    
    def contains(self, text):
        if text.casefold() in self._output.casefold():
            return True
        return False

    def toJSON(self):
        data = {
            "context": self._context,
            "output": self._output,
            "time": self._time,
            "index": self._index,
            "trailing": self._trailing,
            "gen": copy.deepcopy(self._parameters),
            "model": copy.deepcopy(self._model)
        }
        return data
    
    def fromJSON(self, data):
        self._context = data["context"]
        self._output = data["output"]
        self._time = data["time"]
        self._index = data["index"]
        self._trailing = data["trailing"]
        self._parameters = copy.deepcopy(data["gen"])
        self._model = copy.deepcopy(data["model"])
        self.updated.emit()

class GUI(QObject):
    updated = pyqtSignal()
    workingUpdated = pyqtSignal()
    historyUpdated = pyqtSignal()
    settingsUpdated = pyqtSignal()

    aboutToQuit = pyqtSignal()
    errored = pyqtSignal(str, str)
    clear = pyqtSignal()
    saving = pyqtSignal()
    failed = pyqtSignal()

    def __init__(self, parent, mode):
        super().__init__(parent)

        self._gen_config = copy.deepcopy(DEFAULT_PRESETS)
        gen_default_name = DEFAULT_PRESET
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
            "stop_conditions": ["Sentance", "Paragraph", "Line", "None"]
        }, strict=True)

        self._backend_parameters = misc.VariantMap(self, {
            "endpoint": "",
            "key": "",
            "mode": "Local",
            "modes": ["Local", "Remote"]
        }, strict=True)
        self._backend_parameters.updated.connect(self.backendUpdated)

        self._history = {}
        self._history_order = []
        self._history_search = ""
        self._history_results = []
        self._current_entry = None

        self._file = None
        self._recent = []

        self._spell_overlay = True
        self._stream_overlay = True
        self._position_overlay = True
        self._light_mode = False
        self._mode = mode

        self.initConfig()

        self._dictionary = spellcheck.Dictionary()

        self._tabs = tabs.Tabs(self)

        self._status = "idle"
        self._remote_status = "disconnected"

        self._pending_model = None
        self._current_model = None
        self._current_tab = None

        parent.aboutToQuit.connect(self.stop)

        self._needRestart = False
        self._gitInfo = None
        self._gitCommit = None
        self._triedGitInit = False
        self._updating = False
        
        self.getVersionInfo()

        self._backend = None

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
        cfg = DEFAULT_PRESETS[DEFAULT_PRESET].copy()
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
    
    @pyqtSlot(str)
    def setStopCondition(self, stop):
        self._stop_parameters.set("stop_condition", stop)
    
    @pyqtProperty(misc.VariantMap, notify=updated)
    def backendParameters(self):
        return self._backend_parameters  
    
    @pyqtSlot(str)
    def backendUpdated(self, key):
        if key == "mode" and self._backend_parameters.get("mode") == "Local":
            self.restartBackend()
        else:
            self.resetState()

    def resetState(self):
        self._pending_model = None
        self._current_model = None
        self._status = "idle"
        self.setModels([])
        self.workingUpdated.emit()

    @pyqtSlot()
    def ready(self):
        self.restartBackend()

    @pyqtSlot()
    def restartBackend(self):
        if self._backend:
            self._backend.response.disconnect()
            self._backend.stop()
            if not self._backend.wait(500):
                self._backend.terminate()

        self.resetState()
        self.saveConfig()

        mode = self._backend_parameters.get("mode")
        if mode == "Local":
            self._backend = backend.LocalBackend(self)
        else:
            endpoint = self._backend_parameters.get("endpoint")
            key = self._backend_parameters.get("key")
            if endpoint.startswith("ws"):
                self._backend = backend.RemoteBackend(self, endpoint, key)
            else:
                self._backend = backend.APIBackend(self, endpoint, key)
            
        self._backend.response.connect(self.onResponse)
        self._backend.start()

        self.workingUpdated.emit()

    @pyqtProperty(list, notify=historyUpdated)
    def history(self):
        order = self._history_order
        if self._history_search:
            order = self._history_results
        return [str(i) for i in order[::-1]]

    @pyqtSlot(str, result=HistoryEntry)
    def getHistory(self, id):
        id = int(id)
        if id in self._history:
            return self._history[id]
        return None
    
    @pyqtSlot(HistoryEntry)
    def addHistory(self, entry):
        i = 0
        for id in self._history:
            ii = self._history[id]._index
            if ii > i:
                i = ii
        entry._index = i + 1

        id = entry._time
        self._history[id] = entry
        self._history_order += [id]

        self.searchHistory()

    @pyqtSlot(list)
    def clearHistoryEntries(self, ids):
        for i in ids:
            ii = int(i)
            if ii in self._history_order:
                self._history_order.remove(ii)
            if ii in self._history:
                del self._history[ii]
        self.historyUpdated.emit()

    @pyqtSlot(str)
    def clearHistoryEntriesBelow(self, id):
        i = int(id)
        if i in self._history_order:
            ids = [self._history[self._history_order[e]].id for e in range(0,self._history_order.index(i))]
            self.clearHistoryEntries(ids)

    @pyqtSlot()
    def clearHistory(self):
        self._history = {}
        self._history_order = []
        self._history_search = ""
        self._history_results = []
        self.historyUpdated.emit()

    @pyqtSlot(str)
    def searchHistory(self, text=None):
        if text == None:
            text = self._history_search
        self._history_search = text
        self._history_results = []

        if text.strip() != "":
            for i in self._history_order:
                if self._history[i].contains(text):
                    self._history_results += [i]
        self.historyUpdated.emit()

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
            self.getVersionInfo()
            return
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
        return self._current_model != None or (self.isAPI and self._model_parameters.get("model_paths") != [])
    
    @pyqtProperty(bool, notify=workingUpdated)
    def isGenerating(self):
        return self._status == "generating"
    
    @pyqtProperty(bool, notify=workingUpdated)
    def canGenerate(self):
        return not (self.isGenerating or (self.isRemote and not self.isConnected) or (not self.modelIsLoaded))
    
    @pyqtProperty(bool, notify=workingUpdated)
    def isRemote(self):
        return self._backend != None and type(self._backend) != backend.LocalBackend

    @pyqtProperty(bool, notify=workingUpdated)
    def isAPI(self):
        return self._backend != None and type(self._backend) == backend.APIBackend

    @pyqtProperty(bool, notify=workingUpdated)
    def isConnected(self):
        return self._remote_status == "connected" and self.isRemote
    
    @pyqtProperty(bool, notify=workingUpdated)
    def isConnecting(self):
        return self._remote_status == "connecting" and self.isRemote
    
    @pyqtProperty(str, notify=workingUpdated)
    def currentModel(self):
        if self._current_model:
            return self._current_model["model_path"]
        if self._pending_model:
            return self._pending_model["model_path"]
        return ""
    
    def setModels(self, models, model=None):
        self._model_parameters.set("model_paths", models)
        if models:
            if model in models:
                self._model_parameters.set("model_path", model)
            else:
                self._model_parameters.set("model_path", models[0])
        else:
            self._model_parameters.set("model_path", "")

    @pyqtSlot()
    def generate(self):
        if not self.modelIsLoaded:
            self.failed.emit()
            return

        area = self._tabs.current
        self._current_tab = area._tabs[area.current]
        parameters = copy.deepcopy(self._gen_parameters._map)
        if parameters["min_p"] > 0.0 and not self.isAPI:
            parameters["top_p"] = 1.0
            parameters["top_k"] = 0

        parameters["prompt"] = self._current_tab.context()
        parameters["max_tokens"] = self._stop_parameters.get("max_tokens")
        parameters["stop_condition"] = self._stop_parameters.get("stop_condition")

        if self.isAPI:
            del parameters["min_p"]
            parameters["model"] = self._model_parameters.get("model_path")
        
        if self.isRemote:
            n_chrs = max(128, self._model_parameters.get("n_ctx") * 3)
            if len(parameters["prompt"]) > n_chrs:
                parameters["prompt"] = parameters["prompt"][len(parameters["prompt"])-n_chrs:]

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
        if not self.modelIsLoaded:
            self.failed.emit()
            return
        self.revert()
        self.generate()

    @pyqtSlot()
    def revert(self):
        if not self._tabs.currentTab().revert():
            self.fail()

    @pyqtSlot()
    def abort(self):
        self._backend.makeRequest({"type":"abort"})

    @pyqtProperty(Tab, notify=workingUpdated)
    def workingTab(self):
        if self._current_tab:
            return self._current_tab
        return None
    
    @pyqtProperty(TabArea, notify=workingUpdated)
    def workingArea(self):
        if self._current_tab:
            return self._current_tab.parent()
        return None

    @pyqtSlot(object)
    def onResponse(self, response):
        typ = response["type"]

        if typ == "status":
            status = response["data"]["message"]

            if status in {"connected", "connecting", "disconnected"}:
                self._remote_status = status
                if status == "disconnected":
                    self.resetState()
            else:
                self._status = status
            self.workingUpdated.emit()

        if typ == "options":
            model = self._model_parameters.get("model_path")
            models = response["data"]["models"]
            self.setModels(models, model)

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
            if self._current_entry and output.strip():
                self._current_entry._output = output
                self._current_entry._time = int(time.time()*1000)
                self.addHistory(self._current_entry)
            
            self._current_entry = None

            if self._current_tab:
                self._current_tab.endStream()
                self._current_tab = None

            self.workingUpdated.emit()

        if typ == "error":
            status = self._status
            if status == "idle" and self._remote_status == "connecting":
                status = self._remote_status

            self.errored.emit(response["data"]["message"].capitalize(), status.capitalize())
            self._status = "idle"
            self._pending_model = None

            if self._current_tab:
                self._current_tab.endStream()
                self._current_tab = None

            self.workingUpdated.emit()
        
        if typ == "aborted":
            self._status = "idle"

            if self._current_tab:
                self._current_tab.endStream()
                self._current_tab = None

            self.workingUpdated.emit()

        if typ == "stream":
            stream = ''.join([c for c in response["data"]["next"] if ord(c) < 0x10000])
            if self._current_tab:
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
            "recent": self._recent,
            "settings": {
                "spell_overlay": self._spell_overlay,
                "stream_overlay": self._stream_overlay,
                "position_overlay": self._position_overlay,
                "light_mode": self._light_mode
            },
            "remote": self._backend_parameters._map["mode"] == "Remote",
            "endpoint": self._backend_parameters._map["endpoint"],
            "key": self._backend_parameters._map["key"],
            "mode": self._mode
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
        recent_valid = []
        for f in self._recent:
            if os.path.exists(f):
                recent_valid += [f]
        self._recent = recent_valid

        self._model_config = config.get("models", {})
        self._gen_config = config.get("presets", {})

        for k in DEFAULT_PRESETS:
            if not k in self._gen_config:
                self._gen_config[k] = DEFAULT_PRESETS[k]

        presets = list(self._gen_config.keys())
        self._gen_presets.set("presets", presets)
        if presets and not self._gen_presets.get("preset") in presets:
            self._gen_presets.set("preset", presets[0])

        self._backend_parameters.set("mode", "Remote" if config.get("remote", False) else "Local")
        self._backend_parameters.set("endpoint", config.get("endpoint", ""))
        self._backend_parameters.set("key", config.get("key", ""))

        settings = config.get("settings", {})
        self._spell_overlay = settings.get("spell_overlay", self._spell_overlay)
        self._stream_overlay = settings.get("stream_overlay", self._stream_overlay)
        self._position_overlay = settings.get("position_overlay", self._position_overlay)
        self._light_mode = settings.get("light_mode", self._light_mode)

        self.settingsUpdated.emit()

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
            "vocabulary": self._dictionary.added
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

        if "vocabulary" in data:
            self._dictionary.populator.add(data["vocabulary"])

        self.tabsFromJSON(data["areas"])
        self.clearHistory()

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

    def doSave(self, file, indicate=True):
        if indicate:
            self.saving.emit()

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

    @pyqtSlot()
    def autosave(self):
        if self._file:
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
        self.clear.emit()
        self.updated.emit()

    @pyqtSlot()
    def resetFocus(self):
        self._tabs.currentTab().forceFocus()

    @pyqtSlot()
    def setMarker(self):
        self._tabs.currentTab().setMarker()

    @pyqtProperty(bool, notify=settingsUpdated)
    def lightMode(self):
        return self._light_mode
    
    @lightMode.setter
    def lightMode(self, value):
        if value != self._light_mode:
            self._light_mode = value
            self.settingsUpdated.emit()
            self.saveConfig()
    
    @pyqtProperty(bool, notify=settingsUpdated)
    def spellOverlay(self):
        return self._spell_overlay
    
    @spellOverlay.setter
    def spellOverlay(self, value):
        if value != self._spell_overlay:
            self._spell_overlay = value
            self.settingsUpdated.emit()
            self.saveConfig()

    @pyqtProperty(bool, notify=settingsUpdated)
    def streamOverlay(self):
        return self._stream_overlay
    
    @streamOverlay.setter
    def streamOverlay(self, value):
        if value != self._stream_overlay:
            self._stream_overlay = value
            self.settingsUpdated.emit()
            self.saveConfig()

    @pyqtProperty(bool, notify=settingsUpdated)
    def positionOverlay(self):
        return self._position_overlay
    
    @positionOverlay.setter
    def positionOverlay(self, value):
        if value != self._position_overlay:
            self._position_overlay = value
            self.settingsUpdated.emit()
            self.saveConfig()

    @pyqtSlot()
    def fail(self):
        self.failed.emit()

    @pyqtSlot(str, result=str)
    def getName(self, name):
        return name.rsplit('\\',1)[-1].rsplit('/',1)[-1]

def registerTypes():
    qmlRegisterUncreatableType(HistoryEntry, "gui", 1, 0, "HistoryEntry", "Not a QML type")