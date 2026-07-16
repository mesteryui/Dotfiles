pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    PersistentProperties {
        id: storage
        property var historyData: []
        property bool dnd: false
    }

    // 1. FORMA CORRECTA: Exponemos los modelos al exterior usando 'alias'
    property alias historyModel: _historyModel
    property alias activeModel: _activeModel

    // 2. Declaramos los ListModel como objetos hijos internos
    ListModel { id: _historyModel }
    ListModel { id: _activeModel }

    Component.onCompleted: {
        // CORRECCIÓN 1: Forzamos a que siempre sea un array
        let initialData = storage.historyData || [];
        for (let i = 0; i < initialData.length; i++) {
            _historyModel.append(initialData[i]);
        }
    }

    function addNotification(notification) {
        if (storage.dnd && notification.urgency !== NotificationUrgency.Critical)
            return;

        const timestamp = new Date().toLocaleTimeString();

        // 1. Guardar en el historial
        const entry = {
            summary: notification.summary ?? "Sin título",
            body: notification.body ?? "",
            appName: notification.appName ?? "Sistema",
            icon: notification.appIcon ?? notification.image ?? "",
            time: timestamp,
            urgency: notification.urgency
        };
        _historyModel.insert(0, entry);
        
        // CORRECCIÓN 2: Extraemos los datos a una variable segura con fallback a []
        let currentData = storage.historyData || [];
        let newData = [entry];
        
        // Ahora currentData.length es 100% seguro y nunca será undefined
        let maxLimit = Math.min(currentData.length, 49); 
        for (let i = 0; i < maxLimit; i++) {
            newData.push(currentData[i]);
        }
        storage.historyData = newData;

        // 2. Inyectar el objeto VIVO en el modelo activo
        _activeModel.insert(0, { "notifObj": notification });
    }

    function disposeNotification(id) {
        // Buscamos y eliminamos del ListModel activo de forma segura
        for (let i = 0; i < _activeModel.count; i++) {
            let item = _activeModel.get(i);
            if (item && item.notifObj && item.notifObj.id === id) {
                _activeModel.remove(i, 1);
                break;
            }
        }
    }

    function clearHistory() {
        _historyModel.clear();
        storage.historyData = [];
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.addNotification(n)
    }
}