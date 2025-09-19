(() => {
    /**
     * How to use (paste this whole block, then call):
     *   // Download exactly one by name
     *   downloadMp3s({ name: "184_走进新的一天" });
     *
     *   // Download all until (but NOT including) this name
     *   downloadMp3s({ stopAt: "241_奇异恩典" });
     *
     *   // Download all (no stop)
     *   downloadMp3s();
     */

    const TABLE_SEL = "table.wp-list-table.widefat.fixed.striped.table-view-list.attachments";
    const ROW_SEL = "tbody#the-list > tr";

    const sleep = (ms) => new Promise(r => setTimeout(r, ms));

    // Try to turn row text into a nice name like "241_奇异恩典"
    function deriveNiceName(tr) {
        // 1) Prefer the big "Title/Name" cell (has two lines)
        const titleNameCell = tr.querySelector("td.title_name");
        if (titleNameCell) {
            // First line often like "2023新歌本_241_奇异恩典" or "184.走进新的一天_v2"
            const firstLine = (titleNameCell.innerText || "").split(/\r?\n/)[0].trim();

            // Try pattern "..._<digits>_<name>"
            let m = firstLine.match(/(\d{1,4})_(.+?)(?:_[Vv]?\d+)?$/);
            if (m) return `${m[1]}_${m[2]}`;

            // Try pattern "<digits>[._-]<name>"
            m = firstLine.match(/(^|\D)(\d{1,4})[.\-_]([^\s].*?)(?:_[Vv]?\d+)?$/);
            if (m) return `${m[2]}_${m[3]}`;
        }

        // 2) Fallback: parse the inline description like 《241_奇异恩典》
        const inlineBox = tr.querySelector("div[id^='inline_']");
        if (inlineBox) {
            const desc = (inlineBox.querySelector(".post_content")?.innerText || "").trim();
            const m = desc.match(/《\s*([0-9]{1,4}_[^》]+)\s*》/);
            if (m) return m[1];
        }

        // 3) Last resort: from the download link title "Download “2023新歌本_241_奇异恩典”"
        const dlTitle = tr.querySelector(".row-actions .download a")?.getAttribute("title") || "";
        {
            const m = dlTitle.match(/“([^”]+)”/);
            if (m) {
                const s = m[1];
                let mm = s.match(/(\d{1,4})_(.+)$/);
                if (mm) return `${mm[1]}_${mm[2]}`;
            }
        }

        // 4) Give up—use file basename without extension
        const fileUrl = tr.querySelector("td.file_url")?.textContent?.trim();
        if (fileUrl) {
            const base = decodeURIComponent(fileUrl.split("/").pop() || "");
            const stem = base.replace(/\.[a-z0-9]+$/i, "");
            return stem;
        }

        return null;
    }

    function getDownloadUrl(tr) {
        const a = tr.querySelector(".row-actions .download a");
        if (!a) return null;
        // Use the resolved href so &amp; becomes &
        return a.href;
    }

    async function fetchAndSave(url, filename, mime = "audio/mpeg") {
        const res = await fetch(url, { credentials: "same-origin" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const blob = await res.blob();

        // Force a .mp3 extension if missing
        let name = filename;
        if (!/\.(mp3|m4a|wav|flac|aac)$/i.test(name)) name += ".mp3";

        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = name; // Lets us set a nice filename with Unicode
        document.body.appendChild(a);
        a.click();
        URL.revokeObjectURL(a.href);
        a.remove();
    }

    async function downloadMp3s({ name = null, stopAt = null, delayMs = 750 } = {}) {
        const table = document.querySelector(TABLE_SEL);
        if (!table) {
            console.warn("Table not found:", TABLE_SEL);
            return;
        }

        const rows = Array.from(table.querySelectorAll(ROW_SEL));
        let count = 0;

        for (const tr of rows) {
            const nice = deriveNiceName(tr);
            if (!nice) {
                console.debug("Skip row (no name derived):", tr.id);
                continue;
            }

            // If stopAt is provided, stop BEFORE that row
            if (stopAt && nice === stopAt) {
                console.log(`Reached stopAt "${stopAt}". Stopping.`);
                break;
            }

            // If a specific name is requested, only do that one
            if (name && nice !== name) {
                continue;
            }

            const url = getDownloadUrl(tr);
            if (!url) {
                console.debug(`No download link for ${nice} (row: ${tr.id})`);
                if (name && nice === name) {
                    console.warn(`Requested name "${name}" found but has no download link.`);
                    break;
                }
                continue;
            }

            try {
                console.log(`↓ Downloading: ${nice} …`);
                await fetchAndSave(url, nice, "audio/mpeg");
                count++;
            } catch (e) {
                console.error(`Failed: ${nice}`, e);
            }

            // If user asked for a single name, stop after it
            if (name && nice === name) break;

            // Gentle throttle between requests
            await sleep(delayMs);
        }

        console.log(`Done. ${count} file(s) downloaded.`);
    }

    // Expose to window for you to call after pasting
    window.downloadMp3s = downloadMp3s;
})();

downloadMp3s({ stopAt: "241_奇异恩典" });