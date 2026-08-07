import asyncio
import gi
gi.require_version('Geoclue', '2.0')
from gi.repository import Geoclue


def obtain_cordinates():
    try:
        clue = Geoclue.Simple.new_sync("weather",Geoclue.AccuracyLevel.NEIGHBORHOOD, None)
        location = clue.get_location()
        return {
            "latitud": location.get_property("latitude"),
            "longitud": location.get_property("longitude"),
            "precision": location.get_property("accuracy")
        }
    except Exception as e:
        raise e

print(obtain_cordinates())

