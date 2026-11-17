#pragma once
#include <QObject>
#include <QVariant>
// Minimal read-only QGC Fact stand-in for heading diagnostics.
class Fact:public QObject {
public:
 explicit Fact(QObject* parent=nullptr):QObject(parent){}
 QVariant rawValue()const{return _raw;}
 void setRawValue(const QVariant& v){_raw=v;}
private:
 QVariant _raw;
};
