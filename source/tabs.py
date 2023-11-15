import os

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, QObject, QUrl, QThread, QMimeData, QByteArray, QSize
from PyQt5.QtGui import QDrag, QColor, QImage, QSyntaxHighlighter, QColor, QBrush, QTextCharFormat
from PyQt5.QtQml import qmlRegisterUncreatableType
from PyQt5.QtQuick import QQuickTextDocument, QQuickImageProvider

MIME_POSITION = "application/x-lineworks-position"
INVERSE_POSITION = {"T":"B","B":"T","L":"R","R":"L"}
MARK = 0x00AD

def clean_text(text):
    return ''.join([c for c in text if c.isprintable() or c in {'\n', '\r'}])

class TabHighlighter(QSyntaxHighlighter):
    def __init__(self, tab):
        super().__init__(tab)
        self.tab = tab

    def highlightBlock(self, text):
        mark = chr(MARK)

        if mark in text:
            idx = text.index(mark)
            self.setFormat(idx, 1, QColor(0,0,0,0))

        return

class Tab(QObject):
    nameUpdated = pyqtSignal()
    contentUpdated = pyqtSignal()
    markerUpdated = pyqtSignal()
    insert = pyqtSignal(int, str)
    def __init__(self, parent, name):
        super().__init__(parent)
        self.gui = parent.gui
        self._name = name
        self._content = "Hello World!"
        self._highlighter = TabHighlighter(self)
        self._marker = 6

        self._last = ""

    @pyqtProperty(str, notify=nameUpdated)
    def name(self):
        return self._name
    
    @name.setter
    def name(self, name):
        if name != self._name:
            self._name = name
            self.nameUpdated.emit()
    
    @pyqtProperty(str, notify=contentUpdated)
    def initial(self):
        return self.context() + chr(MARK) + self.trailing()
    
    @pyqtProperty(str, notify=contentUpdated)
    def content(self):
        return self._content
    
    @content.setter
    def content(self, text):
        mark = chr(MARK)
        if mark in text:
            self.marker = text.index(mark)
        else:
            marker = min(self.marker, len(text))
            text = text[:marker] + chr(MARK) + text[marker:]
            self.marker = marker
        
        if text != self._content:
            self._content = text
            self.contentUpdated.emit()

    @pyqtProperty(int, notify=markerUpdated)
    def marker(self):
        return self._marker
    
    @marker.setter
    def marker(self, marker):
        if marker != self._marker:
            self._marker = marker
            self.markerUpdated.emit()
    
    @pyqtSlot(int)
    def moveMarker(self, marker):
        if marker != self._marker:
            if self._marker < marker:
                marker -= 1

            text = self._content
            text = text.replace(chr(MARK), '')
            text = text[:marker] + chr(MARK) + text[marker:]
            self.content = text

    @pyqtSlot(str, result=str)
    def clean(self, text):
        mark = chr(MARK)
        return text.replace(mark, '')

    @pyqtSlot(QQuickTextDocument)
    def setHighlighting(self, doc):
        self._highlighter.setDocument(doc.textDocument())

    def revert(self):
        if not self._last:
            return

        marker = None
        for i in range(1, len(self._last)+1):
            a = self._content[self._marker-i]
            b = self._last[-i]
            if a != b:
                break
            marker = self._marker-i

        self._last = ""
        if marker:
            text = self._content[:marker] + chr(MARK) + self._content[self._marker+1:]
            self.content = text
    
    def startStream(self):
        self._last = ""
    
    @pyqtSlot(str)
    def stream(self, text):
        text = clean_text(text)
        self._last += text
        self.insert.emit(self._marker, text)

    @pyqtSlot(result=str)
    def context(self):
        if self._marker == -1:
            context = self._content
        else:
            context = self._content[:self._marker]

        context = clean_text(context)
        return context
    
    @pyqtSlot(result=str)
    def trailing(self):
        if self._marker == -1:
            context = ""
        else:
            context = self._content[self._marker:]

        context = clean_text(context)
        return context
    
    def toJSON(self):
        data = {
            "name": self._name,
            "content": clean_text(self._content),
            "marker": self._marker
        }
        return data

