pragma Singleton
import QtQml
QtObject { function coordinate(lat,lon){return {latitude:lat,longitude:lon,isValid:isFinite(lat)&&isFinite(lon)}} }
