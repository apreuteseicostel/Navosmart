#include <QCoreApplication>
#include <QTest>
#include <cmath>
#include <cstring>
#include "Vehicle.h"
#include "NavoGnssHeading.h"

class HeadingTest:public QObject {
 Q_OBJECT
 static void gps(Vehicle&v,uint16_t yaw,bool gps2=false,int sysid=1,int compid=1) {
  mavlink_message_t m;m.sysid=sysid;m.compid=compid;
  m.msgid=gps2?MAVLINK_MSG_ID_GPS2_RAW:MAVLINK_MSG_ID_GPS_RAW_INT;
  if(gps2){m.gps2.yaw=yaw;m.gps2.fix_type=3;m.gps2.satellites_visible=15;}
  else{m.gps.yaw=yaw;m.gps.fix_type=3;m.gps.satellites_visible=15;m.gps.h_acc=1200;}
  v.send(m);
 }
 static void p(Vehicle&v,const char* name,float value,int sysid=1) {
  mavlink_message_t m;m.msgid=MAVLINK_MSG_ID_PARAM_VALUE;m.sysid=sysid;
  std::strncpy(m.param.param_id,name,sizeof(m.param.param_id));
  m.param.param_value=value;v.send(m);
 }
 static void mag(Vehicle&v,bool present,bool healthy,int sysid=1){
  mavlink_message_t m;m.msgid=MAVLINK_MSG_ID_SYS_STATUS;m.sysid=sysid;
  m.status.onboard_control_sensors_present=present?4:0;
  m.status.onboard_control_sensors_enabled=present?4:0;
  m.status.onboard_control_sensors_health=healthy?4:0;
  v.send(m);
 }
 static void event(Vehicle&v,const char*msg,int sysid=1){
  mavlink_message_t m;m.msgid=MAVLINK_MSG_ID_STATUSTEXT;m.sysid=sysid;
  std::strncpy(m.text.text,msg,sizeof(m.text.text)-1);v.send(m);
 }
 static void configure(Vehicle&v){
  p(v,"EK3_SRC1_YAW",3);
  p(v,"COMPASS_USE",1);
  p(v,"COMPASS_DEV_ID",112233);
  mag(v,true,true);
 }
private slots:
 void cachedParametersAndReadRequests() {
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  // The sensor is healthy, but device ID and source params are not
  // automatically broadcast to a newly attached NAVO module.
  h.setAutopilotHeadingDeg(54);
  mag(v,true,true);
  QCOMPARE(h.compassDeviceId(),-1);
  QVERIFY(h.compassStatus().contains(QStringLiteral("necitit")));
  QCOMPARE(h.headingSource(),QStringLiteral("HEADING --"));
  h.requestCompassParameters();
  QCOMPARE(v.parameterManager()->requested.size(),3);
  QVERIFY(v.parameterManager()->requested.contains(QStringLiteral("COMPASS_DEV_ID")));
  QVERIFY(v.parameterManager()->requested.contains(QStringLiteral("EK3_SRC1_YAW")));
  QVERIFY(v.parameterManager()->requested.contains(QStringLiteral("COMPASS_USE")));
  // The QGC ParameterManager may already hold those Facts, even if NAVO
  // never saw their original MAVLink PARAM_VALUE broadcasts.
  v.parameterManager()->set(QStringLiteral("COMPASS_DEV_ID"),658953);
  v.parameterManager()->set(QStringLiteral("COMPASS_USE"),1);
  v.parameterManager()->set(QStringLiteral("EK3_SRC1_YAW"),3);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QCOMPARE(h.compassDeviceId(),658953);
  QCOMPARE(h.ekfYawMode(),3);
  QVERIFY(!h.compassStatus().contains(QStringLiteral("necitit")));
  QVERIFY(!h.compassFallbackActive()); // HEALTHY + 54° never prove magnetic yaw
  QCOMPARE(h.headingSource(),QStringLiteral("HEADING --"));
  // Genuine EKF3 magnetic fallback announcement permits the selection;
  // only after the parameters, health and an absolute reference are valid.
  event(v,"EKF3 IMU0 yaw fallback active");
  QVERIFY(h.compassFallbackActive());
  QCOMPARE(h.selectedHeadingDeg(),54.0);
  h.setLinkAlive(false);
  QCOMPARE(h.compassDeviceId(),-1);
  QVERIFY(std::isnan(h.selectedHeadingDeg()));
 }
 void missingAndZeroDeviceRemainExplicit() {
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  p(v,"COMPASS_DEV_ID",0);
  QCOMPARE(h.compassDeviceId(),0);
  QVERIFY(h.compassStatus().contains(QStringLiteral("COMPASS_DEV_ID=0")));
  p(v,"COMPASS_DEV_ID",658953);
  QCOMPARE(h.compassDeviceId(),658953);
  QCOMPARE(h.headingSource(),QStringLiteral("HEADING --"));
 }
 void priorityAndSensorIdentity(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  h.setAutopilotHeadingDeg(110);
  QVERIFY(std::isnan(h.selectedHeadingDeg())); // unanchored gyro never absolute
  QCOMPARE(h.headingSource(),QStringLiteral("HEADING --"));
  // Foreign system/component must never spoof a GNSS yaw.
  gps(v,9000,false,9);QVERIFY(!h.gpsYawValid());
  gps(v,9000,false,1,7);QVERIFY(!h.gpsYawValid());
  gps(v,9000);
  QVERIFY(h.gpsYawValid());QCOMPARE(h.selectedHeadingDeg(),90.0);
  QCOMPARE(h.headingSource(),QStringLiteral("GNSS GPS1 / UM982"));
  gps(v,24000,true);QCOMPARE(h.selectedHeadingDeg(),90.0);
  gps(v,65535);QVERIFY(h.gpsYawValid());
  QCOMPARE(h.headingSource(),QStringLiteral("GNSS GPS2"));
  QCOMPARE(h.selectedHeadingDeg(),240.0);
  gps(v,0,true);QVERIFY(!h.gpsYawValid());
  QVERIFY(h.h743FallbackActive());QCOMPARE(h.selectedHeadingDeg(),110.0);
  QCOMPARE(h.headingSource(),QStringLiteral("H743 / EKF (temporar)"));
  h.setLinkAlive(false);QVERIFY(std::isnan(h.selectedHeadingDeg()));
  h.setLinkAlive(true);QVERIFY(!h.h743FallbackActive());
 }
 void compassRequiresExactEKFEventAndHealth(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  h.setAutopilotHeadingDeg(70);
  gps(v,32000);
  gps(v,65535);
  mag(v,true,true);
  event(v,"EKF3 IMU0 yaw fallback active");
  QVERIFY(!h.compassFallbackActive()); // no EK3 / compass ID parameters
  p(v,"EK3_SRC1_YAW",2);p(v,"COMPASS_USE",1);p(v,"COMPASS_DEV_ID",98765);
  QVERIFY(!h.compassFallbackActive()); // EKF yaw mode must be GPS+mag fallback 3
  p(v,"EK3_SRC1_YAW",3);
  QVERIFY(h.compassHealthy()&&h.compassFallbackActive());
  QCOMPARE(h.selectedHeadingDeg(),70.0);
  QVERIFY(h.headingSource().contains(QStringLiteral("Busolă")));
  mag(v,true,false);
  QVERIFY(!h.compassFallbackActive()); // instantly reject unhealthy magnetometer
  QVERIFY(h.h743FallbackActive()); // briefly estimated gyro/EKF only
  mag(v,true,true);
  QVERIFY(h.compassFallbackActive()); // same EKF event remains until external
  event(v,"EKF3 IMU0 yaw external");
  QVERIFY(!h.compassFallbackActive());
  QVERIFY(h.h743FallbackActive());
  event(v,"EKF3 IMU0 yaw fallback active",9); // foreign MAVLink source
  QVERIFY(!h.compassFallbackActive());
  event(v,"EKF3 IMU0 yaw fallback active");
  QVERIFY(h.compassFallbackActive());
  gps(v,25000);QVERIFY(!h.compassFallbackActive());
  QCOMPARE(h.headingSource(),QStringLiteral("GNSS GPS1 / UM982"));
  QCOMPARE(h.selectedHeadingDeg(),250.0);
  gps(v,65535);
  QVERIFY(!h.compassFallbackActive()); // stale fallback event must not revive
  QVERIFY(h.h743FallbackActive());
  h.setVehicle(nullptr);QVERIFY(std::isnan(h.selectedHeadingDeg()));
 }
 void calibrationAndParameterGuards(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  h.setAutopilotHeadingDeg(156);gps(v,15000);gps(v,65535);
  event(v,"EKF3 IMU0 yaw fallback active");
  mag(v,true,true);p(v,"EK3_SRC1_YAW",3);p(v,"COMPASS_USE",0);p(v,"COMPASS_DEV_ID",1234);
  QVERIFY(!h.compassFallbackActive());
  p(v,"COMPASS_USE",1);QVERIFY(h.compassFallbackActive());
  p(v,"COMPASS_DEV_ID",0);QVERIFY(!h.compassFallbackActive());
  p(v,"COMPASS_DEV_ID",1234);QVERIFY(h.compassFallbackActive());
  mag(v,false,false);QVERIFY(!h.compassHealthy());QVERIFY(!h.compassFallbackActive());
 }
 void shortGyroHoldoverExpires(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  h.setAutopilotHeadingDeg(201);gps(v,20000);gps(v,65535);
  QVERIFY(h.h743FallbackActive());
  QTest::qWait(12100);
  QVERIFY(!h.h743FallbackActive());
  QVERIFY(std::isnan(h.selectedHeadingDeg()));
  QCOMPARE(h.headingSource(),QStringLiteral("HEADING --"));
 }
};
QTEST_GUILESS_MAIN(HeadingTest)
#include "heading.moc"
