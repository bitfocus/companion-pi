const semver = require('semver');
const inquirer = require('inquirer');
const { execSync } = require("child_process");
const fs = require('fs');
const axios = require('axios')
const moment = require('moment')

const ALLOWED_VERSIONS = '^2.2.0'
// const ALLOWED_BRANCHES = ['beta']
const ALLOWED_BRANCHES = [] // 'beta' is disabled for now, as it is not compatible with companionpi

// TODO - replace this concept
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

async function getLatestBuildsForBranch(branch, targetCount) {
    targetCount *= 10 // HACK until the api changes
    const data = await axios.get(`https://api.bitfocus.io/v1/product/companion/packages?branch=${branch}&limit=${targetCount}`)

    // TODO - make sure this is durable
    let target = `${process.platform}-${process.arch}-tgz`
    if (target === 'linux-x64-tgz') target = 'linux-tgz'

    // console.log('searching for', target, 'in', data.data.packages)

    // assume the builds are sorted by date already
    const result = []
    for (const pkg of data.data.packages) {
        if (pkg.target === target) {
            result.push({
                name: pkg.version,
                uri: pkg.uri,
                published: new Date(pkg.published)
            })
        }
    }

    return result
}

async function runPrompt() {
    console.log('Warning: Downgrading to an older version can cause issues with the database not being compatible')

    let isOnBeta = true

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
            choices: [
                'latest stable',
                'latest beta',
                'specific stable',
                'specific beta',
                'custom-url',
                'cancel'
            ],
            default: (isOnBeta ? 'latest beta' : 'latest stable')
        }
    ])

    if (answer.ref === 'custom-url') {
        console.log('Warning: This must be an linux build of Companion for the correct architecture, or companion will not be able to launch afterwards')
        const answer = await inquirer.prompt([
            {
                type: 'input',
                name: 'url',
                message: 'What build url?'
            }
        ])
        

        const confirm = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirm',
                message: `Are you sure you to download the build "${answer.url}"?\nMake sure you trust the source.\nIf you don't know what you are doing you could break your CompanionPi installation`
            }
        ])
        if (!confirm.confirm) {
            return runPrompt()
        } else {
            fs.writeFileSync('/tmp/companion-version-selection', answer.url)
        }
    } else if (!answer.ref || answer.ref === 'cancel') {

        console.error('No version was selected!')
    } else if (answer.ref === 'latest beta') {
        const candidates = await getLatestBuildsForBranch('beta', 1)
        const latestBuild = candidates[0]
        if (latestBuild) {
            console.log(`Selected beta: ${latestBuild.name}`)
            fs.writeFileSync('/tmp/companion-version-selection', latestBuild.uri)
        } else {
            console.error('No beta build was found!')
        }
    } else if (answer.ref === 'latest stable') {
        const candidates = await getLatestBuildsForBranch('stable', 1)
        const latestBuild = candidates[0]
        if (latestBuild) {
            console.log(`Selected stable: ${latestBuild.name}`)
            fs.writeFileSync('/tmp/companion-version-selection', latestBuild.uri)
        } else {
            console.error('No beta build was found!')
        }
    } else if (answer.ref === 'specific beta') {
        const candidates = await getLatestBuildsForBranch('beta', 10)

        if (candidates.length === 0) {
            console.error('No beta build was found!')
        } else {

            const selectedBuild = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'ref',
                    message: 'Which version do you want? ',
                    choices: [
                        ...candidates.map(c => c.name),
                        'cancel'
                    ],
                }
            ])
        
            if (selectedBuild.ref && selectedBuild.ref !== 'cancel') {
                const build = candidates.find(c => c.name === selectedBuild.ref)
                if (build) {
                    console.log(`Selected beta: ${build.name}`)
                    fs.writeFileSync('/tmp/companion-version-selection', build.uri)
                } else {
                    console.error('Invalid selection!')
                }
            } else {
                console.error('No version was selected!')
            }
        }
    } else if (answer.ref === 'specific stable') {
        const candidates = await getLatestBuildsForBranch('stable', 10)

        if (candidates.length === 0) {
            console.error('No stable build was found!')
        } else {
            const selectedBuild = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'ref',
                    message: 'Which version do you want? ',
                    choices: [
                        ...candidates.map(c => c.name),
                        'cancel'
                    ],
                }
            ])
        
            if (selectedBuild.ref && selectedBuild.ref !== 'cancel') {
                const build = candidates.find(c => c.name === selectedBuild.ref)
                if (build) {
                    console.log(`Selected stable: ${build.name}`)
                    fs.writeFileSync('/tmp/companion-version-selection', build.uri)
                } else {
                    console.error('Invalid selection!')
                }
            } else {
                console.error('No version was selected!')
            }
        }
    }
}

runPrompt()
