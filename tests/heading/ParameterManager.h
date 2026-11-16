#pragma once
#include <QMap>
#include <QStringList>
#include "Fact.h"

class ParameterManager {
public:
    static constexpr int defaultComponentId = -1;
    bool parameterExists(int componentId, const QString& name) const {
        return componentId == defaultComponentId && _facts.contains(name);
    }
    Fact* getParameter(int componentId, const QString& name) {
        if (!parameterExists(componentId, name)) return nullptr;
        return &_facts[name];
    }
    void refreshParameter(int componentId, const QString& name) {
        if (componentId == defaultComponentId) requested << name;
    }
    void set(const QString& name, int value) { _facts[name].setRawValue(value); }
    QStringList requested;
private:
    QMap<QString, Fact> _facts;
};