class TabArea(QObject):
    tabsUpdated = pyqtSignal()
    positionUpdated = pyqtSignal()
    currentUpdated = pyqtSignal()
    def __init__(self, parent, position):
        super().__init__(parent)
        self.gui = parent.gui
        self._tabs = []
        self._current = 0
        self._position = position
    
    def addTab(self, tab):
        self._tabs += [tab]
        self.tabsUpdated.emit()

    def insertTab(self, tab, index):
        if index == -1:
            self._tabs += [tab]
        else:
            self._tabs.insert(index, tab)
        self.tabsUpdated.emit()

    def removeTab(self, tab):
        self._tabs.remove(tab)
        self.tabsUpdated.emit()
        if self._current >= len(self._tabs):
            self._current = len(self._tabs) - 1
            self.currentUpdated.emit()

    @pyqtSlot()
    def newTab(self):
        tab = Tab(self, self.parent().getNewTabName())
        self.addTab(tab)
        
    @pyqtProperty(list, notify=tabsUpdated)
    def tabs(self):
        return self._tabs
    
    @pyqtProperty(str, notify=positionUpdated)
    def position(self):
        return self._position
    
    @pyqtProperty(int, notify=currentUpdated)
    def current(self):
        return self._current
    
    @current.setter
    def current(self, current):
        self.parent().current = self
        if current == self._current:
            return
        self._current = current
        self.currentUpdated.emit()

    def expandArea(self, position):
        for o in position:
            if o+"C:" in self._position:
                self._position = self._position.replace(o+"C:", o+":")
        self.positionUpdated.emit()

    def splitArea(self, target):
        aPosition = self._position
        bPosition = self._position

        for o in ["T", "B", "L", "R"]:
            i = INVERSE_POSITION[o]
            if not o in target:
                aPosition = aPosition.replace(o+":", o+"C:")
                bPosition = bPosition.replace(i+":", i+"C:")

        self._position = bPosition
        self.positionUpdated.emit()
        return aPosition
    
    def toJSON(self):
        data = {
            "tabs": [tab.toJSON() for tab in self._tabs],
            "position": self._position
        }
        return data
    
