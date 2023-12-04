import warnings
warnings.filterwarnings("ignore", category=UserWarning) 
warnings.filterwarnings("ignore", category=DeprecationWarning) 

import sys
import signal
import traceback
import datetime
import subprocess
import os
import glob
import shutil
import importlib
import pkg_resources
import json
import hashlib
import re

import platform
IS_WIN = platform.system() == 'Windows'

LLAMA_CPP_VERSION = "0.2.20"
LLAMA_CPP_WHEELS = {
    "Windows": {
        "CPU": "https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/cpu/llama_cpp_python-0.2.20+cpuavx2-cp310-cp310-win_amd64.whl",
        "NVIDIA": "https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/textgen-webui/llama_cpp_python_cuda-0.2.20+cu121-cp310-cp310-win_amd64.whl",
        "AMD": None #"https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/rocm/llama_cpp_python_cuda-0.2.20+rocm5.5.1-cp310-cp310-win_amd64.whl"
    }, 
    "Linux": {
        "CPU": "https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/cpu/llama_cpp_python-0.2.20+cpuavx2-cp310-cp310-manylinux_2_31_x86_64.whl",
        "NVIDIA": "https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/textgen-webui/llama_cpp_python_cuda-0.2.20+cu121-cp310-cp310-manylinux_2_31_x86_64.whl",
        "AMD": "https://github.com/jllllll/llama-cpp-python-cuBLAS-wheels/releases/download/rocm/llama_cpp_python_cuda-0.2.20+rocm5.6.1-cp310-cp310-manylinux_2_31_x86_64.whl"
    }
}

NVIDIA_CUDA_WHEELS = [
    "nvidia-pyindex",
    "nvidia-cuda-runtime-cu12",
    "nvidia-cublas-cu12"
]

DICTIONARY_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictionary")
DICTIONARY = {
    "en_US.dic": "https://raw.githubusercontent.com/arenasys/binaries/main/en_US.dic",
    "en_US.aff": "https://raw.githubusercontent.com/arenasys/binaries/main/en_US.aff",
}

WIN_WHEELS = {
    "cyhunspell==2.0.3": "https://github.com/arenasys/binaries/releases/download/v2/cyhunspell-2.0.3-cp310-cp310-win_amd64.whl",
    "cdifflib==1.2.6": "https://github.com/arenasys/binaries/releases/download/v2/cdifflib-1.2.6-cp310-cp310-win_amd64.whl"
}

LINUX_WHEELS = {
    "cyhunspell==2.0.3": "https://github.com/arenasys/binaries/releases/download/v2/cdifflib-1.2.6-cp310-cp310-linux_x86_64.whl",
    "cdifflib==1.2.6": "https://github.com/arenasys/binaries/releases/download/v2/cyhunspell-2.0.3-cp310-cp310-linux_x86_64.whl"
}

from PyQt5.QtCore import pyqtSignal, pyqtSlot, pyqtProperty, QObject, QUrl, QCoreApplication, Qt, QElapsedTimer, QThread
from PyQt5.QtQml import QQmlApplicationEngine, qmlRegisterSingletonType, qmlRegisterType
from PyQt5.QtWidgets import QApplication
from PyQt5.QtGui import QIcon

NAME = "Lineworks"
LAUNCHER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Lineworks.exe")
APPID = "arenasys.lineworks." + hashlib.md5(LAUNCHER.encode("utf-8")).hexdigest()
ERRORED = False

class Application(QApplication):
    t = QElapsedTimer()

    def event(self, e):
        return QApplication.event(self, e)
        
def buildQMLRc():
    qml_path = os.path.join("source", "qml")
    qml_rc = os.path.join(qml_path, "qml.qrc")
    if os.path.exists(qml_rc):
        os.remove(qml_rc)

    items = []

    tabs = glob.glob(os.path.join("source", "tabs", "*"))
    for tab in tabs:
        for src in glob.glob(os.path.join(tab, "*.*")):
            if src.split(".")[-1] in {"qml","svg"}:
                dst = os.path.join(qml_path, os.path.relpath(src, "source"))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy(src, dst)
                items += [dst]

    items += glob.glob(os.path.join(qml_path, "*.qml"))
    items += glob.glob(os.path.join(qml_path, "components", "*.qml"))
    items += glob.glob(os.path.join(qml_path, "style", "*.qml"))
    items += glob.glob(os.path.join(qml_path, "fonts", "*.ttf"))
    items += glob.glob(os.path.join(qml_path, "icons", "*.*"))

    items = ''.join([f"\t\t<file>{os.path.relpath(f, qml_path )}</file>\n" for f in items])

    contents = f"""<RCC>\n\t<qresource prefix="/">\n{items}\t</qresource>\n</RCC>"""

    with open(qml_rc, "w") as f:
        f.write(contents)

