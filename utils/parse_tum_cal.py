import requests
from icalendar import Calendar
from datetime import datetime, timedelta, date

ICAL_URL = "https://campus.tum.de/tumonlinej/ws/termin/ical?pStud=1478C72FF8586E34&pToken=DD742CF65EAB3B617EAD45A9A14067677EDF91C78F53CDBEC0D84B4F1D813CB9"

resp = requests.get(ICAL_URL)
resp.raise_for_status()

cal = Calendar.from_ical(resp.text)

# ----- DATE FILTER SETUP -----
today = date.today()
tomorrow = today + timedelta(days=1)
valid_days = {today, tomorrow}


def extract_event_info(event):
    """Extracts lecture name, date, start/end time from a VEVENT."""
    summary = str(event.get("SUMMARY", "")).encode("latin1").decode("utf8", errors="ignore")

    dtstart = event.get("DTSTART").dt
    dtend = event.get("DTEND").dt

    # Clean summary (remove escaped commas, double spaces)
    summary = summary.replace("\\,", ",").replace("  ", " ").strip()

    return {
        "lecture": summary,
        "date": dtstart.strftime("%Y-%m-%d"),
        "start": dtstart.strftime("%H:%M"),
        "end": dtend.strftime("%H:%M"),
    }


def parse_today_and_tomorrow(events):
    parsed = []
    for ev in events:
        if ev.name != "VEVENT":
            continue

        dtstart = ev.get("DTSTART").dt
        event_day = dtstart.date()

        # Only include today and tomorrow
        if event_day not in valid_days:
            continue

        parsed.append(extract_event_info(ev))

    # Sort by datetime
    parsed.sort(key=lambda e: (e["date"], e["start"]))

    return parsed


events = parse_today_and_tomorrow(cal.walk())
print(events)

