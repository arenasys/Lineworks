import re
import os
import ctypes
import time

try:
    from ctypes import wintypes

    ctypes.windll.ole32.CoInitialize.restype = ctypes.HRESULT
    ctypes.windll.ole32.CoInitialize.argtypes = [ctypes.c_void_p]
    ctypes.windll.ole32.CoUninitialize.restype = None
    ctypes.windll.ole32.CoUninitialize.argtypes = None
    ctypes.windll.shell32.ILCreateFromPathW.restype = ctypes.c_void_p
    ctypes.windll.shell32.ILCreateFromPathW.argtypes = [ctypes.c_char_p]
    ctypes.windll.shell32.SHOpenFolderAndSelectItems.restype = ctypes.HRESULT
    ctypes.windll.shell32.SHOpenFolderAndSelectItems.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p, ctypes.c_ulong]
    ctypes.windll.shell32.ILFree.restype = None
    ctypes.windll.shell32.ILFree.argtypes = [ctypes.c_void_p]

    GUID = ctypes.c_ubyte * 16

    class PROPERTYKEY(ctypes.Structure):
        _fields_ = [("fmtid", GUID),
                    ("pid", wintypes.DWORD)]

    class PROPVARIANT(ctypes.Structure):
        _fields_ = [("vt", wintypes.USHORT),
                    ("wReserved1", wintypes.USHORT),
                    ("wReserved2", wintypes.USHORT),
                    ("wReserved3", wintypes.USHORT),
                    ("pszVal", wintypes.LPWSTR)]

    class IPropertyStoreVtbl(ctypes.Structure):
        _fields_ = [
            ('QueryInterface', ctypes.CFUNCTYPE(ctypes.HRESULT, ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))),
            ('AddRef', ctypes.CFUNCTYPE(ctypes.c_ulong, ctypes.c_void_p)),
            ('Release', ctypes.CFUNCTYPE(ctypes.c_ulong, ctypes.c_void_p)),
            ('GetCount', ctypes.CFUNCTYPE(ctypes.HRESULT, ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong))),
            ('GetAt', ctypes.CFUNCTYPE(ctypes.HRESULT, ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(PROPERTYKEY))),
            ('GetValue', ctypes.CFUNCTYPE(ctypes.HRESULT, ctypes.c_void_p, ctypes.POINTER(PROPERTYKEY), ctypes.POINTER(PROPVARIANT))),
            ('SetValue', ctypes.CFUNCTYPE(ctypes.HRESULT, ctypes.c_void_p, ctypes.POINTER(PROPERTYKEY), ctypes.POINTER(PROPVARIANT))),
            ('Commit', ctypes.CFUNCTYPE(ctypes.HRESULT, ctypes.c_void_p))
        ]

    class IPropertyStore(ctypes.Structure):
        _fields_ = [('lpVtbl', ctypes.POINTER(IPropertyStoreVtbl))]

    ctypes.windll.shell32.SHGetPropertyStoreForWindow.restype = ctypes.HRESULT
    ctypes.windll.shell32.SHGetPropertyStoreForWindow.argtypes = [wintypes.HWND, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.POINTER(IPropertyStore))]

    IID_IPropertyStore = (GUID)(*bytearray.fromhex("eb8e6d88f28c46448d02cdba1dbdcf99"))
    PKEY_AppUserModel = (GUID)(*bytearray.fromhex("55284c9f799f394ba8d0e1d42de1d5f3"))
except:
    pass

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, QObject, Qt, QEvent, QMimeData, QVariant
from PyQt5.QtQuick import QQuickItem
from PyQt5.QtQml import qmlRegisterType

class FocusReleaser(QQuickItem):
    releaseFocus = pyqtSignal()
    dropped = pyqtSignal()
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptedMouseButtons(Qt.AllButtons)
        self.setFlag(QQuickItem.ItemAcceptsInputMethod, True)
        self.setFiltersChildMouseEvents(True)
        self.last = time.time()
    
    def onPress(self, source):
        if not source.hasActiveFocus():
            self.releaseFocus.emit()

    def childMouseEventFilter(self, child, event):
        if event.type() == QEvent.MouseButtonPress:
            self.onPress(child)
            
            now = time.time()
            delta = (now - self.last)*1000
            self.last = now
            if delta < 10:
                return True
            
        return False

    def mousePressEvent(self, event):
        self.last = time.time()
        self.onPress(self)
        event.setAccepted(False)

class MimeData(QObject):
    def __init__(self, mimeData, parent=None):
        super().__init__(parent)
        self._mimeData = mimeData

    @pyqtProperty(QMimeData)
    def mimeData(self):
        return self._mimeData