def buildQMLPy():
    qml_path = os.path.join("source", "qml")
    qml_py = os.path.join(qml_path, "qml_rc.py")
    qml_rc = os.path.join(qml_path, "qml.qrc")

    if os.path.exists(qml_py):
        os.remove(qml_py)
    
    startupinfo = None
    if IS_WIN:
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

    status = subprocess.run(["pyrcc5", "-o", qml_py, qml_rc], capture_output=True, startupinfo=startupinfo)
    if status.returncode != 0:
        raise Exception(status.stderr)

    os.remove(qml_rc)

class Builder(QThread):
    def __init__(self, app, engine):
        super().__init__()
        self.app = app
        self.engine = engine
    
    def run(self):
        buildQMLRc()
        buildQMLPy()

def check(dependancies, enforce_version=True):
    importlib.reload(pkg_resources)
    needed = []
    for d in dependancies:
        try:
            pkg_resources.require(d)
        except pkg_resources.DistributionNotFound:
            needed += [d]
        except pkg_resources.VersionConflict as e:
            if enforce_version:
                #print("CONFLICT", d, e)
                needed += [d]
        except Exception:
            pass
    return needed

def download(url, path, headers={}):
    import requests

    if os.path.isdir(path):
        filename = None
        folder = path
    else:
        filename = path
        folder = os.path.dirname(path)
        os.makedirs(folder, exist_ok=True)

    resp = requests.get(url, stream=True, timeout=10, headers=headers, allow_redirects=True)
    total = int(resp.headers.get('content-length', 0))

    content_length = resp.headers.get("content-length", 0)
    if not content_length:
        raise RuntimeError(f"response is empty")

    content_type = resp.headers.get("content-type", "unknown")
    content_disposition = resp.headers.get("content-disposition", "")

    if not content_type in {"application/zip", "binary/octet-stream", "application/octet-stream", "multipart/form-data", "text/plain; charset=utf-8"}:
        if not (content_type == "unknown" and "attachment" in content_disposition):
            raise RuntimeError(f"{content_type} content type is not supported")

    if not filename:
        if content_disposition:
            filename = re.findall("filename=\"(.+)\";?", content_disposition)[0]
        else:
            filename = url.rsplit("/",-1)[-1]
        filename = os.path.join(folder, filename)

    with open(filename+".tmp", 'wb') as file:
        for data in resp.iter_content(chunk_size=1024):
            file.write(data)

    os.rename(filename+".tmp", filename)

class Installer(QThread):
    output = pyqtSignal(str)
    installing = pyqtSignal(str)
    installed = pyqtSignal(str)
    def __init__(self, parent, packages):
        super().__init__(parent)
        self.packages = packages
        self.proc = None
        self.stopping = False

    def run(self):
        for p in self.packages:
            pkg = "llama-cpp-python==" + LLAMA_CPP_VERSION if "llama-cpp-python" in p else p

            if p == "hunspell-dictionaries":
                self.installing.emit(pkg)
                
                for file, url in DICTIONARY.items():
                    self.output.emit(f"DOWNLOADING {file} {url}")
                    download(url, os.path.join(DICTIONARY_PATH, file))

                self.installed.emit(pkg)
                continue

            if IS_WIN and p in WIN_WHEELS:
                p = WIN_WHEELS[p]
                
            if not IS_WIN and p in LINUX_WHEELS:
                p = LINUX_WHEELS[p]

            self.installing.emit(pkg)
            args = ["pip", "install", "-U", p]
            args = [sys.executable, "-m"] + args

            startupinfo = None
            if IS_WIN:
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

            self.proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=os.environ, startupinfo=startupinfo)

            output = ""
            while self.proc.poll() == None:
                while line := self.proc.stdout.readline():
                    if line:
                        line = line.strip()
                        output += line + "\n"
                        self.output.emit(line)
                    if self.stopping:
                        return
            if self.stopping:
                return
            if self.proc.returncode:
                raise RuntimeError("Failed to install: ", pkg, "\n", output)
            
            self.installed.emit(pkg)
        self.proc = None

    @pyqtSlot()
    def stop(self):
        self.stopping = True
        if self.proc:
            self.proc.kill()

