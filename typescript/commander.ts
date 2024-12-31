import { Command, Option } from '@commander-js/extra-typings';
import { readFileSync, unlinkSync, writeFileSync } from "fs";
import { walk } from './utils';
const program = new Command();


async function replaceUrlCommander() {

    const cmd = `wpHugoExporterAfterAllProcessor`;
    program
        .command(cmd)
        .usage(`npx ts-node typescript/commander.ts wpHugoExporterAfterAllProcessor --path $(pwd)/content`)
        .addOption(
            new Option(
                '--path <path>', 
                'The path of the markdown files'
            )
            .makeOptionMandatory()
        )
        .action(async (str, options) => {
            const p = options.getOptionValue('path');
            // Example usage:

            await walk({
                dir: p,
                callback: async(filePath) => {
                    // console.log(filePath);
                    let content = readFileSync(filePath).toString();

                    const pattList = [
                        {
                            pattern: /http(s)?:\/\/.+?\.shwchurch.org\//gi,
                            replacement: `/`
                        },
                        {
                            pattern: /<\/wp-content.+?>/gi,
                            replacement: ``
                        },
                        {
                            pattern: /date: -00[0-9-]+T00:00:00\+00:00/,
                            replacement: `date: 2020-12-28T03:17:00+00:00`,
                            replaceFunc: (content: string) => {
                                return '';
                            },
                        },
                    ];

                    pattList.forEach(
                        ({ pattern, replacement, replaceFunc }) => {
                            // console.log(`Replace pattern ${pattern} with / in ${filePath}`);
                            content = replaceFunc ? (pattern.test(content) ? replaceFunc(content) : content ) : content.replace(pattern, replacement);
                        }
                    );

                    if (!content) {
                        unlinkSync(filePath);
                    } else {

                        writeFileSync(
                            `${filePath}`,
                            content
                        )
                    }


                },
                filter: (filePath) => {
                    return /\.md$/.test(filePath)
                }
            });

            console.log(`Done: ${cmd}`)
            process.exit();

        });



}

async function main() {

    await replaceUrlCommander();

    program.exitOverride();

    try {
        await program.parseAsync(process.argv);
    } catch (error) {
        console.error(error);
        process.exit(100);
    }

}

main();

setInterval(() => {
    console.log(`Keep process running in commander`)
}, 1000 * 60);