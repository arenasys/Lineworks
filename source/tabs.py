import os

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, QObject, QUrl, QThread, QMimeData, QByteArray, QSize, QPoint
from PyQt5.QtGui import QDrag, QColor, QImage, QSyntaxHighlighter, QColor, QBrush, QTextCharFormat
from PyQt5.QtQml import qmlRegisterUncreatableType
from PyQt5.QtQuick import QQuickTextDocument, QQuickImageProvider

import spellcheck

MIME_POSITION = "application/x-lineworks-position"
MIME_POSITION_AREA = "application/x-lineworks-position-area"
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
    updated = pyqtSignal()
    nameUpdated = pyqtSignal()
    contentUpdated = pyqtSignal()
    markerUpdated = pyqtSignal()
    lastUpdated = pyqtSignal()
    insert = pyqtSignal(int, str)
    remove = pyqtSignal(int, int)
    move = pyqtSignal(int, int)
    focus = pyqtSignal()
    set = pyqtSignal()
    def __init__(self, parent, name):
        super().__init__(parent)
        self.gui = parent.gui
        self._name = name
        self._content = "Hello World!"
        self._highlighter = TabHighlighter(self)
        self._spellchecker = spellcheck.Spellchecker(self.gui._dictionary, self)
        self._marker = -1

        self._last = ""
        self._history = []

    @pyqtProperty(str, notify=nameUpdated)
    def name(self):
        return self._name
    
    @name.setter
    def name(self, name):
        if name != self._name:
            self._name = name
            self.nameUpdated.emit()
    
    @pyqtProperty(spellcheck.Spellchecker, notify=updated)
    def spellchecker(self):
        return self._spellchecker

    @pyqtProperty(str, notify=contentUpdated)
    def initial(self):
        context = self.context()
        trailing = self.trailing()
        if trailing:
            return context + chr(MARK) + trailing
        else:
            return context + trailing
    
    @pyqtProperty(str, notify=contentUpdated)
    def content(self):
        return self._content
    
    @content.setter
    def content(self, text):
        mark = chr(MARK)
        if mark in text:
            marker = text.index(mark)
        else:
            marker = -1
        
        if text != self._content:
            self._content = text
            self.contentUpdated.emit()
        
        if marker != self._marker:
            self._marker = marker
            self.markerUpdated.emit()

        self.lastUpdated.emit()

    @pyqtProperty(int, notify=markerUpdated)
    def marker(self):
        return self._marker
    
    def getMarker(self):
        return self._marker if self._marker != -1 else len(self._content)
    
    @marker.setter
    def marker(self, marker):
        if marker != self._marker:
            self._marker = marker
            self.markerUpdated.emit()
            self.lastUpdated.emit()
    
    @pyqtSlot(int)
    def moveMarker(self, marker):
        if marker != self._marker:
            if self._marker >= 0 and self._marker < marker:
                marker -= 1

            text = self._content

            old = -1
            if chr(MARK) in text:
                old = text.index(chr(MARK))
                text = text.replace(chr(MARK), '')
                
            if marker != len(text):
                self.move.emit(old, marker)
                text = text[:marker] + chr(MARK) + text[marker:]
            else:
                self.move.emit(old, -1)
            self.content = text

    @pyqtSlot(str, result=str)
    def clean(self, text):
        mark = chr(MARK)
        return text.replace(mark, '')

    @pyqtSlot(QQuickTextDocument)
    def setHighlighting(self, doc):
        self._highlighter.setDocument(doc.textDocument())

    @pyqtProperty(list, notify=lastUpdated)
    def last(self):
        if not self._last:
            return []
        
        marker = self.lastStart()
        if marker == None:
            return []
        
        text = self._content[marker:self.getMarker()+1]

        segments = []
        segment = 0
        for i in range(len(text)+1):
            if i == len(text) or text[i].isspace():
                if segment != None:
                    segments += [QPoint(marker+segment, marker+i)]
                    segment = None
                elif i != len(text) and text[i] == '\n' and (i == 0 or text[i-1] == '\n'):
                    segments += [QPoint(marker+i, marker+i)]
                continue
            if segment == None:
                segment = i

        return segments

    def lastStart(self):
        if not self._last:
            return None

        marker = None

        self_marker = self.getMarker()

        for i in range(1, len(self._last)+1):
            if self_marker - i < 0:
                break
            a = self._content[self_marker-i]
            b = self._last[-i]
            if a != b:
                break
            marker = self_marker-i
        
        return marker

    def revert(self):
        if not self._last:
            return False

        marker = self.lastStart()

        if self._history:
            self._last = self._history.pop()
        else:
            self._last = ""
        
        if marker != None:
            start = marker
            end = self.getMarker()
            self.remove.emit(start, end)

            text = self._content[:start]
            if self._marker != -1:
                text += chr(MARK) + self._content[self._marker+1:]
            self.content = text

        return True
    
    def startStream(self):
        if self._last:
            self._history += [self._last]
        self._last = ""
        self.lastUpdated.emit()

    def endStream(self):
        if not self._last and self._history:
            self._last = self._history.pop()
    
    @pyqtSlot(str)
    def stream(self, text):
        text = clean_text(text)
        self._last += text
        self.insert.emit(self.getMarker(), text)

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
    
    def forceFocus(self):
        self.focus.emit()

    def setMarker(self):
        self.set.emit()
    
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
    
    def addTab(self, tab, signal=True):
        self._tabs += [tab]
        if signal:
            self.tabsUpdated.emit()

    def insertTab(self, tab, index, signal=True):
        if index == -1:
            self._tabs += [tab]
        else:
            self._tabs.insert(index, tab)
        if signal:
            self.tabsUpdated.emit()

    def removeTab(self, tab, signal=True):
        self._tabs.remove(tab)
        if signal:   
            self.tabsUpdated.emit()
        if self._current >= len(self._tabs):
            self._current = len(self._tabs) - 1
            if signal:
                self.currentUpdated.emit()

    @pyqtSlot()
    def newTab(self):
        tab = Tab(self, self.parent().getNewTabName())
        self.addTab(tab)
        self.current = len(self._tabs)-1
        
    @pyqtProperty(list, notify=tabsUpdated)
    def tabs(self):
        return self._tabs
    
    @pyqtProperty(str, notify=positionUpdated)
    def position(self):
        return self._position
    
    @position.setter
    def position(self, position):
        self._position = position
        self.positionUpdated.emit()
    
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

    @pyqtSlot()
    def nextTab(self):
        index = min(self._current + 1, len(self._tabs) - 1)
        if index != self._current:
            self._current = index
            self.currentUpdated.emit()

    @pyqtSlot()
    def prevTab(self):
        index = max(self._current - 1, 0)
        if index != self._current:
            self._current = index
            self.currentUpdated.emit()

    @pyqtSlot(int)
    def setTab(self, index):
        index -= 1
        if index < len(self._tabs) and index != self._current:
            self._current = index
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
        self._draggedArea = None
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
            if len(sourceArea._tabs) == 1:
                self._areas.remove(sourceArea)
                self.expandAreas()
                self.areasUpdated.emit()
            else:
                sourceArea.removeTab(tab)

    @pyqtSlot(Tab, str)
    def saveTab(self, tab, file):
        file = os.path.abspath(QUrl(file).toLocalFile())
        text = tab.content
        with open(file, "w") as f:
            f.write(text)

    @pyqtProperty(bool, notify=dragUpdated)
    def draggingTab(self):
        return self._draggedTab != None
    
    @pyqtProperty(bool, notify=dragUpdated)
    def draggingArea(self):
        return self._draggedArea != None
    
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

    @pyqtSlot(TabArea)
    def dragArea(self, area):
        self._draggedArea = area
        self.dragUpdated.emit()
        mimeData = QMimeData()
        mimeData.setData(MIME_POSITION_AREA, QByteArray(f"POSITION".encode()))
        drag = QDrag(self)
        drag.setMimeData(mimeData)
        drag.exec()
        self._draggedArea = None
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
                    sourceArea.removeTab(tab, sourceArea != targetArea)
                index = targetArea._tabs.index(indexTab)
            else:
                if sourceArea:
                    sourceArea.removeTab(tab, sourceArea != targetArea)
            targetArea.insertTab(tab, index)
            targetArea.currentUpdated.emit()
        
        if tab in targetArea._tabs:
            targetArea.current = targetArea._tabs.index(tab)

    @pyqtSlot(TabArea, str)
    def dropArea(self, area, target):
        sourceArea = self._draggedArea
        targetArea = area

        if sourceArea == targetArea:
            return

        self._areas.remove(sourceArea)
        self.expandAreas()
        self.areasUpdated.emit()

        position = targetArea.splitArea(target)
        sourceArea.position = position
        self._areas += [sourceArea]
        self.areasUpdated.emit()

        self.current = area
        
    @pyqtProperty(TabArea, notify=currentUpdated)
    def current(self):
        return self._current
    
    @current.setter
    def current(self, current):
        if(current != self._current):
            self._current = current
            self.currentUpdated.emit()

    def currentTab(self):
        return self._current._tabs[self._current._current]

    @pyqtSlot()
    def nextArea(self):
        area = None
        if self._current in self._areas:
            index = self._areas.index(self._current)
            index = (index + 1) % len(self._areas)
            area = self._areas[index]
        elif self._areas:
            area = self._areas[0]

        if area and area != self._current:
            self._current = area
            self.currentUpdated.emit()

    @pyqtSlot()
    def prevArea(self):
        area = None
        if self._current in self._areas:
            index = self._areas.index(self._current)
            index = (index - 1) % len(self._areas)
            area = self._areas[index]
        elif self._areas:
            area = self._areas[0]

        if area and area != self._current:
            self._current = area
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