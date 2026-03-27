# Grocery List

> **How this works:** Tell your agent to add items ("add milk to grocery list", "need soy sauce", "we're running low on X"). The agent categorizes automatically and adds here. Say "show grocery list" to see the current list, or "planning a costco trip" to get a filtered list. After a grocery run, say "done with costco trip" or "remove milk" to clear items.

---

{{GROCERY_SECTIONS}}

---

## Category Rules (for the agent)

When an item is added, categorize using these rules:

{{GROCERY_RULES}}

**Override rule:** If a specific store is mentioned ("get X from Wegmans"), put it in Store-Specific Requests regardless of category.

**Multi-store items:** Some items can be bought at multiple stores (e.g., eggs at normal grocery OR specialty grocery). When listing for a specific trip, include these items with a note: "[also available at X]"
