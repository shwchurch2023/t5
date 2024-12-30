
import { readdirSync, statSync } from "fs";
import { join } from "path";

export const walk = async (
    {
        dir, filter, callback
    }: {
        dir: string, 
        callback: (file: string) => Promise<any>;
        filter: (filePath: string) => boolean
    }
) =>  {
    const files = readdirSync(dir);

    for (let file of files) {
        const filePath = join(dir, file);
    
        const stats = statSync(filePath);

        if (stats.isDirectory()) {
            await walk({
                dir: filePath, 
                callback,
                filter
            }); // Recurse into directory
        } else if (stats.isFile()) {
            if (!filter(filePath)) {
                continue;
            }

            await callback(filePath); // Call the callback for each file
        }
    }


}