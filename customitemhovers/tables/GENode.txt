const fs = require('fs');
const axios = require('axios');

// Manual crafting relationships: input → product
const productMap = {
  "Fire orb": "Fire battlestaff",
  "Water orb": "Water battlestaff",
  "Earth orb": "Earth battlestaff",
  "Air orb": "Air battlestaff",
  "Unpowered orb": "Air orb",
  "Molten glass": "Unpowered orb",
  "Green dragon leather": "Green d'hide body",
  "Gold bar": "Sapphire ring",
  "Soft clay": "Pie dish",
  "Snakeskin": "Snakeskin chaps",
  "Cured yak-hide": "Yak-hide armour (legs)",
  "Blamish red shell (round)": "Blood'n'tar snelm",
  "Mixed hide base": "Mixed hide top",
  "Bark": "Splitbark body",
  "Amethyst": "Amethyst arrowtips",
  "Logs": "Bird house"
};

async function updateAllPrices() {
  try {
    const dumpRes = await axios.get('https://chisel.weirdgloop.org/gazproj/gazbot/os_dump.json');
    const dump = dumpRes.data;
    const updatedItems = {};

    // First pass: store literal item names with gp
    for (const itemId in dump) {
      const item = dump[itemId];
      const itemName = item.name;
      const itemPrice = item.price;
      if (typeof itemPrice !== 'number') continue;
      updatedItems[itemName] = { gp: itemPrice };
    }

    // Second pass: apply lowercase underscore keys for product references
    for (const inputName in productMap) {
      const productName = productMap[inputName];
      const inputEntry = Object.values(dump).find(i => i.name === inputName);
      const productEntry = Object.values(dump).find(i => i.name === productName);

      if (!inputEntry || !productEntry) continue;
      const inputPrice = inputEntry.price;
      const productPrice = productEntry.price;
      if (typeof inputPrice !== 'number' || typeof productPrice !== 'number') continue;

      const inputKey = inputName.replace(/ /g, '_').toLowerCase();     // fire_orb
      const productKey = productName.replace(/ /g, '_').toLowerCase(); // fire_battlestaff

      // Add product to input's object
      updatedItems[inputName][productKey] = productPrice;

      // Add input to product's object
      if (!updatedItems[productName]) updatedItems[productName] = { gp: productPrice };
      updatedItems[productName][inputKey] = inputPrice;
    }

    const finalJson = {
      name: "Grand Exchange Prices",
      is_table_file: "absolutely",
      items: updatedItems
    };

    fs.writeFileSync('./GrandExchangePrices.json', JSON.stringify(finalJson, null, 2));
    console.log(`✅ Mapping complete with lowercase keys: ${Object.keys(updatedItems).length} items updated.`);
  } catch (err) {
    console.error("⚠️ Error during price update:", err.message);
  }
}

updateAllPrices();