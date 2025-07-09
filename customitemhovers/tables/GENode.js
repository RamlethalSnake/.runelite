const fs = require('fs');
const axios = require('axios');

async function updateAllPrices() {
  const mappingRes = await axios.get('https://prices.runescape.wiki/api/v1/osrs/mapping');
  const latestRes = await axios.get('https://prices.runescape.wiki/api/v1/osrs/latest');

  const mapping = mappingRes.data;
  const latest = latestRes.data.data;

  const updatedItems = {};

  for (const entry of mapping) {
    const itemId = entry.id;
    const itemName = entry.name;

    if (latest[itemId] && typeof latest[itemId].low === 'number') {
      updatedItems[itemName] = { gp: latest[itemId].low };
    }
  }

  const finalJson = {
    name: "Grand Exchange Prices",
    is_table_file: "absolutely",
    items: updatedItems
  };

  fs.writeFileSync('./GrandExchangePrices.json', JSON.stringify(finalJson, null, 2));
  console.log(`✅ Updated ${Object.keys(updatedItems).length} items from the Grand Exchange.`);
}

updateAllPrices();