# Recycler: Progression Design Document (120-Minute Demo)

## 1. Selected Mechanics Catalog

| ID | Mechanic | Implementation & Role |
| :--- | :--- | :--- |
| **C1** | **Click Core** | Manual bag clicking with 3-stage visual degradation dropping Scrap, Junk, and rare Gold. |
| **C2** | **Tiered Generators** | 3 machines with distinct recipes, batch cycle timers, and progress bars. Purchased *only* with crafted resources. |
| **C3** | **Generator Inline Upgrades** | Generators have dedicated upgrade paths (Speed, Multiplier, Auto-In, Auto-Out) attached directly to their UI line. Purchased with **Money**. |
| **M1** | **Global Shop Drawer** | A slide-out shop dedicated to Bag upgrades (Click power, Gold chance) and the Auto-Collector Box. |
| **A2** | **Resource Gating** | Tiered unlocking: Raw Scrap → Clean Flakes → Poly-Pellets → Eco-Fabric. Refined materials can be sold for Money. |
| **A4** | **Auto-Collector Box** | A helper entity (initially a simple box sprite) that automatically sweeps the ground to pick up dropped items and deposit them into the inventory. |
| **A8** | **Achievements** | 5 milestones awarding *Golden Masterbatch Pellets* (+5% global cycle speed). |

---

## 2. Core Loops & UI Layout

### A. Persistent UI Panels (Always Visible)
* **Top Inventory Panel:** A horizontal bar spanning the top of the screen. Displays accumulated resources with icon and count (e.g., 🛢️ Scrap: 145 | ❄️ Flakes: 20 | ⚪ Pellets: 5 | 🧵 Fabric: 2). Large numbers use abbreviations (e.g., 1.5k).
* **Left Finance Panel:** A distinct, floating panel on the left edge displaying **only** current Money (e.g., 💵 $4,250). Money is earned by selling refined materials or finding dropped Gold.

### B. The Bag Cracking Loop (Center Screen)
* **Hit Counter:** Default requires 10 clicks to burst. Alpha visual feedback (1.0 → 0.65 → 0.30).
* **Burst Drop:** Spawns plastic, junk, and a chance for Gold. Drops scatter on the ground.
* **Collection:** 
  * *Early Game:* Player must manually click or hover over dropped items to collect them.
  * *Mid Game:* Player buys the "Collector Box" which automatically moves to drops and sweeps them into the top inventory panel.

### C. The Drawer System (Right Screen Edge)
Two toggleable tabs slide out from the right:
1. **Workshop Drawer (Generators):**
   * Purchased with resources (e.g., Scrap, Flakes). 
   * Each purchased generator occupies a single horizontal line: `[Machine Name] [Progress Bar] [Qty: 1x/5x/Max] [Run]`
   * **Inline Upgrades (Cost: Money):** 4 compact icons beneath the progress bar:
     * ⏱️ *Speed* (Reduces cycle time)
     * 📈 *Multiplier* (Increases output yield per batch)
     * 📥 *Auto-In* (Automates resource consumption)
     * 📤 *Auto-Out* (Automatically collects finished goods)
2. **Shop Drawer (Bag, Collection & Global):**
   * Uses **Money** exclusively. Contains upgrades for bag damage, gold drop chances, and Collector Box efficiency.

---

## 3. JSON Configuration

```json
{
  "ui": {
    "topPanel": { "visible": true, "content": ["plastic", "flakes", "pellets", "fabric"] },
    "leftPanel": { "visible": true, "content": ["money"] },
    "drawers": {
      "workshop": { "defaultState": "closed" },
      "shop": { "defaultState": "closed" }
    }
  },
  "resources": [
    { "id": "money", "name": "Money", "symbol": "$" },
    { "id": "gold", "name": "Gold", "sellValue": 100 },
    { "id": "plastic", "name": "Plastic", "sellValue": 1 },
    { "id": "flakes", "name": "Clean Flakes", "sellValue": 5 },
    { "id": "pellets", "name": "Poly-Pellets", "sellValue": 15 },
    { "id": "fabric", "name": "Eco-Fabric", "sellValue": 50 }
  ],
  "bag": {
    "tier": 1,
    "clicksToBurst": 10,
    "stages": [
      { "clicksRemainingMin": 7, "alpha": 1.0 },
      { "clicksRemainingMin": 3, "alpha": 0.65 },
      { "clicksRemainingMin": 1, "alpha": 0.3 }
    ],
    "drops": {
      "plastic": { "min": 4, "max": 7 },
      "junk": { "min": 1, "max": 3 },
      "gold": { "chance": 0.05, "min": 1, "max": 1 }
    }
  },
  "shop_upgrades": [
    {
      "id": "shop_u_bag_dmg",
      "name": "Heavy Duty Cutters",
      "cost": { "money": 50 },
      "effect": { "target": "bag", "clickDamage": 2 }
    },
    {
      "id": "shop_u_bag_gold",
      "name": "Lucky Seams",
      "cost": { "money": 200 },
      "effect": { "target": "bag", "goldDropChance": "+0.05" }
    },
    {
      "id": "shop_u_collector_base",
      "name": "Basic Collector Box",
      "cost": { "money": 150 },
      "effect": { "target": "collection", "autoCollectEnabled": true, "speed": 1.0 }
    },
    {
      "id": "shop_u_collector_speed",
      "name": "Box Motor Upgrade",
      "cost": { "money": 400 },
      "effect": { "target": "collection", "speedMult": 1.5 }
    }
  ],
  "generators": [
    {
      "id": "g1_sorter",
      "name": "Manual Sorting Table",
      "cost": { "plastic": 20 },
      "baseCycleTimeSec": 3.5,
      "recipePerBatch": { "plastic": 5 },
      "outputPerBatch": { "flakes": 2 },
      "upgrades": {
        "speed": { "cost": { "money": 100 }, "effectMult": 0.8 },
        "multiplier": { "cost": { "money": 250 }, "effectMult": 2.0 },
        "autoIn": { "cost": { "money": 500 }, "unlocked": false },
        "autoOut": { "cost": { "money": 500 }, "unlocked": false }
      }
    },
    {
      "id": "g2_pelletizer",
      "name": "Melt Pelletizer",
      "cost": { "flakes": 60, "plastic": 50 },
      "baseCycleTimeSec": 6.0,
      "recipePerBatch": { "flakes": 4, "plastic": 3 },
      "outputPerBatch": { "pellets": 2 },
      "upgrades": {
        "speed": { "cost": { "money": 300 }, "effectMult": 0.8 },
        "multiplier": { "cost": { "money": 600 }, "effectMult": 2.0 },
        "autoIn": { "cost": { "money": 1200 }, "unlocked": false },
        "autoOut": { "cost": { "money": 1200 }, "unlocked": false }
      }
    },
    {
      "id": "g3_loom",
      "name": "Weaving Loom",
      "cost": { "pellets": 100, "plastic": 120 },
      "baseCycleTimeSec": 10.0,
      "recipePerBatch": { "pellets": 5, "plastic": 6 },
      "outputPerBatch": { "fabric": 1 },
      "upgrades": {
        "speed": { "cost": { "money": 800 }, "effectMult": 0.8 },
        "multiplier": { "cost": { "money": 1500 }, "effectMult": 2.0 },
        "autoIn": { "cost": { "money": 3000 }, "unlocked": false },
        "autoOut": { "cost": { "money": 3000 }, "unlocked": false }
      }
    }
  ]
}