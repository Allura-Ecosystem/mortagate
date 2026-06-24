const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    // Only discover MVP component tests under force-app. The repo also holds
    // git worktrees (.claude/worktrees, .worktrees) and an unrelated
    // vibefore-audit tree whose stray suites otherwise turn `npm run test:unit`
    // red even when the MVP is green.
    roots: ['<rootDir>/force-app'],
    modulePathIgnorePatterns: [
        '<rootDir>/.localdevserver',
        '<rootDir>/.claude',
        '<rootDir>/.worktrees',
        '<rootDir>/vibefore-audit'
    ]
};
