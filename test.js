import 'dotenv/config';
import { handleMessage } from './main.js';

async function runTests() {
  console.log("=== Testing Supply ===");
  await handleMessage("I have a plot for sale in block A, 400gz, demand 1.5cr.", "03001234567");

  console.log("\n=== Testing Demand ===");
  await handleMessage("Looking for a plot in block A, around 400gz, budget is 1cr.", "03211234567");
}

runTests();
