import hunspell
import re
import os
import collections
import difflib

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, Qt, QObject, QPoint, QAbstractListModel, QModelIndex, QVariant, QByteArray
from PyQt5.QtQml import qmlRegisterUncreatableType

WORD_RE = re.compile(r"\b[a-zA-Z-'’]+\b")
DICT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictionary")
CACHE_SIZE = 10240
MARK = 0x00AD

class Dictionary():
    def __init__(self):
        dic_f = os.path.join(DICT_PATH, "en_US.dic")
        aff_f = os.path.join(DICT_PATH, "en_US.aff")

        self.spell = None
        if os.path.exists(dic_f) and os.path.exists(aff_f):
            self.spell = hunspell.HunSpell(dic_f, aff_f)
        
        self.cache = collections.OrderedDict()
    
    def lookup(self, term):
        if not self.spell:
            return None

        if len(term) > 15:
            return None

        if term in self.cache:
            return self.cache[term]
        
        suggestions = None

        if not self.spell.spell(term):
            suggestions = self.spell.suggest(term)
        
        self.cache[term] = suggestions
        if len(self.cache) > 10240:
            self.cache.popitem(0)

        return suggestions
    
    def add(self, word):
        self.spell.add(word)

class Word(QObject):
    updated = pyqtSignal()
    def __init__(self, text, start, parent):
        super().__init__(parent)
        self.text = text
        self.start = start
        self.results = []

    @pyqtProperty(QPoint, notify=updated)
    def span(self):
        return QPoint(self.start, self.start+len(self.text))
    
    @pyqtProperty(list, notify=updated)
    def suggestions(self):
        if self.results:
            return self.results
        return []
    
    def move(self, start):
        if start != self.start:
            self.start = start
            self.updated.emit()

    def check(self, dict):
        if not self.results:
            self.results = dict.lookup(self.text)
            if self.results:
                self.updated.emit()

class Spellchecker(QAbstractListModel):
    def __init__(self, dictionary, parent):
        super().__init__(parent)
        self.text = ""
        self.words = []
        self.dictionary = dictionary

    def data(self, index, role):
        value = QVariant()
        row = index.row()
        if row < len(self.words):
            value = self.words[row]
        return value
    
    def rowCount(self, parent):
        return len(self.words)

    def roleNames(self):
        return {Qt.UserRole: QByteArray(("modelData").encode("utf-8"))}
    
    @pyqtSlot(str)
    def update(self, text):
        new_words = []
        text = text.replace(chr(MARK), '')

        if text == self.text:
            return

        for m in WORD_RE.finditer(text):
            t = m.group()
            s,e = m.span()
            new_words += [Word(t,s,self)]
        
        new_lines = [w.text for w in new_words]
        old_lines = [w.text for w in self.words]

        diff = difflib.ndiff(old_lines, new_lines)

        i = 0
        for d in diff:
            if d[0] == "+":
                self.beginInsertRows(QModelIndex(), i, i)
                self.words.insert(i, new_words[i])
                self.endInsertRows()
                i += 1
            elif d[0] == "-":
                self.beginRemoveRows(QModelIndex(), i, i)
                self.words.pop(i)
                self.endRemoveRows()
            elif d[0] == " ":
                self.words[i].move(new_words[i].start)
                i += 1

        self.text = text

    @pyqtSlot()
    def check(self):
        for word in self.words:
            word.check(self.dictionary)

def registerTypes():
    qmlRegisterUncreatableType(Word, "gui", 1, 0, "Word", "Not a QML type")
    qmlRegisterUncreatableType(Spellchecker, "gui", 1, 0, "Spellchecker", "Not a QML type")