class DropArea(QQuickItem):
    dropped = pyqtSignal(MimeData, arguments=["mimeData"])
    updated = pyqtSignal()
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFlag(QQuickItem.ItemAcceptsDrops, True)
        self._containsDrag = False
        self._filters = []
    
    @pyqtProperty(bool, notify=updated)
    def containsDrag(self):
        return self._containsDrag
    
    @pyqtProperty(list, notify=updated)
    def filters(self):
        return self._filters
    
    def accepted(self, mimeData):
        if not self._filters:
            return True
        formats = mimeData.formats()
        if any([f in formats for f in self._filters]):
            return True
        if mimeData.hasUrls():
            for url in mimeData.urls():
                if url.scheme() in self._filters:
                    return True
                if url.isLocalFile():
                    ext = "*." + url.toLocalFile().rsplit('.',1)[-1].lower()
                    if ext in self._filters:
                        return True
        return False

    @filters.setter
    def filters(self, filters):
        self._filters = filters
        self.updated.emit()

    def dragEnterEvent(self, enter):
        if self.accepted(enter.mimeData()):
            enter.accept()
            self._containsDrag = True
            self.updated.emit()

    def dragLeaveEvent(self, leave):
        leave.accept()
        self._containsDrag = False
        self.updated.emit()

    def dragMoveEvent(self, move):
        if self.accepted(move.mimeData()):
            move.accept()

    def dropEvent(self, drop):
        if self.accepted(drop.mimeData()):
            drop.accept()
            self.dropped.emit(MimeData(drop.mimeData()))
            self._containsDrag = False
            self.updated.emit()

def showFilesInExplorer(folder, files):
    ctypes.windll.ole32.CoInitialize(None)

    folder_pidl = ctypes.windll.shell32.ILCreateFromPathW(folder.encode('utf-16le') + b'\0')
    files_pidl = [ctypes.windll.shell32.ILCreateFromPathW(f.encode('utf-16le') + b'\0') for f in files]
    files_pidl_arr = (ctypes.c_void_p * len(files_pidl))(*files_pidl)

    ctypes.windll.shell32.SHOpenFolderAndSelectItems(folder_pidl, len(files_pidl_arr), files_pidl_arr, 0)

    for pidl in files_pidl[::-1]:
        ctypes.windll.shell32.ILFree(pidl)
    ctypes.windll.shell32.ILFree(folder_pidl)

    ctypes.windll.ole32.CoUninitialize()

def setWindowProperties(hwnd, app_id, display_name, relaunch_path):
    ctypes.windll.ole32.CoInitialize(None)

    prop_store = ctypes.POINTER(IPropertyStore)()
    result = ctypes.windll.shell32.SHGetPropertyStoreForWindow(int(hwnd), IID_IPropertyStore, ctypes.pointer(prop_store))
    if result != 0:
        return False
    functions = prop_store.contents.lpVtbl.contents
    
    success = False
    # PID of PKEY_AppUserModel_ID is 5, etc
    values = (5, app_id), (4, display_name), (2, relaunch_path)
    for pid, value in values:
        prop_key = PROPERTYKEY()
        prop_key.fmtid = PKEY_AppUserModel
        prop_key.pid = pid

        prop_variant = PROPVARIANT()
        prop_variant.vt = 31 # VT_LPWSTR
        prop_variant.pszVal = value

        result = functions.SetValue(prop_store, prop_key, prop_variant)
        if result != 0:
            break
    else:
        success = True
    
    if success:
        functions.Commit(prop_store)

    functions.Release(prop_store)
    ctypes.windll.ole32.CoUninitialize()
    return success

def setAppID(app_id):
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(app_id)

NATSORT_KEY = lambda s: [int(t) if t.isdigit() else t.lower() for t in re.split('(\d+)', s)]

def sortFiles(files):
    return sorted(files, key=lambda f: NATSORT_KEY(f.rsplit(os.path.sep,1)[-1]))

def formatFloat(f):
    return f"{f:.4f}".rstrip('0').rstrip('.')

class VariantMap(QObject):
    updating = pyqtSignal(str, 'QVariant', 'QVariant')
    updated = pyqtSignal(str)
    def __init__(self, parent=None, map = {}, strict=False):
        super().__init__(parent)
        self._map = map
        self._strict = strict

    @pyqtSlot(str, result='QVariant')
    def get(self, key, default=QVariant()):
        if key in self._map:
            return self._map[key]
        return default
    
    @pyqtSlot(str, 'QVariant')
    def set(self, key, value):
        if key in self._map and self._map[key] == value:
            return

        if key in self._map:
            if self._strict:
                try:
                    value = type(self._map[key])(value)
                except Exception:
                    pass
            self.updating.emit(key, self._map[key], value)
        else:
            self.updating.emit(key, QVariant(), value)

        self._map[key] = value
        self.updated.emit(key)

def registerTypes():
    qmlRegisterType(FocusReleaser, "gui", 1, 0, "FocusReleaser")
    qmlRegisterType(DropArea, "gui", 1, 0, "AdvancedDropArea")
    qmlRegisterType(MimeData, "gui", 1, 0, "MimeData")
    qmlRegisterType(VariantMap, "gui", 1, 0, "VariantMap")