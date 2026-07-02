const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    // Register @sa11y/jest matchers (toBeAccessible) for LWC DOM a11y assertions.
    setupFilesAfterEnv: [
        ...(jestConfig.setupFilesAfterEnv || []),
        '<rootDir>/jest.setup.a11y.js'
    ],
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
