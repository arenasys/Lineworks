import QtQuick 2.15

ListModel {
    property var source
    property var current: []
    property var unique: false // avoids object destruction/recreation, requires all object to be unique, slower
    property var debug: false

    function doAppend(obj) {
        if(debug) {
            console.log("APPEND")
        }
        current.push(obj)
        append({"data":obj})
    }

    function doInsert(i, obj) {
        if(debug) {
            console.log("INSERT", i)
        }
        current.splice(i, 0, obj);
        insert(i, {"data":obj})
    }

    function doRemove(i) {
        if(debug) {
            console.log("REMOVE", i)
        }
        current.splice(i, 1)
        remove(i)
    }

    function doMove(a, b) {
        if(debug) {
            console.log("MOVE", a, b)
        }
        var e = current[a];
        current.splice(a, 1);
        current.splice(b, 0, e);
        move(a,b,1)
    }

    function doReplace(i, obj) {
        if(debug) {
            console.log("REPLACE", i)
        }
        current[i] = obj
        set(i, {"data":obj})
    }

    function doClear() {
        if(debug) {
            console.log("CLEAR")
        }
        current = []
        clear()
    }

    function getCurrent() {
        var out = []
        for(var i = 0; i < count; i++) {
            out.push(get(i).data)
        }
        return out
    }

    function find(a, b) {
        for(var i = 0; i < a.length; i++) {
            var e = a[i]
            if(a[i] == b) {
                return i
            }
        }
        return -1
    }

    function syncGeneral() {
        if(source == undefined) {
            doClear()
            return
        }

        var next = [];
        for(var i = 0; i < source.length; i++) {
            next.push(source[i])
        }

        if(current.length == 0 && next.length != 0) {
            for(var i = 0; i < next.length; i++) {
                doAppend(next[i])
            }
            return
        }

        if(current.length != 0 && next.length == 0) {
            doClear()
            return
        }

        var total = next.length
        var i = 0
        while(next.length != 0 && i < current.length) {
            if(current[i] == next[0]) {
                next.shift()
                i += 1
                continue
            }

            var src_idx = find(current.slice(i), next[0])
            var dst_idx = find(next, current[i])

            if(src_idx == -1 && dst_idx == -1) {
                doReplace(i, next.shift())
                i += 1
                continue
            }
            
            if (src_idx > 0) {
                for(var j = 0; j < src_idx; j++) {
                    doRemove(i)
                }
            }

            if (dst_idx > 0) {
                for(var j = 0; j < dst_idx; j++) {
                    doInsert(i, next.shift())
                    i += 1
                }
            }
        }

        while(next.length != 0) {
            doAppend(next.shift())
        }

        while(current.length > total) {
            doRemove(current.length-1)
        }
    }

    function syncUnique() {
        if(source == undefined) {
            doClear()
            return
        }

        var next = [];
        for(var i = 0; i < source.length; i++) {
            next.push(source[i])
        }

        for(var i = 0; i < current.length; i++) {
            if(!next.includes(current[i])) {
                doRemove(i)
                i--;
            }
        }

        var sub = [];
        for(var i = 0; i < next.length; i++) {
            if(current.includes(next[i])) {
                sub.push(next[i])
            }
        }

        for(var i = 0; i < sub.length; i++) {
            if(current[i] != sub[i]) {
                var j = current.indexOf(sub[i]);
                doMove(j, i)
            }
        }

        for(var i = 0; i < next.length; i++) {
            if(!current.includes(next[i])) {
                doInsert(i, next[i])
            }
        }
    }

    function sync() {
        if(unique) {
            syncUnique()
        } else {
            syncGeneral()
        }
        if(debug) {
            console.log(source, current, getCurrent())
        }
    }

    onSourceChanged: {
        sync()
    }

    Component.onCompleted: {
        sync()
    }
}