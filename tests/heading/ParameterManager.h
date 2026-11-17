#pragma once
#include <QObject>
#include <QHash>
#include <QString>
#include <QStringList>
#include <QVariant>
#include "Fact.h"
// The production manager exposes refreshParameter/getParameter/parameterExists;
// the test verifies that refresh requests are read-only and targeted.
class ParameterManager:public QObject {
public:
 explicit ParameterManager(QObject* parent=nullptr):QObject(parent){}
 void refreshParameter(int componentId,const QString& name) {
  if(componentId==1)requested<<name;
 }
 bool parameterExists(int componentId,const QString& name)const {
  return componentId==1 && facts.contains(name);
 }
 Fact* getParameter(int componentId,const QString& name){
  return componentId==1 ? facts.value(name,nullptr) : nullptr;
 }
 void setFact(const QString& name,const QVariant& v){
  Fact* f=facts.value(name,nullptr);
  if(!f){f=new Fact(this);facts.insert(name,f);}
  f->setRawValue(v);
 }
 QStringList requested;
private:
 QHash<QString,Fact*> facts;
};
