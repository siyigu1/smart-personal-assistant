# Travel Packing Plugin

## What This Plugin Does

Helps the user plan packing for trips. Maintains a master packing template that scales by trip length, weather, and travel party. Generates trip-specific packing lists and sends pre-travel reminders.

## Installation

When this plugin is installed, add the following to the user's `Preferences.md` under "Installed Plugins":

```
- travel: Trip packing and travel planning. Triggers: "add trip [details]", "what do I need to pack", "generate packing list", "show my trips", "what do I need for [trip]", "going on a trip". → Follow travel plugin playbook. Data: plugins/travel/my_packing_template.md, plugins/travel/my_trips.md
```

## Master Template

The assistant maintains a `my_packing_template.md` with the user's personalized packing items. The template is organized by category with baseline quantities for a 3-day trip.

### Default Categories

**Documents & Essentials:** passports, wallet, insurance cards, medication
**Electronics:** phone, laptop, power bank, charging cables, chargers
**Clothing — Adult:** tops, bottoms, underwear, socks, sleepwear (scale by trip length)
**Clothing — Child:** same categories, extra items for kids
**Toiletries:** toothpaste, toothbrush, skincare, sunscreen
**Food & Drinks:** water, snacks, special dietary items
**Pet:** if applicable — food, bowls, leash, medication

### Scaling Rules

**Clothing quantity = baseline + ceil((trip_days - 3) / 2)**
- 3-day trip: baseline
- 5-day: +1 each
- 7-day: +2 each
- 10-day: +4 each
- 20-day: +9 each (note: plan laundry at destination)

**For trips > 10 days:** reduce clothing by ~30%, note "do laundry at destination"

**Weather adjustments:**
- Hot/beach: add swimwear, sunscreen, sun hats, sandals. Remove cold items.
- Cold/snow: add warm layers, boots, gloves. Remove summer items.
- International: add power adapter, check visa requirements.

**Travel method:**
- Flying: note weight limits, flag items that can't fly (large liquids, fruit)
- Driving: more flexible on quantity

**Companion adjustments:**
- Remove sections for people not going
- Add sections for pets if applicable

## How the Assistant Should Behave

### Adding Trips
When user says "Add trip [details]" or describes upcoming travel:
→ Add to the trips section in `my_trips.md`
→ Ask for: dates, destination, travelers, route, weather

### Generating Packing Lists
When user says "Generate packing list for [trip]" or "What do I need for [trip]?":
→ Read the master template
→ Scale quantities by trip length
→ Adjust for weather, travel method, companions
→ Generate a trip-specific checklist in `my_trips.md` under that trip

### Pre-Travel Reminders
The assistant should proactively set up reminders (via add_automations):
- **14 days before:** Generate packing list, check passports, book remaining travel
- **7 days before:** Buy missing items, arrange pet care, check flight status
- **3 days before:** Start laying out items, charge electronics, check weather
- **1 day before:** Final packing, pack perishables, confirm arrangements
- **Day of:** Last-minute items, final walkthrough

### Managing the Template
When user says "Add [item] to packing template":
→ Add to the appropriate category in `my_packing_template.md`
→ Ask which category if unclear

## User Data Files

Create and maintain:
- `my_packing_template.md` — the user's personalized master template (created during first use)
- `my_trips.md` — upcoming trips and their trip-specific packing lists

The template starts empty and gets built as the user uses it. On first use, ask the user about their typical travel items to seed the template.
