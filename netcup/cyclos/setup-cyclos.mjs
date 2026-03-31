// Cyclos Initial Setup via Playwright
// GWT selectionField: click icon → popup with search input → type filter → click item
import { chromium } from 'playwright';

const CYCLOS_URL = process.env.CYCLOS_URL || 'http://cyclos:8080';
const LICENSE_USER = process.env.LICENSE_USER || 'jeffemmett';
const LICENSE_PASS = process.env.LICENSE_PASS || '';
const NEW_ADMIN_PASS = process.env.CYCLOS_ADMIN_PASS || 'HCC-Admin-2026!';
const APP_NAME = 'HCC Timebank';

const SHOT_DIR = process.env.SHOT_DIR || '/tmp';
let shotIdx = 0;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const shot = async (page, label) => {
  const path = `${SHOT_DIR}/cyclos-${String(++shotIdx).padStart(2,'0')}-${label}.png`;
  await page.screenshot({ path, fullPage: true });
  console.log(`  [shot] ${path}`);
};

function rowInputRect(label, sel = 'input') {
  return `(() => {
    for (const row of document.querySelectorAll('tr')) {
      const td = row.querySelector('td:first-child');
      if (td && td.textContent.trim().includes('${label}')) {
        const el = row.querySelector('${sel}');
        if (el && el.offsetParent !== null && el.getBoundingClientRect().width > 20) {
          const r = el.getBoundingClientRect();
          return { x: r.x, y: r.y, w: r.width, h: r.height };
        }
      }
    }
    return null;
  })()`;
}

async function fillInput(page, label, value) {
  const rect = await page.evaluate(rowInputRect(label));
  if (!rect) return false;
  await page.mouse.click(rect.x + rect.w / 2, rect.y + rect.h / 2);
  await sleep(200);
  await page.keyboard.press('Control+a');
  await page.keyboard.type(value, { delay: 20 });
  await page.keyboard.press('Tab');
  await sleep(300);
  return true;
}

