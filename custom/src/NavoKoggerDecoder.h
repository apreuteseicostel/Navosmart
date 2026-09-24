#pragma once
#include <QObject>
#include <QByteArray>
#include <QVariantList>

class NavoKoggerDecoder : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
 Q_PROPERTY(double depthM READ depthM NOTIFY depthChanged)
 Q_PROPERTY(double waterTempC READ waterTempC NOTIFY temperatureChanged)
 Q_PROPERTY(QVariantList echoSamples READ echoSamples NOTIFY echoSamplesChanged)
public:
 explicit NavoKoggerDecoder(QObject* parent=nullptr);
 bool connected() const { return _connected; }
 double depthM() const { return _depthM; }
 double waterTempC() const { return _waterTempC; }
 QVariantList echoSamples() const { return _echoSamples; }
 Q_INVOKABLE void feedBytes(const QByteArray& bytes);
 Q_INVOKABLE void reset();
signals:
 void connectedChanged();
 void depthChanged();
 void temperatureChanged();
 void echoSamplesChanged();
 void frameRejected();
private:
 void process();
 bool validFrame(const QByteArray& frame) const;
 static quint16 le16(const char* p);
 static quint32 le32(const char* p);
 static constexpr int MaxBufferBytes=256*1024;
 static constexpr int MaxChartBytes=128*1024;
 QByteArray _buffer;
 QByteArray _chart;
 quint16 _chartResolution=0;
 quint16 _chartAbsoluteOffset=0;
 bool _connected=false;
 double _depthM=qQNaN();
 double _waterTempC=qQNaN();
 QVariantList _echoSamples;
};