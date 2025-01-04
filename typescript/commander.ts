import { Command, Option } from '@commander-js/extra-typings';
import { readFileSync, unlinkSync, writeFileSync } from "fs";
import { walk } from './utils';
const program = new Command();


async function replaceUrlCommander() {

    const cmd = `wpHugoExporterAfterAllProcessor`;

    const keyValueSplitter = `____`;
    program
        .command(cmd)
        .usage(`npx ts-node typescript/commander.ts wpHugoExporterAfterAllProcessor --path $(pwd)/content`)
        .usage(`npx ts-node typescript/commander.ts wpHugoExporterAfterAllProcessor --path $(pwd)/shwchurch7.github.io --file_ext=*.html --replace_def=https://shwchurch7.github.io/wp-content/uploads/2008${keyValueSplitter}https://shwchurch4.github.io/wp-content/uploads/2008`)
        .addOption(
            new Option(
                '--path <path>',
                'The path of the markdown files'
            )
                .makeOptionMandatory()
        ) 
        .addOption(
            new Option(
                '--file_ext <file_ext...>',
                'The file extension to filter'
            )
                .default(
                    [`.md`]
                )
        )
        .addOption(
            new Option(
                '--replace_def <replace_def...>',
                `e.g --replace_def=https://shwchurch7.github.io/wp-content/uploads/2008${keyValueSplitter}https://shwchurch4.github.io/wp-content/uploads/2008`
            )
        )
        .action(async (str, options) => {
            const p = options.getOptionValue('path');
            const file_ext = options.getOptionValue('file_ext');
            const replace_def = options.getOptionValue('replace_def');
            // Example usage:

            await walk({
                dir: p,
                callback: async (filePath) => {
                    // console.log(filePath);
                    let content = readFileSync(filePath).toString();

                    const pattList = replace_def
                        ? replace_def.map(def => {

                            const split = def.split(keyValueSplitter)

                            return {
                                pattern: new RegExp(split[0]),
                                replacement: split[1],
                            };
                        })
                        : [
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
                            content = replaceFunc ? (pattern.test(content) ? replaceFunc(content) : content) : content.replace(pattern, replacement);
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
                    return file_ext.some(ext => filePath.endsWith(ext))
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