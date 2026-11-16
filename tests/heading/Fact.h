#pragma once
#include <QVariant>
class Fact {
public:
    Fact() = default;
    explicit Fact(const QVariant& value) : _raw(value) {}
    QVariant rawValue() const { return _raw; }
    void setRawValue(const QVariant& value) { _raw = value; }
private:
    QVariant _raw;
};
