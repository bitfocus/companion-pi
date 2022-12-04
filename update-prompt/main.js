const semver = require('semver');
const inquirer = require('inquirer');
const { execSync } = require("child_process");
const fs = require('fs');

const ALLOWED_VERSIONS = '^2.2.0'
// const ALLOWED_BRANCHES = ['beta']
const ALLOWED_BRANCHES = [] // 'beta' is disabled for now, as it is not compatible with companionpi

const currentTag = execSync(`git name-rev --name-only --tags --no-undefined HEAD 2>/dev/null | sed -n 's/^\\([^^~]\\{1,\\}\\)\\(\\^0\\)\\{0,1\\}$/\\1/p'`).toString().trim()
const currentBranch = execSync(`git branch --show-current`).toString().trim()

const allTags = execSync(`git tag -l`).toString()

const allowedTags = []
for (const tag of allTags.split('\n')) {
    const tag2 = tag.trim()
    if (tag2) {
        try {
            if (semver.satisfies(tag2, ALLOWED_VERSIONS))
                allowedTags.push(tag2)
        } catch (e) {
            // Not a semver tag, so ignore
        }
    }
}
allowedTags.sort(semver.rcompare)

async function runPrompt() {
    console.log('Warning: Downgrading to an older version can cause issues with the database not being compatible')

    if (currentBranch) {
        console.log(`You are currently on branch: ${currentBranch}`)
    } else if (currentTag) {
        console.log(`You are currently on release: ${currentTag}`)
    } else {
        console.log('Unable to determine your current version')
    }

    const answer = await inquirer.prompt([
        {
            type: 'list',
            name: 'ref',
            message: 'What version do you want? ',
            choices: [...ALLOWED_BRANCHES, ...allowedTags, 'custom', 'cancel'],
            default: (currentTag ? allowedTags[0] : currentBranch) || undefined
        }
    ])

    if (answer.ref === 'custom') {
        const answer = await inquirer.prompt([
            {
                type: 'input',
                name: 'ref',
                message: 'What git ref?'
            }
        ])
        
        if (answer.ref === 'beta' || answer.ref === 'develop') {
            console.error(`It is not possible to use ${answer.ref} on CompanionPi currently. It is too experimental!`)
            process.exit(1)
        }

        const confirm = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirm',
                message: `Are you sure you to switch to "${answer.ref}"?\nIf you don't know what you are doing you could break your CompanionPi installation`
            }
        ])
        if (!confirm.confirm) {
            return runPrompt()
        } else {
            fs.writeFileSync('/tmp/companion-version-selection', answer.ref)
        }
    } else if (!answer.ref || answer.ref === 'cancel') {

        console.error('No version was selected!')
    } else {
        fs.writeFileSync('/tmp/companion-version-selection', answer.ref)
    }
}

runPrompt()
