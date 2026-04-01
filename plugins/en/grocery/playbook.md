# Grocery Plugin

## What This Plugin Does

Keeps track of the user's grocery shopping list, organized by store type. When the user mentions needing an item, the assistant categorizes it and adds it to the right store list. When the user plans a shopping trip, the assistant pulls up the relevant items.

## Installation

When this plugin is installed, add the following to the user's `Preferences.md` under "Installed Plugins":

```
- grocery: Grocery shopping list. Triggers: "add [item] to grocery list", "need [item]", "we're out of [item]", "买[item]", "show grocery list", "planning a [store] trip", "what should I buy", "going to costco/grocery/中国超市". → Follow grocery plugin playbook. Data: plugins/grocery/my_grocery.md
```

## Store Categories

Items are organized into these store types:

### Bulk Store (Costco / Sam's Club)
Bulk items, cleaning supplies, household goods, beverages in bulk.
- Cleaning: napkins, tissues, toilet paper, paper towels, laundry detergent, dish soap, trash bags
- Beverages (bulk): Coke, sparkling water, juice boxes
- Bulk food: granola bars, snacks (large packs), frozen items (bulk)
- Household: batteries, aluminum foil, plastic wrap, Ziploc bags

### Regular Grocery (Wegmans / local supermarket)
Fresh produce, dairy, meat, bread, everyday cooking staples.
- Dairy: milk, cheese, yogurt, butter, cream, eggs
- Produce: tomato, onion, spinach, lettuce, cucumber, bell pepper, garlic, ginger, banana, apple, berries
- Meat: chicken wings, chicken thighs, ground beef, steak, salmon, shrimp
- Bakery: croissant, bread, bagels
- Pantry: pasta, olive oil, flour, sugar, pancake mix, cereal

### Chinese/Asian Grocery (H Mart / 99 Ranch / etc.)
Asian-specific ingredients, sauces, specialty items.
- Sauces: soy sauce, oyster sauce, sesame oil, rice vinegar, doubanjiang, hoisin sauce
- Grains: rice, rice noodles, dried noodles, glutinous rice
- Proteins: ground pork, pork belly, fish balls, tofu, dumplings
- Specialty: Chinese snacks, tea, dried mushrooms, seaweed, red bean paste
- Produce: bok choy, Chinese eggplant, daikon, napa cabbage, chives

### Store-Specific Requests
Items the user specifically wants from a particular store (overrides default categorization).

## Multi-Store Items
Some items can be bought at multiple stores: eggs, green onion, garlic, ginger, tofu, ground pork, rice. When listing for a specific trip, include these with a note: "(also available at [other store])".

## How the Assistant Should Behave

### Adding Items
When the user says any of these:
- "Add [item] to grocery list"
- "Need [item]"
- "We're out of [item]"
- "买[item]" (Chinese)
- "加[item]到购物清单"

→ Categorize using the rules above and add to the correct section in `my_grocery.md`.
→ If the user specifies a store ("get X from Wegmans"), put it in Store-Specific.
→ Confirm: "Added [item] to [store] list."

### Viewing the List
- "Show grocery list" / "What's on my grocery list?" → Show all sections with items
- "Planning a costco trip" / "Going to [store]" → Show that store's items PLUS multi-store items that could be gotten there
- "What do I need?" → Show the full list

### Removing Items
- "Remove [item]" / "Got [item]" / "Done with [store] trip" → Remove items
- After a store trip, ask if they want to clear that store's list

## User Data File

Create and maintain: `my_grocery.md`

Format:
```markdown
# My Grocery List

## Bulk Store (Costco)
- [items]

## Regular Grocery
- [items]

## Chinese Grocery
- [items]

## Store-Specific
- [item] — from [store name]
```

When the list is empty for a section, show `_(empty)_`.
