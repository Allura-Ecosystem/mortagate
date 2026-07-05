// Registers @sa11y/jest so any LWC test can assert:  await expect(el).toBeAccessible();
// Catches DOM-level a11y defects (roles, labels, tab order). Color-contrast of
// CSS-variable tokens is enforced separately by scripts/check-brand-tokens.mjs,
// because jsdom does not resolve computed colors from static-resource CSS vars.
const { setup } = require('@sa11y/jest');
setup();
