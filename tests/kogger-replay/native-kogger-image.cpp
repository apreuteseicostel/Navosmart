#include "../../custom/kogger_native/navo_kogger_echogram_palette.h"
#include "../../custom/kogger_native/navo_kogger_echogram_sampling.h"
#include "../../custom/src/NavoKoggerEchogramItem.h"
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QSet>
#include <QtGlobal>
#include <cassert>
#include <cmath>
#include <iostream>
#include <stdexcept>
static void require(bool condition,const char* message) {
    if(!condition)throw std::runtime_error(message);
}
int main(int argc,char**argv) {
    qputenv("QT_QPA_PLATFORM","offscreen");
    QGuiApplication app(argc,argv);
    const auto classic=NavoKoggerPalette::colors(0,0,100);
    const auto ice=NavoKoggerPalette::colors(1,0,100);
    const auto sepia=NavoKoggerPalette::colors(2,0,100);
    require(classic.size()==256 && ice.size()==256 && sepia.size()==256,
            "Kogger 8-bit palette should contain 256 RGB entries");
    require(classic[0]==qRgb(0,0,0) && classic[255]==qRgb(255,255,255),
            "Kogger Classic palette original anchor colors lost");
    require(ice[0]==qRgb(0,0,70) && sepia[255]==qRgb(255,232,160),
            "original Kogger Ice/Sepia stops changed");
    QSet<QRgb> distinct;
    for(auto c:classic)distinct.insert(c);
    require(distinct.size()>150,"Kogger image is still four-color quantized");
    const auto contrast=NavoKoggerPalette::colors(0,20,80);
    require(contrast!=classic && contrast.front()==classic.front(),
            "low/high display levels are not mapped without modifying CHART");
    QByteArray samples;
    samples.append(char(0));samples.append(char(64));
    samples.append(char(128));samples.append(char(255));
    using NavoKoggerSampling::atDisplayDepth;
    require(atDisplayDepth(samples,0,0,1,0,0.25)==0,"Kogger near sample wrong");
    require(atDisplayDepth(samples,0,0,1,1,0.25)==64,"Kogger full 8-bit column wrong");
    require(atDisplayDepth(samples,0,0,1,3,0.25)==255,"Kogger maximum sample clipped");
    require(atDisplayDepth(samples,0,0,1,1,2.0)>50,"Kogger downsampling lost signal");
    require(atDisplayDepth(samples,0,0,1,1.5,0.25)>64,"Kogger zoom interpolation missing");
    require(atDisplayDepth(samples,0,0,1,10,0.25)==0,"samples outside physical range should be blank");
    require(atDisplayDepth(samples,0,0,0,1,0.25)==0,"zero sample resolution accepted");
    QByteArray version1;
    version1.append(char(32));version1.append(char(0));
    version1.append(char(220));version1.append(char(0));
    require(atDisplayDepth(version1,1,0,1,1,0.1)==220,"CHART version 1 stride changed");
    NavoKoggerEchogramItem item;
    item.setWidth(256);item.setHeight(180);
    item.setPaletteMode(1);item.setLowLevel(15);item.setHighLevel(90);
    item.setDepthRange(12);item.setNoiseFloor(.04);
    QImage target(256,180,QImage::Format_ARGB32_Premultiplied);
    target.fill(Qt::transparent);
    QPainter painter(&target);item.paint(&painter);painter.end();
    require(qAlpha(target.pixel(120,30))==255,"native Qt Quick painter did not fill the image");
    require(item.columnCount()==0,"fresh renderer must not invent sonar data");
    require(item.inspectAt(40,40).isEmpty(),"inspector invented a CHART column");
    std::cout<<"PASS native Kogger 256-level palette, exact original palette stops, CHART sampling, valid source depths, 8-bit image rendering\n";
}