class Tabs(QObject):
    areasUpdated = pyqtSignal()
    dragUpdated = pyqtSignal()
    currentUpdated = pyqtSignal()

    def __init__(self, gui):
        super().__init__(gui)
        self.gui = gui
        self._draggedTab = None
        self._areas = []
        self._current = None

        self.addDefaultArea()

    def addDefaultArea(self):
        area = TabArea(self, "T:B:L:R:")
        area.addTab(Tab(area, "Scratch 1"))
        self.addArea(area)

    def addArea(self, area):
        self._areas += [area]
        self.areasUpdated.emit()
        if self._current == None:
            self._current = area
            self.currentUpdated.emit()

    def clearAreas(self):
        self._areas = []
        self._current = None

    @pyqtProperty(list, notify=areasUpdated)
    def areas(self):
        return self._areas
    
    @pyqtSlot()
    def expandAreas(self):
        occupation = {}
        for v in ["T", "B"]:
            for h in ["L", "R"]:
                occupation[(v,h)] = None
                for area in self._areas:
                    position = area._position
                    if v+":" in position and h+":" in position:
                        occupation[(v,h)] = area
                        break
        
        repeat = False
        for v,h in occupation:
            if occupation[(v,h)] == None:
                vv = INVERSE_POSITION[v]
                hh = INVERSE_POSITION[h]

                found = None
                potential = None
                for vo, ho in [(vv,h),(v,hh),(vv,h),(v,hh)]:
                    o = occupation[(vo,ho)]
                    c = len([a for _,a in occupation.items() if a == o])
                    if not o and potential:
                        found = potential
                        break
                    if c == 1:
                        found = o
                        break
                    if c == 2:
                        potential = o
                        continue
                else:
                    raise Exception("area expand failed")
                
                found.expandArea(f"{v}:{h}:")
                repeat = True

        if repeat:
            self.expandAreas()

    @pyqtSlot(Tab)
    def deleteTab(self, tab):
        if self.getTabCount() == 1:
            return

        sourceArea = [a for a in self._areas if tab in a._tabs]
        sourceArea = sourceArea[0] if sourceArea else None
        if sourceArea:
            sourceArea.removeTab(tab)

    @pyqtSlot(Tab, str)
    def saveTab(self, tab, file):
        file = os.path.abspath(QUrl(file).toLocalFile())
        text = tab.content
        with open(file, "w") as f:
            f.write(text)

    @pyqtProperty(bool, notify=dragUpdated)
    def dragging(self):
        return self._draggedTab != None
    
    @pyqtSlot(Tab)
    def dragTab(self, tab):
        self._draggedTab = tab
        self.dragUpdated.emit()
        mimeData = QMimeData()
        mimeData.setData(MIME_POSITION, QByteArray(f"POSITION".encode()))
        drag = QDrag(self)
        drag.setMimeData(mimeData)
        drag.exec()
        self._draggedTab = None
        self.dragUpdated.emit()

    @pyqtSlot(str)
    def dragHistory(self, id):
        entry = self.gui._history[int(id)]

        tab = Tab(self, self.getNewTabName())
        tab._content = entry._context + entry._output + entry._trailing
        tab._marker = len(entry._context + entry._output)

        self._draggedTab = tab
        self.dragUpdated.emit()
        mimeData = QMimeData()
        mimeData.setData(MIME_POSITION, QByteArray(f"POSITION".encode()))
        drag = QDrag(self)
        drag.setMimeData(mimeData)
        drag.exec()
        self._draggedTab = None
        self.dragUpdated.emit()

    @pyqtSlot(TabArea, str)
    def dropTab(self, area, target):
        tab = self._draggedTab
        sourceArea = [a for a in self._areas if tab in a._tabs]
        sourceArea = sourceArea[0] if sourceArea else None

        targetArea = area

        onlyTab = len(sourceArea._tabs) == 1 if sourceArea else False
        if sourceArea == targetArea and onlyTab:
            return
        if onlyTab:
            self._areas.remove(sourceArea)
            self.expandAreas()
            self.areasUpdated.emit()

        if ":" in target:
            if sourceArea:
                sourceArea.removeTab(tab)
            position = targetArea.splitArea(target)
            area = TabArea(self, position)
            area.addTab(tab)
            self._areas += [area]
            self.areasUpdated.emit()
            self.current = area
        else:
            index = int(target)
            if index != -1:
                indexTab = targetArea._tabs[index]
                if indexTab == tab:
                    return
                if sourceArea:
                    sourceArea.removeTab(tab)
                index = targetArea._tabs.index(indexTab)
            else:
                if sourceArea:
                    sourceArea.removeTab(tab)
            targetArea.insertTab(tab, index)
        
        if tab in targetArea._tabs:
            targetArea.current = targetArea._tabs.index(tab)
        
    @pyqtProperty(TabArea, notify=currentUpdated)
    def current(self):
        return self._current
    
    @current.setter
    def current(self, current):
        self._current = current
        self.currentUpdated.emit()

    def getTabCount(self):
        count = 0
        for area in self._areas:
            for tab in area._tabs:
                count += 1
        return count

    def getNewTabName(self):
        return f"Scratch {self.getTabCount()+1}"
    
    def toJSON(self):
        return [area.toJSON() for area in self._areas]

def registerTypes():
    qmlRegisterUncreatableType(Tabs, "gui", 1, 0, "Tabs", "Not a QML type")
    qmlRegisterUncreatableType(TabArea, "gui", 1, 0, "TabArea", "Not a QML type")
    qmlRegisterUncreatableType(Tab, "gui", 1, 0, "Tab", "Not a QML type")