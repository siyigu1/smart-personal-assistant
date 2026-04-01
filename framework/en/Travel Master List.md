# Travel Master List

> **How this works:** This is the master reference for multi-day trip packing. 14 days before a trip, the agent generates a trip-specific packing list from this template, adjusted for: trip length, destination weather, travel method (car/fly), who's going, and any special needs. The agent will also remind you about pre-travel tasks.

---

## Upcoming Trips

_(Add trips here. Format:)_

### Trip: [Destination]
- **Dates:** [start] - [end]
- **Travelers:** [who's going]
- **Route:** [drive/fly/train]
- **Weather:** [expected conditions]
- **Special notes:** [any special needs]

---

## Master Packing Template

> Baseline quantities are for a 3-day trip. Scale by trip length using the rules at the bottom.

### Documents & Essentials
| Item | Notes | Scale by trip length? |
|---|---|---|
| Passport(s) | All travelers | No |
| Wallet | | No |
| Insurance cards | | No |
| Medication | Any prescriptions | No |

### Electronics & Charging
| Item | Qty (baseline) | Notes |
|---|---|---|
| Phone | 1 | |
| Laptop | 1 | Optional |
| Power bank | 1-2 | |
| Charging cables | 2 | Long + short |
| Charger heads | 2 | |

### Clothing — Adult
| Item | Qty (3-day baseline) | Scale? |
|---|---|---|
| Tops | 2 | Yes (+1 per 2 days) |
| Bottoms | 2 | Yes (+1 per 2 days) |
| Underwear | 3 | Yes (+1 per 2 days) |
| Socks | 3 | Yes (+1 per 2 days) |
| Sleepwear | 1 | No |

### Clothing — Child
| Item | Qty (3-day baseline) | Scale? | Notes |
|---|---|---|---|
| Tops | 3 | Yes (+1 per 2 days) | Kids need extras |
| Bottoms | 2 | Yes (+1 per 2 days) | |
| Underwear | 3 | Yes (+1 per 2 days) | |
| Socks | 3 | Yes (+1 per 2 days) | |
| Sleepwear | 1 | No | |

### Toiletries
| Item | Qty | Notes |
|---|---|---|
| Toothpaste | 1 | |
| Toothbrushes | per person | |
| Dental floss | 1 | |
| Skincare (travel size) | 1 set | |
| Sunscreen | 1 | If warm weather |

### Food & Drinks (pack day-of)
| Item | Notes |
|---|---|
| Water bottles | For the road/flight |
| Snacks | |
| Any special dietary items | |

---

## Pre-Travel Checklist Template

> The agent generates this 14 days before a trip. Adjust based on trip specifics.

### 14 days before
- [ ] Generate trip-specific packing list
- [ ] Check passport expiration dates (all travelers)
- [ ] Book any remaining accommodations/flights
- [ ] Check destination weather forecast
- [ ] Identify items to buy vs. items we have

### 7 days before
- [ ] Buy any missing items from packing list
- [ ] Check flight/car status
- [ ] Start a load of laundry for travel clothes
- [ ] Refill any medications

### 3 days before
- [ ] Start laying out items in packing staging area
- [ ] Charge all electronics (power banks, tablets)
- [ ] Check weather forecast again, adjust clothing
- [ ] Print any boarding passes / confirmation emails

### 1 day before
- [ ] Final packing — check everything against list
- [ ] Pack food/drinks/snacks (perishables)
- [ ] Set out-of-office if needed
- [ ] Check all documents in one place

### Day of
- [ ] Last-minute fresh items (water, snacks)
- [ ] Final walkthrough of house
- [ ] Double-check documents, wallet, phone, keys

---

## Scaling Rules (for the agent)

**Clothing quantity = baseline + ceil((trip_days - 3) / 2)**
- 3-day trip: baseline quantities
- 5-day trip: +1 each
- 7-day trip: +2 each
- 10-day trip: +4 each
- 20-day trip: +9 each (consider laundry at destination)

**For trips > 10 days:** Note "plan to do laundry at destination" and reduce clothing by ~30%

**Weather adjustments:**
- Hot/beach: Add swimwear, sunscreen, sun hats, sandals. Remove cold-weather items.
- Cold/snow: Add warm layers, boots, gloves, hat. Remove summer items.
- International: Add power adapter. Check visa/document requirements.

**Travel method adjustments:**
- Flying: Note luggage weight limits. Flag items that can't fly (large liquids). Pack essentials in carry-on.
- Driving: More flexible on quantity. Can bring more bulky items.
