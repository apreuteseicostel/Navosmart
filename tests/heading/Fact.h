#pragma once
#include <QVariant>

// Minimal QGC Fact test double for the production GNSS diagnostic reader.
class Fact {
public:
    explicit Fact(const QVariant& value={}) : _value(value) {}
    QVariant rawValue() const { return _value; }
    void setRawValue(const QVariant& value) { _value=value; }
private:
    QVariant _value;
};
