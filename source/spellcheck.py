import hunspell
import re
import os
import collections
import time

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, Qt, QObject, QPoint, QThread, QRunnable, QMutex, QReadWriteLock, QThreadPool
from PyQt5.QtQml import qmlRegisterUncreatableType

from cdifflib import CSequenceMatcher
import difflib
difflib.SequenceMatcher = CSequenceMatcher


WORD_RE = re.compile(r"[\w'’]+")
LINE_RE = re.compile(r".+\n*")
DICT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictionary")
CACHE_SIZE = 10240
MARK = 0x00AD

class Dictionary():
    def __init__(self):
        dic_f = os.path.join(DICT_PATH, "en_US.dic")
        aff_f = os.path.join(DICT_PATH, "en_US.aff")

        self.spell = None
        if os.path.exists(dic_f) and os.path.exists(aff_f):
            self.spell = hunspell.Hunspell("en_US", hunspell_data_dir=DICT_PATH)

        self.populator = Populator(self)
        self.populator.start()
        
        self.added = []
        self.cache = collections.OrderedDict()
    
    def filterSuggestions(self, suggestions):
        out = []
        for s in suggestions:
            if len(s) > 3 and s[-2] == " ":
                continue
            out += [s]
            if len(out) == 5:
                break
        return out

    def lookupCache(self, term):
        suggestions = None
        if term in self.cache:
            suggestions = self.cache[term]
        return suggestions
    
    def lookupDictionary(self, term):
        suggestions = []

        if not self.spell.spell(term):
            suggestions = self.spell.suggest(term)
            suggestions = self.filterSuggestions(suggestions)

        self.cache[term] = suggestions
        if len(self.cache) > 10240:
            self.cache.popitem(0)

        return suggestions
    
    def lookup(self, term):
        if not self.spell:
            return []

        if len(term) > 15:
            return []

        suggestions = self.lookupCache(term)
        if suggestions != None:
            return suggestions
        
        self.populator.push([term])
        return None
    
    def add(self, word, affix=None):
        if "/" in word:
            return False

        if not word:
            return False

        if self.spell.spell(word):
            return False

        if affix == None and word[0].isupper():
            affix = "S"
        
        if affix != None:
            self.spell.add(word, affix)
            self.added += [word + "/" + affix]
        else:
            self.spell.add(word)
            self.added += [word]

        for c in list(self.cache.keys()):
            if word.lower() in c.lower():
                del self.cache[c]

        return True

class Populator(QThread):
    def __init__(self, dictionary):
        super().__init__()
        self.words = set()
        self.adding = []
        self.dictionary = dictionary
        self.stopping = False

    def push(self, words):
        for word in words:
            if not word in self.words:
                self.words.add(word)

    def add(self, words):
        self.adding = words

    def stop(self):
        self.running = False

    def run(self):
        while not self.stopping:
            if self.adding:
                for word in self.adding:
                    if "/" in word:
                        word, affix = word.split("/")
                        self.dictionary.add(word, affix)
                    else:
                        self.dictionary.add(word)

            word = None
            if len(self.words) != 0:
                word = self.words.pop()
            
            if word:
                if not word in self.dictionary.cache:
                    self.dictionary.lookupDictionary(word)
            else:
                QThread.msleep(1)

class Word(QObject):
    updated = pyqtSignal()
    spanUpdated = pyqtSignal()
    def __init__(self, text, start, parent):
        super().__init__(parent)
        self.text = text
        self.start = start
        self.incorrect = None

    @pyqtProperty(str, notify=updated)
    def word(self):
        return self.text
    
    @pyqtProperty(QPoint, notify=spanUpdated)
    def span(self):
        return QPoint(self.start, self.start+len(self.text))
    
    def move(self, start):
        if start != self.start:
            self.start = start
            self.spanUpdated.emit()

    def __repr__(self) -> str:
        return str((self.text, self.start))
    
