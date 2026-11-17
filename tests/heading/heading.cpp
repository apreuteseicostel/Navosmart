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
 void explicitParameterReadIdentifiesIST8310AndKeepsQGCCacheSeparate(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  QCOMPARE(h.ekfYawMode(),-1);
  QVERIFY(!h.compassIdentity().contains(QStringLiteral("identificat")));
  h.requestDiagnosticParameters();
  auto* pm=v.parameterManager();
  QVERIFY(h.parameterRefreshPending());
  QVERIFY(pm->requested.contains(QStringLiteral("EK3_SRC1_YAW")));
  QVERIFY(pm->requested.contains(QStringLiteral("EK3_SRC2_YAW")));
  QVERIFY(pm->requested.contains(QStringLiteral("COMPASS_DEV_ID")));
  QVERIFY(pm->requested.contains(QStringLiteral("COMPASS_DEV_ID2")));
  QVERIFY(pm->requested.contains(QStringLiteral("COMPASS_PRIO1_ID")));
  QVERIFY(!pm->requested.contains(QStringLiteral("PARAM_SET")));
  // ArduPilot device ID: DEVTYPE_IST8310=0x0A, I2C type=1, bus=1,
  // address=0x0E. A non-zero ID alone is not proof of IST8310.
  const quint32 ist=(0x0Au<<16)|(0x0Eu<<8)|(1u<<3)|1u;
  pm->setFact(QStringLiteral("EK3_SRC1_YAW"),3);
  pm->setFact(QStringLiteral("COMPASS_USE"),1);
  pm->setFact(QStringLiteral("COMPASS_DEV_ID"),ist);
  pm->setFact(QStringLiteral("COMPASS_PRIO1_ID"),ist);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QCOMPARE(h.ekfYawMode(),3);
  QVERIFY(h.ekfYawStatus().contains(QStringLiteral("valoare QGC/cache")));
  QVERIFY(h.compassIdentity().contains(QStringLiteral("IST8310")));
  QVERIFY(h.compassIdentity().contains(QStringLiteral("I2C bus 1")));
  QVERIFY(h.compassIdentity().contains(QStringLiteral("COMPASS_DEV_ID")));
  QVERIFY(h.compassPriorityStatus().contains(QStringLiteral("IST8310")));
  QVERIFY(h.parameterReadStatus().contains(QStringLiteral("valori QGC")));
  p(v,"EK3_SRC1_YAW",3);
  QVERIFY(h.ekfYawStatus().contains(QStringLiteral("răspuns MAVLink")));
  h.setLinkAlive(false);
  QCOMPARE(h.ekfYawMode(),-1);
  QVERIFY(!h.compassIdentity().contains(QStringLiteral("IST8310")));
 }
 void compassIdIsNotModelProofAndMissingValuesRemainUnknown(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  auto* pm=v.parameterManager();
  h.requestDiagnosticParameters();
  pm->setFact(QStringLiteral("COMPASS_DEV_ID"),1234);
  pm->setFact(QStringLiteral("EK3_SRC1_YAW"),2);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(h.compassIdentity().contains(QStringLiteral("niciun ID nu confirmă IST8310")));
  QVERIFY(h.ekfYawStatus().contains(QStringLiteral("GPS yaw")));
  QVERIFY(!h.ekfYawStatus().contains(QStringLiteral("rezervă busolă")));
  // A different device may be healthy but must never be labelled IST8310.
  mag(v,true,true);
  QVERIFY(h.compassHealthy());
  QVERIFY(!h.compassIdentity().contains(QStringLiteral("IST8310 identificat")));
  h.setVehicle(nullptr);
  QVERIFY(!h.parameterRefreshPending());
 }
 void priorityIndexedYawUseDoesNotFollowDiscoveryIndexAndRejectsDuplicateIds(){
  Vehicle v;NavoGnssHeading h;h.setVehicle(&v);h.setLinkAlive(true);
  auto* pm=v.parameterManager();h.requestDiagnosticParameters();
  const quint32 ist=(0x0Au<<16)|(0x0Eu<<8)|(1u<<3)|1u;
  // Detection slot 2 is independent of compass *priority* order.
  pm->setFact(QStringLiteral("COMPASS_DEV_ID"),0);
  pm->setFact(QStringLiteral("COMPASS_DEV_ID2"),ist);
  pm->setFact(QStringLiteral("COMPASS_USE"),0);
  pm->setFact(QStringLiteral("COMPASS_USE2"),1);
  pm->setFact(QStringLiteral("COMPASS_PRIO1_ID"),ist);
  pm->setFact(QStringLiteral("COMPASS_PRIO2_ID"),ist);
  pm->setFact(QStringLiteral("EK3_SRC1_YAW"),0);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(h.compassIdentity().contains(QStringLiteral("COMPASS_DEV_ID2")));
  QVERIFY(h.compassUseStatus().contains(QStringLiteral("Prioritate 1: dezactivat")));
  QVERIFY(h.compassUseStatus().contains(QStringLiteral("Prioritate 2: activ")));
  QVERIFY(h.compassPriorityStatus().contains(QStringLiteral("DUPLICAT cu prioritatea 1")));
  QVERIFY(h.compassStatus().contains(QStringLiteral("EK3_SRC1_YAW=0")));
  QVERIFY(!h.compassFallbackActive());
  pm->setFact(QStringLiteral("EK3_SRC1_YAW"),3);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(h.compassStatus().contains(QStringLiteral("ID DUPLICAT")));
  h.setAutopilotHeadingDeg(133);
  gps(v,20000);gps(v,65535);mag(v,true,true);
  event(v,"EKF3 IMU0 yaw fallback active");
  QVERIFY(!h.compassFallbackActive()); // duplicate priorities fail closed
  // Remove duplicate priority. Priority 1 points to detected slot 2,
  // but USE (priority 1) remains 0 -> no magnetic fallback.
  pm->setFact(QStringLiteral("COMPASS_PRIO2_ID"),0);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(!h.compassFallbackActive());
  pm->setFact(QStringLiteral("COMPASS_USE"),1);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(h.compassFallbackActive());
  QCOMPARE(h.selectedHeadingDeg(),133.0);
  pm->setFact(QStringLiteral("COMPASS_USE"),0);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(!h.compassFallbackActive());
  // Alternative valid second priority, even though DEV_ID2 matched
  // both cases. USE2 applies to priority 2, not discovery slot 2.
  pm->setFact(QStringLiteral("COMPASS_PRIO1_ID"),0);
  pm->setFact(QStringLiteral("COMPASS_PRIO2_ID"),ist);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(h.compassFallbackActive());
  pm->setFact(QStringLiteral("COMPASS_USE2"),0);
  QVERIFY(QMetaObject::invokeMethod(&h,"_refresh",Qt::DirectConnection));
  QVERIFY(!h.compassFallbackActive());
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