// Select from GWT selectionField popup by clicking icon, searching, clicking item
async function selectOption(page, rowLabel, searchText, matchText) {
  console.log(`  Selecting "${matchText}" from "${rowLabel}"...`);

  // 1. Click dropdown icon
  const iconRect = await page.evaluate((label) => {
    for (const row of document.querySelectorAll('tr')) {
      const td = row.querySelector('td:first-child');
      if (!td || !td.textContent.trim().includes(label)) continue;
      const icon = row.querySelector('.icon');
      if (icon) { const r = icon.getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; }
    }
    return null;
  }, rowLabel);
  if (!iconRect) { console.log('    No dropdown icon'); return false; }

  await page.mouse.click(iconRect.x + iconRect.w / 2, iconRect.y + iconRect.h / 2);
  await sleep(1000);

  // 2. Find search input in popup and type
  const searchRect = await page.evaluate(() => {
    const popup = document.querySelector('.optionsPopup, [class*="optionsPopup"]');
    if (!popup) return null;
    const input = popup.querySelector('input');
    if (!input) return null;
    const r = input.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height };
  });

  if (!searchRect) { console.log('    No search input in popup'); return false; }

  await page.mouse.click(searchRect.x + searchRect.w / 2, searchRect.y + searchRect.h / 2);
  await sleep(200);
  await page.keyboard.type(searchText, { delay: 50 });
  await sleep(1500);

  await shot(page, `sel-${rowLabel.replace(/\s/g, '')}`);

  // 3. Dump popup state for debugging
  const popupState = await page.evaluate((match) => {
    const popup = document.querySelector('.optionsPopup, [class*="optionsPopup"]');
    if (!popup) return { error: 'no popup' };

    // Get all visible text-bearing elements in popup
    const items = [];
    const walk = document.createTreeWalker(popup, NodeFilter.SHOW_ELEMENT);
    while (walk.nextNode()) {
      const el = walk.currentNode;
      const r = el.getBoundingClientRect();
      if (r.width < 20 || r.height < 10 || r.height > 50) continue;
      // Check for leaf elements (no child elements with same text)
      const text = el.textContent?.trim();
      if (!text || text.length > 80) continue;
      // Check if this is a clickable option item
      const isOption = el.classList.contains('option') || el.classList.contains('optionRow') ||
                       el.closest('[class*="option"]') || el.tagName === 'TD';
      items.push({
        text: text.substring(0, 60), tag: el.tagName,
        cls: el.className?.substring(0, 40),
        w: Math.round(r.width), h: Math.round(r.height),
        matchesSearch: text.includes(match),
        isLeaf: el.children.length === 0 || el.tagName === 'TD'
      });
    }
    // Only show items that look like options (not containers)
    const optionLike = items.filter(i => i.isLeaf && i.h > 15 && i.h < 40);
    return { total: items.length, options: optionLike.slice(0, 15) };
  }, matchText);

  console.log(`    Popup items: ${popupState.total}, options:`, JSON.stringify(popupState.options?.map(o => o.text)));

  // 4. Click the matching item
  const clicked = await page.evaluate((match) => {
    const popup = document.querySelector('.optionsPopup, [class*="optionsPopup"]');
    if (!popup) return null;

    // Try clicking any element whose text matches
    const walk = document.createTreeWalker(popup, NodeFilter.SHOW_ELEMENT);
    while (walk.nextNode()) {
      const el = walk.currentNode;
      const text = el.textContent?.trim();
      if (!text || !text.includes(match)) continue;
      const r = el.getBoundingClientRect();
      if (r.width < 20 || r.height < 10 || r.height > 50) continue;
      // Prefer leaf nodes
      if (el.children.length === 0 || el.querySelector('[class*="option"]') === null) {
        el.click();
        return { clicked: text.substring(0, 60), tag: el.tagName };
      }
    }

    // Fallback: click any visible option-like element
    const allDivs = popup.querySelectorAll('div[class*="option"], td');
    for (const div of allDivs) {
      const text = div.textContent?.trim();
      if (text && text.includes(match)) {
        div.click();
        return { clicked: text.substring(0, 60), tag: div.tagName, fallback: true };
      }
    }
    return null;
  }, matchText);

  if (clicked) {
    console.log(`    Clicked: ${JSON.stringify(clicked)}`);
    await sleep(500);
  } else {
    console.log('    No match found, pressing Escape');
    await page.keyboard.press('Escape');
    await sleep(300);
    return false;
  }

  // Verify
  const display = await page.evaluate((label) => {
    for (const row of document.querySelectorAll('tr')) {
      const td = row.querySelector('td:first-child');
      if (td && td.textContent.trim().includes(label)) {
        return row.querySelector('.selectionLabel')?.textContent?.trim();
      }
    }
    return null;
  }, rowLabel);
  console.log(`    Display: "${display}"`);
  return display && display !== 'Please, select an option';
}

