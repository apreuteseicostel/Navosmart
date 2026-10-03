#include "../../custom/src/NavoKoggerDecoder.h"
#include <QGuiApplication>
#include "../../custom/src/NavoKoggerDatasetAdapter.h"
#include <QCryptographicHash>
#include <QFile>
#include <iostream>
#include <stdexcept>
#include <algorithm>

static void require(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}
static void u16(QByteArray& bytes, quint16 value) {
    bytes.append(char(value & 255)); bytes.append(char(value >> 8));
}
static QByteArray frame(bool kp2, quint16 seq, const QByteArray& data, int type=1) {
    QByteArray payload; u16(payload,seq); u16(payload,10); u16(payload,0); payload+=data;
    QByteArray f;
    if(kp2) {
        f=QByteArray::fromHex("cc550000030000");
        f.append(char(type)); u16(f,24); f+=payload;
        const int size=f.size()+2; f[2]=char(size&255); f[3]=char(size>>8);
    } else {
        f=QByteArray::fromHex("bb5500010300"); f[3]=char(type);
        f[5]=char(payload.size()); f+=payload;
    }
    quint8 a=0,b=0;
    for(int i=2;i<f.size();++i){a=quint8(a+quint8(f[i]));b=quint8(b+a);}
    f.append(char(a));f.append(char(b));return f;
}
static void synthetic() {
    for(bool kp2 : {false,true}) {
        NavoKoggerDecoder d; int count=0;
        QObject::connect(&d,&NavoKoggerDecoder::chartColumnReady,[&]{++count;});
        const QByteArray stream=frame(kp2,0,QByteArray::fromHex("1020"))+
            frame(kp2,4,QByteArray::fromHex("3040"))+frame(kp2,0,QByteArray::fromHex("5060"));
        for(const char b:stream)d.feedBytes(QByteArray(1,b));
        require(count==1,"split headers and payloads lost a column");
        require(d.chartRawBytes()==QByteArray::fromHex("102000003040"),"lost fragment offset was not preserved");
        require(d.chartResolution()==10 && std::abs(d.chartRangeMeters()-0.06)<1e-9,"physical scale changed");
        QByteArray corrupt=frame(kp2,0,QByteArray::fromHex("7080")); corrupt[corrupt.size()-1]=char(quint8(corrupt[corrupt.size()-1])^1);
        d.feedBytes(corrupt+frame(kp2,0,QByteArray::fromHex("90a0")));
        require(count==2 && d.chartRawBytes()==QByteArray::fromHex("5060"),"checksum resynchronization failed");
        d.feedBytes(frame(kp2,0,QByteArray::fromHex("b0c0"),2));
        require(count==2,"setting response became a measurement");
        d.reset(); require(!d.connected() && d.chartRawBytes().isEmpty(),"reset retained old recording");
    }
    std::cout<<"PASS KP1/KP2 fragmentation, missing fragments, checksum recovery, type filter and reset\n";
}
struct Result { qint64 columns=0; QByteArray hash; };
static Result replay(const QByteArray& bytes, bool fragmented) {
    NavoKoggerDecoder d; Result result; QCryptographicHash hash(QCryptographicHash::Sha256);
    NavoKoggerDatasetAdapter adapter;
    Dataset dataset;
    // Test-only channel identity for this fixture, never a live connection UUID.
    const ChannelId channel(QUuid("{52202375-23b1-44cb-83a8-d2b8611efbab}"),0);
    QObject::connect(&d,&NavoKoggerDecoder::chartColumnReady,[&]{
        require(d.chartVersion()==0,"unexpected published version");
        require(d.chartResolution()==10 && d.chartAbsoluteOffset()==0,"unexpected CHART metadata");
        require(d.chartRawBytes().size()==5000,"unexpected column length");
        require(adapter.append(d,qQNaN(),qQNaN(),0),"adapter rejected fixture column");
        const auto& record=adapter.records().last();
        require(!record.hasPosition(),"replay fabricated GPS");
        Epoch epoch;
        require(!NavoKoggerDatasetAdapter::toKoggerEpoch(record,ChannelId(),epoch),"invalid channel was accepted");
        require(NavoKoggerDatasetAdapter::toKoggerEpoch(record,channel,epoch),"Epoch conversion failed");
        const auto* chart=epoch.chart(channel,0);
        require(chart && chart->amplitude.size()==5000 && std::abs(chart->resolution-0.01f)<1e-6f,
                "Epoch lost chart samples or physical scale");
        for(int i=0;i<5000;++i)
            require(chart->amplitude[i]==quint8(record.chart[i]),"Epoch modified raw amplitude");
        require(NavoKoggerDatasetAdapter::appendToKoggerDataset(record,channel,dataset),"Dataset ingestion failed");
        const auto latest=dataset.fromIndexCopy(dataset.endIndex());
        Epoch copy=latest;
        const auto* stored=copy.chart(channel,0);
        require(stored && stored->amplitude==chart->amplitude,"Dataset/Epoch chart differs");
        // Bound test Dataset batches; this does not claim production eviction.
        if(dataset.size()>=128)dataset.resetDataset();
        hash.addData(d.chartRawBytes()); ++result.columns;
    });
    if(!fragmented)d.feedBytes(bytes);
    else {
        const int sizes[]={1,13,4096,257,23}; int index=0;
        for(qsizetype offset=0;offset<bytes.size();){
            const qsizetype size=std::min(qsizetype(sizes[index++%5]),bytes.size()-offset);
            d.feedBytes(bytes.mid(offset,size));offset+=size;
        }
    }
    require(adapter.records().size()==3000 && adapter.retainedRawBytes()==15000000,
            "adapter retention budget failed");
    result.hash=hash.result().toHex();return result;
}
int main(int argc,char**argv) {
    qputenv("QT_QPA_PLATFORM","offscreen");
    QGuiApplication app(argc,argv);
    try {
        synthetic();
        if(argc==2) {
            QFile file(QString::fromLocal8Bit(argv[1])); require(file.open(QIODevice::ReadOnly),"cannot open KLF");
            const QByteArray bytes=file.readAll();
            require(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex()==
                "1ff5e23abbdd37e31eeacd7875c4e8a457ccb927641e47ea77c861151ab2ace0","fixture hash mismatch");
            const Result whole=replay(bytes,false), split=replay(bytes,true);
            require(whole.columns==15423 && split.columns==whole.columns,"recorded column count mismatch");
            require(whole.hash=="f597aee532fadf5ec71e48b4fd2f8890ee32c63927023e66d15516dfef745055" && split.hash==whole.hash,
                "recorded CHART bytes differ from fixture reference");
            std::cout<<"PASS KLF: "<<whole.columns<<" completed columns, 5000 samples, 10 mm, byte-identical chunked replay, Dataset/Epoch ingestion and bounded adapter retention\n";
            std::cout<<"Trailing 200-sample column remains pending; live decoding needs the next column boundary.\n";
        }
    }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