class Line(QObject):
    incorrectUpdated = pyqtSignal()
    spanUpdated = pyqtSignal()
    def __init__(self, text, start, parent):
        super().__init__(parent)
        self.text = text
        self.start = start
        self._words = []
        self._incorrect = []

        self.update(text)

    @pyqtProperty(list, notify=incorrectUpdated)
    def incorrect(self):
        return self._incorrect
    
    @pyqtProperty(QPoint, notify=spanUpdated)
    def span(self):
        return QPoint(self.start, self.start+len(self.text.rstrip()))

    def update(self, text, start=None):
        new_words = []
        old_words = [w.text for w in self._words]

        for m in WORD_RE.finditer(text):
            new_words += [(m.group(), m.span()[0])]

        word_diff = [str(d)[0] for d in difflib.ndiff(old_words, [l[0] for l in new_words])]
        word_diff = [d for d in word_diff if d in {' ', '-', '+'}]

        i = 0
        changed = False
        for d in word_diff:
            if d == "+":
                self._words.insert(i, Word(new_words[i][0], new_words[i][1], self))
                changed = True
                i += 1
            elif d == "-":
                self._words.pop(i)
                changed = True
            elif d == " ":
                if self._words[i].start != new_words[i][1]:
                    self._words[i].move(new_words[i][1])
                i += 1
        
        if start != None:
            self.start = start
        self.text = text
        self.spanUpdated.emit()
        
        if changed:
            self.sync()
    
    def move(self, start):
        if start != self.start:
            self.start = start
            self.spanUpdated.emit()

    def sync(self):
        incorrect = []
        for word in self._words:
            if word.incorrect:
                incorrect += [word]

        if incorrect != self._incorrect:
            self._incorrect = incorrect
            self.incorrectUpdated.emit()

    def check(self):
        dictionary = self.parent().dictionary

        missing = False
        incorrect = []

        start = time.time()
        for word in self._words:
            if word.incorrect == None:
                if time.time()-start < 0.001:
                    results = dictionary.lookup(word.text)
                else:
                    results = None
                if results == None:
                    missing = True
                elif results:
                    word.incorrect = True
                else:
                    word.incorrect = False
                
            if word.incorrect:
                incorrect += [word]

        if not missing and incorrect != self._incorrect:
            self._incorrect = incorrect
            self.incorrectUpdated.emit()
            return missing

        return missing

    def clear(self, text):
        for word in self._words:
            if text.lower() in word.text.lower():
                word.incorrect = None

    def __repr__(self) -> str:
        return f"[{', '.join([str(w) for w in self._words])}, {self.start}]"

class Spellchecker(QObject):
    updated = pyqtSignal()
    def __init__(self, dictionary, parent):
        super().__init__(parent)
        self._lines = []
        self.dictionary = dictionary

    @pyqtProperty(list, notify=updated)
    def lines(self):
        return self._lines

    @pyqtSlot(str)
    def update(self, text):
        new_lines = []
        old_lines = [l.text for l in self._lines]

        text = text.replace(chr(MARK), '')

        if text and text[-1] != "\n":
            text += "\n"
        
        for m in LINE_RE.finditer(text):
            new_lines += [(m.group(), m.span()[0])]

        line_diff = [str(d)[0] for d in difflib.ndiff(old_lines, [l[0] for l in new_lines])]
        line_diff = [d for d in line_diff if d in {' ', '-', '+'}]
    
        i = 0
        j = 0
        changed = False
        while j < len(line_diff):
            d = line_diff[j]
            dd = line_diff[j+1] if j+1 < len(line_diff) else ''
            
            if d == '-' and dd == '+':
                self._lines[i].update(new_lines[i][0], new_lines[i][1])
                i += 1
                j += 1
            elif d == "+":
                self._lines.insert(i, Line(new_lines[i][0], new_lines[i][1], self))
                changed = True
                i += 1
            elif d == "-":
                self._lines.pop(i)
                changed = True
            elif d == " ":
                self._lines[i].move(new_lines[i][1])
                i += 1
            j += 1

        if changed:
            self.updated.emit()

    @pyqtSlot(str, result=list)
    def getSuggestions(self, text):
        return self.dictionary.lookup(text)


    @pyqtSlot(str, result=bool)
    def addWord(self, word):
        if self.dictionary.add(word):
            for line in self._lines:
                line.clear(word)
            return True
        return False

    @pyqtSlot(result=bool)
    def check(self):
        recheck = False
        for line in self._lines:
            r = line.check()
            recheck = recheck or r
        return recheck

def registerTypes():
    qmlRegisterUncreatableType(Word, "gui", 1, 0, "Word", "Not a QML type")
    qmlRegisterUncreatableType(Line, "gui", 1, 0, "Line", "Not a QML type")
    qmlRegisterUncreatableType(Spellchecker, "gui", 1, 0, "Spellchecker", "Not a QML type")