class Coordinator(QObject):
    ready = pyqtSignal()
    show = pyqtSignal()
    proceed = pyqtSignal()
    cancel = pyqtSignal()

    output = pyqtSignal(str)

    updated = pyqtSignal()
    installedUpdated = pyqtSignal()
    def __init__(self, app, engine):
        super().__init__(app)
        self.app = app
        self.engine = engine
        self.builder = Builder(app, engine)
        self.builder.finished.connect(self.loaded)
        self.installer = None

        self._needRestart = False
        self._installed = []
        self._installing = ""

        self._mode = None
        try:
            with open("config.json", "r", encoding="utf-8") as f:
                cfg = json.load(f)
                if "mode" in cfg:
                    self._mode = cfg["mode"]
        except Exception:
            pass
        if not self._mode in self.modes:
            self._mode = "CPU"
            self.writeMode()

        self.in_venv = "VIRTUAL_ENV" in os.environ
        self.override = False
        self.enforce = True

        with open(os.path.join("source", "requirements.txt")) as file:
            self.required = [line.rstrip() for line in file]

        self.findNeeded()

        qmlRegisterSingletonType(Coordinator, "gui", 1, 0, "COORDINATOR", lambda qml, js: self)

    @pyqtProperty(int, notify=updated)
    def mode(self):
        return self.modes.index(self._mode)

    @mode.setter
    def mode(self, mode):
        self._mode = self.modes[mode]
        self.writeMode()
        self.updated.emit()

    @pyqtProperty(list, constant=True)
    def modes(self):
        if IS_WIN:
            return ["CPU", "NVIDIA"]
        else:
            return ["CPU", "NVIDIA", "AMD"]
    
    def writeMode(self):
        cfg = {}
        try:
            with open("config.json", "r", encoding="utf-8") as f:
                cfg = json.load(f)
        except Exception as e:
            pass
        cfg["mode"] = self._mode
        with open("config.json", "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=4)

    @pyqtProperty(list, notify=updated)
    def packages(self):
        return self.getNeeded()
    
    @pyqtProperty(list, notify=installedUpdated)
    def installed(self):
        return self._installed
    
    @pyqtProperty(str, notify=installedUpdated)
    def installing(self):
        return self._installing
    
    @pyqtProperty(bool, notify=installedUpdated)
    def disable(self):
        return self.installer != None
    
    @pyqtProperty(bool, notify=updated)
    def needRestart(self):
        return self._needRestart
    
    def findNeeded(self):
        self.llama_version = None
        try:
            self.llama_version = pkg_resources.get_distribution("llama_cpp_python_cuda")
        except:
            pass
        if not self.llama_version:
            try:
                self.llama_version = pkg_resources.get_distribution("llama_cpp_python")
            except:
                pass
            
        required = self.required
        if self._mode == "NVIDIA":
            required = required + NVIDIA_CUDA_WHEELS
            
        return check(required, self.enforce)

    def getNeeded(self):
        needed = self.findNeeded()

        for file in DICTIONARY.keys():
            if not os.path.exists(os.path.join(DICTIONARY_PATH, file)):
                needed = needed + ["hunspell-dictionaries"]
                break
        
        if not self.llama_version or not LLAMA_CPP_VERSION in str(self.llama_version):
            needed = needed + ["llama-cpp-python=="+LLAMA_CPP_VERSION]

        if needed:
            needed = ["pip", "wheel"] + needed

        return needed

    @pyqtSlot()
    def load(self):
        self.app.setWindowIcon(QIcon("source/qml/icons/placeholder-flat.svg"))
        self.builder.start()

    @pyqtSlot()
    def loaded(self):
        ready()
        self.ready.emit()

        if self.in_venv and self.packages:
            self.show.emit()
        else:
            self.done()
        
    @pyqtSlot()
    def done(self):
        start(self.engine, self.app, self._mode)
        self.proceed.emit()

    @pyqtSlot()
    def install(self):
        if self.installer:
            self.cancel.emit()
            return
        packages = self.packages
        if not packages:
            self.done()
            return
        
        llama_cpp_pkg = "llama-cpp-python==" + LLAMA_CPP_VERSION
        if llama_cpp_pkg in packages:
            platform = "Windows" if IS_WIN else "Linux"
            wheel = LLAMA_CPP_WHEELS[platform][self._mode]
            packages[packages.index(llama_cpp_pkg)] = wheel

        self.installer = Installer(self, packages)
        self.installer.installed.connect(self.onInstalled)
        self.installer.installing.connect(self.onInstalling)
        self.installer.output.connect(self.onOutput)
        self.installer.finished.connect(self.doneInstalling)
        self.app.aboutToQuit.connect(self.installer.stop)
        self.cancel.connect(self.installer.stop)
        self.installer.start()
        self.installedUpdated.emit()

    @pyqtSlot(str)
    def onInstalled(self, package):
        self._installed += [package]
        self.installedUpdated.emit()
    
    @pyqtSlot(str)
    def onInstalling(self, package):
        self._installing = package
        self.installedUpdated.emit()
    
    @pyqtSlot(str)
    def onOutput(self, out):
        self.output.emit(out)
    
    @pyqtSlot()
    def doneInstalling(self):
        self._installing = ""
        self.installer = None
        self.installedUpdated.emit()
        self.findNeeded()
        if not self.packages:
            self.done()
            return
        self.installer = None
        self.installedUpdated.emit()
        if all([p in self._installed for p in self.packages]):
            self._needRestart = True
            self.updated.emit()

    @pyqtProperty(float, constant=True)
    def scale(self):
        if IS_WIN:
            factor = round(self.parent().desktop().logicalDpiX()*(100/96))
            if factor == 125:
                return 0.82
        return 1.0
    
def launch():
    import misc
    if IS_WIN:
        misc.setAppID(APPID)
    
    QCoreApplication.setAttribute(Qt.AA_UseDesktopOpenGL, True)
    QCoreApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    QCoreApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)

    scaling = False
    if scaling:
        QApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)

    app = Application([NAME])
    signal.signal(signal.SIGINT, lambda sig, frame: app.quit())
    app.startTimer(100)

    app.setOrganizationName(NAME)
    app.setOrganizationDomain(NAME)
    
    engine = QQmlApplicationEngine()
    engine.quit.connect(app.quit)
    
    coordinator = Coordinator(app, engine)

    engine.load(QUrl('file:source/qml/Splash.qml'))

    if IS_WIN:
        hwnd = engine.rootObjects()[0].winId()
        misc.setWindowProperties(hwnd, APPID, NAME, LAUNCHER)

    os._exit(app.exec())

