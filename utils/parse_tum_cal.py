import requests
from icalendar import Calendar

ICAL_URL = "https://campus.tum.de/tumonlinej/ws/termin/ical?pStud=1478C72FF8586E34&pToken=DD742CF65EAB3B617EAD45A9A14067677EDF91C78F53CDBEC0D84B4F1D813CB9"  # or cal.tum.app URL

resp = requests.get(ICAL_URL)
resp.raise_for_status()

cal = Calendar.from_ical(resp.text)

lectures = []
for component in cal.walk():
    if component.name != "VEVENT":
        continue

    summary = str(component.get("SUMMARY"))
    dtstart = component.get("DTSTART").dt
    dtend = component.get("DTEND").dt
    location = str(component.get("LOCATION", ""))
    print(component)

    # Heuristic: treat events that look like lectures
    # (you can adjust this to your program)
    if "Praktikum" in summary or "Übung" in summary or "Vorlesung" in summary:
        lectures.append({
            "title": summary,
            "start": dtstart,
            "end": dtend,
            "location": location,
        })

print(lectures)
for lecture in lectures:
    print(lecture)