(async () => {
  if (!LICENSE_PASS) { console.error('LICENSE_PASS required'); process.exit(1); }
  console.log(`Targeting ${CYCLOS_URL}...`);
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
  page.on('console', msg => { if (msg.type() === 'error') console.log('PAGE_ERR:', msg.text()); });

  try {
    // ─── Step 1/3: License ───
    console.log('\n=== STEP 1/3: License ===');
    await page.goto(`${CYCLOS_URL}/global/`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await sleep(5000);
    const t1 = await page.evaluate(() => document.body?.innerText || '');
    if (t1.includes('license server authentication')) {
      await fillInput(page, 'Login name', LICENSE_USER);
      const pr = await page.evaluate(rowInputRect('Password', 'input[type="password"]'));
      if (pr) { await page.mouse.click(pr.x + pr.w / 2, pr.y + pr.h / 2); await sleep(100); await page.keyboard.type(LICENSE_PASS, { delay: 20 }); }
      await page.evaluate(() => [...document.querySelectorAll('button')].find(b => b.textContent?.trim() === 'Next')?.click());
      console.log('  Submitted, validating...');
      await sleep(15000);
      await shot(page, 'after-license');
    }

    // ─── Step 2/3: Basic Config ───
    console.log('\n=== STEP 2/3: Basic Config ===');
    const t2 = await page.evaluate(() => document.body?.innerText || '');
    if (t2.includes('Basic configuration') || t2.includes('Step 2')) {
      await fillInput(page, 'Application name', APP_NAME);
      console.log('  App name: done');

      // First change country to Canada (so Toronto timezone is available)
      const countryOk = await selectOption(page, 'Country', 'Canada', 'Canada');
      console.log(`  Country: ${countryOk ? 'OK' : 'FAILED'}`);

      // Wait for timezone list to refresh after country change
      await sleep(2000);

      // Then select timezone
      const tzOk = await selectOption(page, 'Time zone', 'Toronto', 'America/Toronto');
      if (!tzOk) {
        // Fallback: try New_York (Eastern US)
        console.log('  Retrying with America/New_York...');
        const tzOk2 = await selectOption(page, 'Time zone', 'New_York', 'America/New_York');
        console.log(`  TZ (New_York): ${tzOk2 ? 'OK' : 'FAILED'}`);
      } else {
        console.log('  Time zone: OK');
      }

      await shot(page, 'step2-done');

      // Verify all
      const vals = await page.evaluate(() => {
        const r = {};
        for (const row of document.querySelectorAll('tr')) {
          const label = row.querySelector('td:first-child')?.textContent?.trim()?.replace(/\*/g, '').trim();
          const sl = row.querySelector('.selectionLabel');
          const input = row.querySelector('input.inputField');
          if (label) r[label] = sl?.textContent?.trim() || input?.value || '';
        }
        return r;
      });
      console.log('  Values:', JSON.stringify(vals));

      // Click Next
      await page.evaluate(() => [...document.querySelectorAll('button')].find(b => b.textContent?.trim() === 'Next')?.click());
      console.log('  Clicked Next');
      await sleep(8000);

      const after2 = await page.evaluate(() => document.body?.innerText?.substring(0, 300) || '');
      if (after2.includes('validation errors')) {
        console.log('  FAILED:', after2.substring(0, 200));
        await shot(page, 'step2-fail');
      } else {
        console.log('  STEP 2 PASSED!');
        await shot(page, 'step2-ok');
      }
    }

    // ─── Step 3/3: System Administrator ───
    console.log('\n=== STEP 3/3: System Administrator ===');
    const t3 = await page.evaluate(() => document.body?.innerText || '');
    if (t3.includes('Step 3') || t3.includes('System administrator')) {
      await shot(page, 'step3');

      // Fill Name
      await fillInput(page, 'Name', 'HCC Admin');
      console.log('  Name: done');

      // Fill Login name
      await fillInput(page, 'Login name', 'admin');
      console.log('  Login name: done');

      // Fill E-Mail
      await fillInput(page, 'E-Mail', 'admin@timebank.rspace.online');
      console.log('  Email: done');

      // Fill Password and Confirm password — use index-based since labels overlap
      const pwdRects = await page.evaluate(() => {
        return [...document.querySelectorAll('input[type="password"]')]
          .filter(el => el.offsetParent !== null && el.getBoundingClientRect().width > 20)
          .map(el => { const r = el.getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
      });
      console.log(`  Found ${pwdRects.length} visible password fields`);
      for (let i = 0; i < pwdRects.length; i++) {
        await page.mouse.click(pwdRects[i].x + pwdRects[i].w / 2, pwdRects[i].y + pwdRects[i].h / 2);
        await sleep(100);
        await page.keyboard.type(NEW_ADMIN_PASS, { delay: 15 });
        await page.keyboard.press('Tab');
        await sleep(200);
        console.log(`  Password field ${i + 1}: done`);
      }

      await shot(page, 'step3-filled');

      // Click Finish
      await page.evaluate(() => {
        for (const t of ['Finish', 'Save', 'Next']) {
          const b = [...document.querySelectorAll('button')].find(b => b.offsetParent && b.textContent?.trim().includes(t));
          if (b) { b.click(); return; }
        }
      });
      console.log('  Clicked Finish');
      await sleep(15000); // Initial setup may take a while
      const after3 = await page.evaluate(() => document.body?.innerText?.substring(0, 300) || '');
      console.log('  After step 3:', after3.substring(0, 200));
      await shot(page, 'after-step3');
    }

    // ─── Handle post-setup states ───
    console.log('\n=== POST-SETUP ===');
    let post = await page.evaluate(() => document.body?.innerText?.substring(0, 500) || '');
    console.log('  Page:', post.substring(0, 200));

    // If we got bounced back to license auth, retry
    if (post.includes('Invalid license') || post.includes('license server authentication')) {
      console.log('  License re-validation needed, retrying Step 1...');
      // Close error dialog if present
      await page.evaluate(() => [...document.querySelectorAll('button')].find(b => b.textContent?.trim() === 'Close')?.click());
      await sleep(500);

      await fillInput(page, 'Login name', LICENSE_USER);
      const pr = await page.evaluate(rowInputRect('Password', 'input[type="password"]'));
      if (pr) { await page.mouse.click(pr.x + pr.w / 2, pr.y + pr.h / 2); await sleep(100); await page.keyboard.type(LICENSE_PASS, { delay: 20 }); }
      await page.evaluate(() => [...document.querySelectorAll('button')].find(b => b.textContent?.trim() === 'Next')?.click());
      console.log('  Re-submitted license credentials...');
      await sleep(15000);
      post = await page.evaluate(() => document.body?.innerText?.substring(0, 500) || '');
      console.log('  After retry:', post.substring(0, 200));
      await shot(page, 'license-retry');

      // If still on Step 2, fast-forward through it again
      if (post.includes('Basic configuration') || post.includes('Step 2')) {
        console.log('  Re-doing Step 2...');
        await fillInput(page, 'Application name', APP_NAME);
        await selectOption(page, 'Country', 'Canada', 'Canada');
        await sleep(1000);
        await selectOption(page, 'Time zone', 'Toronto', 'America/Toronto');
        await page.evaluate(() => [...document.querySelectorAll('button')].find(b => b.textContent?.trim() === 'Next')?.click());
        await sleep(8000);
        post = await page.evaluate(() => document.body?.innerText?.substring(0, 500) || '');
        console.log('  After Step 2 redo:', post.substring(0, 150));
      }

      // If on Step 3, re-do it
      if (post.includes('Step 3') || post.includes('System administrator')) {
        console.log('  Re-doing Step 3...');
        await fillInput(page, 'Name', 'HCC Admin');
        await fillInput(page, 'Login name', 'admin');
        await fillInput(page, 'E-Mail', 'admin@timebank.rspace.online');
        const pwdRects = await page.evaluate(() =>
          [...document.querySelectorAll('input[type="password"]')]
            .filter(el => el.offsetParent !== null && el.getBoundingClientRect().width > 20)
            .map(el => { const r = el.getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; })
        );
        for (const rect of pwdRects) {
          await page.mouse.click(rect.x + rect.w / 2, rect.y + rect.h / 2);
          await sleep(100); await page.keyboard.type(NEW_ADMIN_PASS, { delay: 15 });
          await page.keyboard.press('Tab'); await sleep(200);
        }
        await page.evaluate(() => [...document.querySelectorAll('button')].find(b => b.textContent?.trim().includes('Finish'))?.click());
        console.log('  Clicked Finish (retry)');
        await sleep(15000);
        post = await page.evaluate(() => document.body?.innerText?.substring(0, 500) || '');
        console.log('  After Step 3 retry:', post.substring(0, 200));
        await shot(page, 'step3-retry');
      }
    }

    // Login if we see a login form
    if (post.includes('Login name') && !post.includes('license')) {
      console.log('  Logging in as admin...');
      await fillInput(page, 'Login name', 'admin');
      const pr = await page.evaluate(rowInputRect('Password', 'input[type="password"]'));
      if (pr) { await page.mouse.click(pr.x + pr.w / 2, pr.y + pr.h / 2); await sleep(100); await page.keyboard.type(NEW_ADMIN_PASS, { delay: 20 }); }
      await page.keyboard.press('Enter');
      await sleep(8000);
      await shot(page, 'after-login');
    }

    const admin = await page.evaluate(() => document.body?.innerText?.substring(0, 200) || '');
    console.log('  Final state:', admin.substring(0, 150));
    if (admin.includes('Networks') || admin.includes('Dashboard') || admin.includes('Logout')) {
      console.log('\n  GLOBAL ADMIN REACHED!');
    }
    await shot(page, 'final');
    console.log('\n=== Done ===');

  } catch (err) {
    console.error('\nERROR:', err.message);
    await shot(page, 'error').catch(() => {});
  } finally {
    await browser.close();
  }
})();