def ready():
    import qml.qml_rc
    import misc
    qmlRegisterSingletonType(QUrl("qrc:/Common.qml"), "gui", 1, 0, "COMMON")
    misc.registerTypes()

def start(engine, app, mode):
    import gui
    import sql
    import tabs
    import spellcheck

    sql.registerTypes()
    spellcheck.registerTypes()
    tabs.registerTypes()
    gui.registerTypes()

    backend = gui.GUI(parent=app, mode=mode)

    if mode == "NVIDIA":
        from nvidia.cuda_runtime import bin as cudart_bin
        from nvidia.cublas import bin as cublas_bin
        import ctypes
        for file_path in [cudart_bin.__file__, cublas_bin.__file__]:
            bin_path = os.path.dirname(os.path.abspath(file_path))
            sys.path.append(bin_path)
            os.add_dll_directory(bin_path)
        ctypes.RTLD_GLOBAL = None # fix for llama.cpp disabling dll import directories

    qmlRegisterSingletonType(gui.GUI, "gui", 1, 0, "GUI", lambda qml, js: backend)

def exceptHook(exc_type, exc_value, exc_tb):
    global ERRORED
    tb = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    with open("crash.log", "a", encoding='utf-8') as f:
        f.write(f"GUI {datetime.datetime.now()}\n{tb}\n")
    print(tb)
    print("TRACEBACK SAVED: crash.log")

    if IS_WIN and os.path.exists(LAUNCHER) and not ERRORED:
        ERRORED = True
        message = f"{tb}\nError saved to crash.log"
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        subprocess.run([LAUNCHER, "-e", message], startupinfo=startupinfo)

    QApplication.exit(-1)

def main():
    if not sys.stdout:
        sys.stdout = open(os.devnull, "w")
        sys.stderr = open(os.devnull, "w")

    sys.excepthook = exceptHook
    launch()

if __name__ == "__main__":
    main()