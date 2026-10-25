// Screenshots of the console against a running app with demo data (bin/rails db:seed).
// BASE_URL defaults to the Rails server on :3000 serving the built console.
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const BASE = process.env.BASE_URL ?? "http://localhost:3000";
const OUT = new URL("../../docs/screenshots/", import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();

async function as(person, { width = 1360, height = 900, scheme = "light" } = {}) {
  const page = await browser.newPage({ viewport: { width, height }, colorScheme: scheme, reducedMotion: "reduce" });
  await page.goto(`${BASE}/sign-in`);
  await page.getByRole("button", { name: new RegExp(person) }).click();
  await page.waitForLoadState("networkidle");
  return page;
}

async function shot(page, name, opts = {}) {
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${OUT}${name}.png`, fullPage: true, ...opts });
  console.log(`wrote ${name}.png`);
}

const signIn = await browser.newPage({ viewport: { width: 1360, height: 900 } });
await signIn.goto(`${BASE}/sign-in`);
await shot(signIn, "01-sign-in");

const theo = await as("Theo Brandt");
await theo.getByRole("heading", { level: 1 }).waitFor();
await shot(theo, "02-caseload");

for (const [name, file] of [["Anna Becker", "03-patient-red-flag"], ["Fatma Yilmaz", "04-held-draft"], ["Karl Weber", "05-set-aside"]]) {
  await theo.goto(`${BASE}/`);
  await theo.getByRole("link", { name: new RegExp(name) }).click();
  await theo.getByRole("heading", { name }).waitFor();
  await shot(theo, file);
}

const petra = await as("Petra Lindqvist");
await petra.getByRole("link", { name: /Jürgen Haas/ }).click();
await petra.getByRole("heading", { name: "Jürgen Haas" }).waitFor();
await shot(petra, "06-completed-programme");

const bea = await as("Bea Kowalski");
await bea.getByRole("heading", { name: "Billing" }).waitFor();
await shot(bea, "07-billing");

const ada = await as("Ada Nowak");
await ada.goto(`${BASE}/audit`);
await ada.getByRole("heading", { name: "Audit trail" }).waitFor();
await shot(ada, "08-audit-trail", { fullPage: false });

const phone = await as("Theo Brandt", { width: 390, height: 844 });
await shot(phone, "09-caseload-phone");
await phone.getByRole("link", { name: /Anna Becker/ }).click();
await phone.getByRole("heading", { name: "Anna Becker" }).waitFor();
await shot(phone, "10-patient-phone");

const dark = await as("Theo Brandt", { scheme: "dark" });
await dark.getByRole("link", { name: /Anna Becker/ }).click();
await dark.getByRole("heading", { name: "Anna Becker" }).waitFor();
await shot(dark, "11-patient-dark");

await browser.close();
