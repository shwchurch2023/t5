import { Command, Option } from '@commander-js/extra-typings';
import { readFileSync, writeFileSync } from "fs";
import { walk } from './utils';
const program = new Command();


async function replaceUrlCommander() {

    const cmd = `replaceUrlWithRootPath`;
    program
        .command(cmd)
        .usage(`npx ts-node typescript/commander.ts replaceUrlWithRootPath --path $BASE_PATH_COMMON/content`)
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
                    console.log(filePath);
                    let content = readFileSync(filePath).toString();

                    const pattList = [
                        /http(s)?:\/\/.+?\.shwchurch.org\//gi
                    ];

                    pattList.forEach(
                        pattern => {
                            console.log(`Replace pattern ${pattern} with / in ${filePath}`);
                            content = content.replace(pattern, `/`);
                        }
                    );

                    writeFileSync(
                        `${filePath}`,
                        content
                    )

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