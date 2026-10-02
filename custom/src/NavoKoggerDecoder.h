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
 Q_PROPERTY(QVariantList compensatedSamples READ compensatedSamples NOTIFY echoSamplesChanged)
 Q_PROPERTY(QByteArray chartRawBytes READ chartRawBytes NOTIFY echoSamplesChanged)
 Q_PROPERTY(quint16 chartResolution READ chartResolution NOTIFY echoSamplesChanged)
 Q_PROPERTY(quint16 chartAbsoluteOffset READ chartAbsoluteOffset NOTIFY echoSamplesChanged)
 Q_PROPERTY(quint8 chartVersion READ chartVersion NOTIFY echoSamplesChanged)
 Q_PROPERTY(double chartResolutionMeters READ chartResolutionMeters NOTIFY echoSamplesChanged)
 Q_PROPERTY(double chartOffsetMeters READ chartOffsetMeters NOTIFY echoSamplesChanged)
 Q_PROPERTY(double chartRangeMeters READ chartRangeMeters NOTIFY echoSamplesChanged)
public:
 explicit NavoKoggerDecoder(QObject* parent=nullptr);
 bool connected() const { return _connected; }
 double depthM() const { return _depthM; }
 double waterTempC() const { return _waterTempC; }
 QVariantList echoSamples() const { return _echoSamples; }
 QVariantList compensatedSamples() const { return _compensatedSamples; }
 QByteArray chartRawBytes() const { return _publishedChartRaw; }
 quint16 chartResolution() const { return _publishedChartResolution; }
 quint16 chartAbsoluteOffset() const { return _publishedChartAbsoluteOffset; }
 quint8 chartVersion() const { return _publishedChartVersion; }
 double chartResolutionMeters() const { return double(_publishedChartResolution) * 0.001; }
 double chartOffsetMeters() const { return double(_publishedChartAbsoluteOffset) * double(_publishedChartResolution) * 0.001; }
 int chartSampleCount() const { return _publishedChartRaw.size() / (_publishedChartVersion == 1 ? 2 : 1); }
 double chartRangeMeters() const { return double(chartSampleCount()) * chartResolutionMeters(); }
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
 QByteArray _publishedChartRaw;
 quint16 _chartResolution=0;
 quint8 _chartVersion=0;
 quint16 _publishedChartResolution=0;
 quint16 _publishedChartAbsoluteOffset=0;
 quint8 _publishedChartVersion=0;
 quint16 _chartAbsoluteOffset=0;
 bool _connected=false;
 double _depthM=qQNaN();
 double _waterTempC=qQNaN();
 QVariantList _echoSamples;
 QVariantList _compensatedSamples;
 void publishChart();
};