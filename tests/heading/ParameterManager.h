#pragma once
#include <QHash>
#include <QString>
#include <QStringList>
#include "Fact.h"

// QGroundControl 5.0.7 subset: cached facts and read-only refresh requests.
class ParameterManager {
public:
    static constexpr int defaultComponentId=-1;
    bool parametersReady() const { return _ready; }
    void setReady(bool ready) { _ready=ready; }
    bool parameterExists(int,const QString& key) const { return _facts.contains(key); }
    Fact* getParameter(int,const QString& key) {
        auto it=_facts.find(key);
        return it==_facts.end() ? nullptr : &it.value();
    }
    void set(const QString& key,const QVariant& value) { _facts.insert(key,Fact(value)); }
    void refreshParameter(int,const QString& key) { _requests.append(key); }
    const QStringList& readRequests() const { return _requests; }
private:
    bool _ready=false;
    QHash<QString,Fact> _facts;
    QStringList _requests;
};
