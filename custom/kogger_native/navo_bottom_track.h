#pragma once
#include <QObject>
#include <QHash>
#include <QReadWriteLock>
#include <QVector3D>
#include <QVector>
// Native point provider for the original SurfaceProcessor. Points are generated
// only from located Dataset epochs with processed depth, never from UI pixels.
class BottomTrack : public QObject {
public:
    QVector<QVector3D> data() const { QReadLocker guard(&mutex_); return points_; }
    int put(int epoch, const QVector3D& point) {
        QWriteLocker guard(&mutex_);
        if(indices_.contains(epoch)){int index=indices_[epoch];points_[index]=point;return index;}
        const int index=points_.size();indices_.insert(epoch,index);points_.append(point);return index;
    }
    void clear(){QWriteLocker guard(&mutex_);points_.clear();indices_.clear();}
private:
    mutable QReadWriteLock mutex_;
    QVector<QVector3D> points_;
    QHash<int,int> indices_;
};

Q_DECLARE_METATYPE(BottomTrack*)
